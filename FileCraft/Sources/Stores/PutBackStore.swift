/*
 * PutBackStore.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-04.
 * Copyright 2026 Thomas Bonk <thomas@meandmymac.de>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import Observation

/// Remembers where the items that FileCraft moved to the Trash came from, so that File > Put Back can return them
/// (design decision D10). The store is a versioned JSON file in Application Support.
@Observable
internal final class PutBackStore {

  // MARK: - Types

  /// The file format.
  nonisolated private struct Contents: Codable {
    var version: Int
    var records: [Record]
  }

  /// Where an item in the Trash came from.
  nonisolated private struct Record: Codable, Hashable {
    var originalPath: String
    var trashedPath: String
  }

  // MARK: - Properties

  /// The store of the app, shared by all windows.
  internal static let shared = PutBackStore(storage: JSONFileStorage(fileName: "PutBack.json"))
  private static let currentVersion = 1

  /// The records by the comparable path of the item in the Trash.
  private var records: [String: Record] = [:]

  @ObservationIgnored private let writer: StoreWriter
  @ObservationIgnored private var hasLoaded = false
  /// Changes made before loading finished, which loading merges and saves.
  @ObservationIgnored private var hasUnsavedChanges = false

  // MARK: - Initialization

  internal init(storage: JSONFileStorage) {
    writer = StoreWriter(storage: storage)
  }

  // MARK: - Loading

  /// Reads the file once; records made before merge with the stored ones.
  internal func loadIfNeeded() async {
    guard hasLoaded == false else {
      return
    }
    hasLoaded = true
    let data = await writer.read()
    if let data, let stored = try? JSONDecoder().decode(Contents.self, from: data), stored.version == Self.currentVersion {
      for record in stored.records where records[record.trashedPath.comparablePath] == nil {
        records[record.trashedPath.comparablePath] = record
      }
    }
    if hasUnsavedChanges {
      save()
    }
  }

  // MARK: - Records

  /// The place the item at `trashed` came from, when FileCraft moved it to the Trash.
  internal func originalLocation(of trashed: URL) -> URL? {
    records[trashed.comparablePath].map { URL(filePath: $0.originalPath) }
  }

  /// Records items moved to the Trash, from their original place to the place in the Trash.
  internal func record(_ moves: [ItemMove]) {
    guard moves.isEmpty == false else {
      return
    }
    for move in moves {
      let trashedPath = move.to.path(percentEncoded: false)
      records[trashedPath.comparablePath] = Record(originalPath: move.from.path(percentEncoded: false), trashedPath: trashedPath)
    }
    save()
  }

  /// Forgets the items at `trashed`, for example after they were put back.
  internal func remove(trashed: [URL]) {
    let keys = trashed.map(\.comparablePath).filter { records[$0] != nil }
    guard keys.isEmpty == false else {
      return
    }
    for key in keys {
      records[key] = nil
    }
    save()
  }

  /// Forgets the items that are no longer in the Trash, for example after Empty Trash or a Put Back in Finder.
  internal func removeMissingItems() async {
    let paths = records.values.map(\.trashedPath)
    let missing = await Self.missingPaths(paths)
    remove(trashed: missing.map { URL(filePath: $0) })
  }

  /// Waits until every change so far is written to the file.
  internal func waitForPendingWrites() async {
    await writer.waitForPendingWrites()
  }

  // MARK: - Private

  @concurrent
  private static func missingPaths(_ paths: [String]) async -> [String] {
    paths.filter { FileManager.default.fileExists(atPath: $0) == false }
  }

  private func save() {
    guard hasLoaded else {
      hasUnsavedChanges = true
      return
    }
    hasUnsavedChanges = false
    let contents = Contents(version: Self.currentVersion, records: records.values.sorted { $0.trashedPath < $1.trashedPath })
    guard let data = try? JSONEncoder().encode(contents) else {
      return
    }
    writer.write(data)
  }
}

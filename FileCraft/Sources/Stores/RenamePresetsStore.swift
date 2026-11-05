/*
 * RenamePresetsStore.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-05.
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

/// A named list of rename rules, saved from the batch rename sheet.
nonisolated internal struct RenamePreset: Identifiable, Codable, Hashable, Sendable {
  internal var id = UUID()
  internal var name: String
  internal var rules: [RenameRule]
}

/// The batch rename presets, kept in a versioned JSON file in Application Support.
@Observable
internal final class RenamePresetsStore {

  // MARK: - Types

  nonisolated private struct Contents: Codable {
    var version: Int
    var presets: [RenamePreset]
  }

  // MARK: - Properties

  /// The store of the app, shared by all windows.
  internal static let shared = RenamePresetsStore(storage: JSONFileStorage(fileName: "RenamePresets.json"))
  private static let currentVersion = 1

  /// The presets sorted by name.
  internal private(set) var presets: [RenamePreset] = []

  @ObservationIgnored private let writer: StoreWriter
  @ObservationIgnored private var hasLoaded = false
  @ObservationIgnored private var hasUnsavedChanges = false

  // MARK: - Initialization

  internal init(storage: JSONFileStorage) {
    writer = StoreWriter(storage: storage)
  }

  // MARK: - Loading

  /// Reads the file once; presets saved before keep precedence over stored ones with the same name.
  internal func loadIfNeeded() async {
    guard hasLoaded == false else {
      return
    }
    hasLoaded = true
    let data = await writer.read()
    if let data, let stored = try? JSONDecoder().decode(Contents.self, from: data), stored.version == Self.currentVersion {
      let names = Set(presets.map { Self.key($0.name) })
      presets = Self.sorted(presets + stored.presets.filter { names.contains(Self.key($0.name)) == false })
    }
    if hasUnsavedChanges {
      save()
    }
  }

  // MARK: - Editing

  /// Saves `rules` as the preset `name`, replacing a preset with the same name, ignoring case.
  internal func save(_ rules: [RenameRule], as name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard trimmed.isEmpty == false else {
      return
    }
    presets.removeAll { Self.key($0.name) == Self.key(trimmed) }
    presets = Self.sorted(presets + [RenamePreset(name: trimmed, rules: rules)])
    save()
  }

  internal func delete(_ preset: RenamePreset) {
    presets.removeAll { $0.id == preset.id }
    save()
  }

  /// Waits until every change so far is written to the file.
  internal func waitForPendingWrites() async {
    await writer.waitForPendingWrites()
  }

  // MARK: - Private

  private static func key(_ name: String) -> String {
    name.lowercased()
  }

  private static func sorted(_ presets: [RenamePreset]) -> [RenamePreset] {
    presets.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  private func save() {
    guard hasLoaded else {
      hasUnsavedChanges = true
      return
    }
    hasUnsavedChanges = false
    guard let data = try? JSONEncoder().encode(Contents(version: Self.currentVersion, presets: presets)) else {
      return
    }
    writer.write(data)
  }
}

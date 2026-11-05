/*
 * RecentsStore.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-10-31.
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

/// The folders visited most recently, listed in Go > Recent Folders, the paths last entered in Go to Folder and the
/// recent searches of the search field.
///
/// The store is a versioned JSON file in Application Support. Folders are bookmarks, so that entries
/// follow folders that are moved or renamed.
@Observable
internal final class RecentsStore {

  // MARK: - Types

  /// The file format. Files written before Go to Folder entries or recent searches existed lack those keys.
  nonisolated private struct Contents: Codable {
    var version: Int
    var folders: [FileReference]
    var goToFolderEntries: [String]
    var searches: [SearchParameters]

    init(version: Int, folders: [FileReference], goToFolderEntries: [String], searches: [SearchParameters]) {
      self.version = version
      self.folders = folders
      self.goToFolderEntries = goToFolderEntries
      self.searches = searches
    }

    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      version = try container.decode(Int.self, forKey: .version)
      folders = try container.decode([FileReference].self, forKey: .folders)
      goToFolderEntries = try container.decodeIfPresent([String].self, forKey: .goToFolderEntries) ?? []
      searches = try container.decodeIfPresent([SearchParameters].self, forKey: .searches) ?? []
    }
  }

  // MARK: - Properties

  /// The store of the app, shared by all windows.
  internal static let shared = RecentsStore(storage: JSONFileStorage(fileName: "Recents.json"))
  /// The number of folders the menu lists.
  internal static let folderLimit = 15
  /// The number of entries Go to Folder offers.
  internal static let goToFolderEntryLimit = 10
  /// The number of searches the search field's menu offers.
  internal static let searchLimit = 10
  private static let currentVersion = 1

  /// The recent folders, most recent first, without duplicates.
  internal private(set) var folders: [FileReference] = []
  /// The paths entered in Go to Folder, exactly as typed, most recent first.
  internal private(set) var goToFolderEntries: [String] = []
  /// The recent searches with their scope, criteria and options, most recent first, without duplicates.
  internal private(set) var searches: [SearchParameters] = []

  @ObservationIgnored private let writer: StoreWriter
  @ObservationIgnored private var hasLoaded = false
  /// Changes made before loading finished, which loading merges and saves.
  @ObservationIgnored private var hasUnsavedChanges = false

  // MARK: - Initialization

  internal init(storage: JSONFileStorage) {
    writer = StoreWriter(storage: storage)
  }

  // MARK: - Loading

  /// Reads the file once; folders recorded before merge with the stored ones.
  internal func loadIfNeeded() async {
    guard hasLoaded == false else {
      return
    }
    hasLoaded = true
    let data = await writer.read()
    let stored = data.flatMap { try? JSONDecoder().decode(Contents.self, from: $0) }
    if let stored, stored.version == Self.currentVersion {
      folders = Self.merged(folders, stored.folders)
      goToFolderEntries = Self.mergedEntries(goToFolderEntries, stored.goToFolderEntries)
      searches = Self.mergedSearches(searches, stored.searches)
    }
    if hasUnsavedChanges {
      save()
    }
  }

  // MARK: - Recording

  /// Moves `folder` to the top of the list.
  internal func recordVisit(to folder: FileReference) {
    folders = Self.merged([folder], folders)
    save()
  }

  /// Removes all folders, as Clear Menu does.
  internal func clear() {
    folders.removeAll()
    save()
  }

  /// Moves `entry`, a path that Go to Folder showed successfully, to the top of its entries.
  internal func recordGoToFolderEntry(_ entry: String) {
    goToFolderEntries = Self.mergedEntries([entry], goToFolderEntries)
    save()
  }

  /// Moves `search` to the top of the recent searches.
  internal func recordSearch(_ search: SearchParameters) {
    searches = Self.mergedSearches([search], searches)
    save()
  }

  /// Removes all recent searches, as Clear Recent Searches does.
  internal func clearSearches() {
    searches.removeAll()
    save()
  }

  /// Waits until every change so far is written to the file.
  internal func waitForPendingWrites() async {
    await writer.waitForPendingWrites()
  }

  // MARK: - Private

  /// `newer` followed by the folders of `older` that are not in `newer`, cut to the folder limit.
  private static func merged(_ newer: [FileReference], _ older: [FileReference]) -> [FileReference] {
    var seenPaths = Set<String>()
    let unique = (newer + older).filter { seenPaths.insert($0.lastKnownPath.comparablePath).inserted }
    return Array(unique.prefix(folderLimit))
  }

  /// `newer` followed by the entries of `older` that are not in `newer`, cut to the entry limit.
  private static func mergedEntries(_ newer: [String], _ older: [String]) -> [String] {
    var seen = Set<String>()
    return Array((newer + older).filter { seen.insert($0).inserted }.prefix(goToFolderEntryLimit))
  }

  /// `newer` followed by the searches of `older` that search for something else, cut to the search limit.
  private static func mergedSearches(_ newer: [SearchParameters], _ older: [SearchParameters]) -> [SearchParameters] {
    var seen = Set<SearchParameters>()
    return Array((newer + older).filter { seen.insert($0.rule).inserted }.prefix(searchLimit))
  }

  private func save() {
    guard hasLoaded else {
      hasUnsavedChanges = true
      return
    }
    hasUnsavedChanges = false
    let contents = Contents(
      version: Self.currentVersion, folders: folders, goToFolderEntries: goToFolderEntries, searches: searches)
    guard let data = try? JSONEncoder().encode(contents) else {
      return
    }
    writer.write(data)
  }
}

/*
 * FavoritesStore.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-03.
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

/// One entry of the sidebar's Favorites: a folder or file, stored as a bookmark.
nonisolated internal struct Favorite: Identifiable, Codable, Hashable, Sendable {
  internal let id: UUID
  internal var reference: FileReference

  internal var url: URL {
    reference.lastKnownURL
  }

  /// The localized name of the item at its last known location.
  internal var name: String {
    FileManager.default.displayName(atPath: reference.lastKnownPath)
  }
}

/// What clicking a favorite shows.
nonisolated internal enum FavoriteTarget: Hashable, Sendable {
  case folder(FileReference)
  case file(URL)
  case unavailable
}

/// The sidebar's Favorites, shared by all windows and stored as a versioned JSON file in Application Support.
///
/// Favorites are bookmarks: `refresh()` gives renamed or moved items their new path and marks items that cannot
/// be resolved, such as items on a network volume that is not mounted, as unavailable.
@Observable
internal final class FavoritesStore {

  // MARK: - Types

  /// The file format.
  nonisolated private struct Contents: Codable {
    var version: Int
    var favorites: [Favorite]
  }

  // MARK: - Properties

  /// The store of the app, shared by all windows.
  internal static let shared = FavoritesStore(storage: JSONFileStorage(fileName: "Favorites.json"))
  private static let currentVersion = 1

  /// The favorites in sidebar order.
  internal private(set) var favorites: [Favorite] = []
  /// The favorites whose items could not be resolved at the last refresh.
  internal private(set) var unavailableIDs: Set<Favorite.ID> = []
  /// Whether the favorites have been read and resolved once; the sidebar waits for it.
  internal private(set) var isLoaded = false

  /// Writes the file; nil for a store that lives only in memory, as in previews.
  @ObservationIgnored private let writer: StoreWriter?
  /// The folders a new store starts with.
  @ObservationIgnored private let defaultFolders: [URL]
  @ObservationIgnored private var hasLoaded = false

  // MARK: - Initialization

  /// - Parameters:
  ///   - storage: The store file, or nil for a store that is never read or written.
  ///   - defaultFolders: The favorites of a new store: Home, Desktop, Documents, Downloads and Applications.
  internal init(storage: JSONFileStorage?, defaultFolders: [URL] = FavoritesStore.standardFolders) {
    writer = storage.map(StoreWriter.init(storage:))
    self.defaultFolders = defaultFolders
  }

  /// A store with fixed favorites that never touches the file system, for previews.
  internal convenience init(previewFavorites urls: [URL]) {
    self.init(storage: nil)
    favorites = urls.map { Favorite(id: UUID(), reference: FileReference(unresolvedURL: $0)) }
    hasLoaded = true
    isLoaded = true
  }

  /// Home, Desktop, Documents, Downloads and Applications.
  nonisolated internal static var standardFolders: [URL] {
    [StandardLocation.home, .desktop, .documents, .downloads, .applications].compactMap { $0.url() }
  }

  // MARK: - Loading

  /// Reads the file once, or starts with the default folders, and then refreshes the favorites.
  internal func loadIfNeeded() async {
    guard hasLoaded == false, let writer else {
      return
    }
    hasLoaded = true
    let data = await writer.read()
    let stored = data.flatMap { try? JSONDecoder().decode(Contents.self, from: $0) }
    if let stored, stored.version == Self.currentVersion {
      // Favorites added while the file was read stay behind the stored ones.
      let storedPaths = Set(stored.favorites.map(\.reference.lastKnownPath.comparablePath))
      favorites = stored.favorites + favorites.filter { storedPaths.contains($0.reference.lastKnownPath.comparablePath) == false }
    } else {
      favorites = await Self.favorites(for: defaultFolders) + favorites
    }
    save()
    await refresh()
    isLoaded = true
  }

  // MARK: - Editing

  /// Adds the items at `urls` at `index`, or at the end; items that are favorites already are skipped.
  internal func add(_ urls: [URL], at index: Int? = nil) async {
    var seenPaths = Set(favorites.map(\.reference.lastKnownPath.comparablePath))
    let newURLs = urls.filter { seenPaths.insert($0.comparablePath).inserted }
    let newFavorites = await Self.favorites(for: newURLs)
    guard newFavorites.isEmpty == false else {
      return
    }
    let position = min(max(index ?? favorites.count, 0), favorites.count)
    favorites.insert(contentsOf: newFavorites, at: position)
    save()
  }

  internal func remove(_ id: Favorite.ID) {
    favorites.removeAll { $0.id == id }
    unavailableIDs.remove(id)
    save()
  }

  /// Moves the favorites at `source` before the favorite at `destination`, as `List` reordering reports it.
  internal func move(fromOffsets source: IndexSet, toOffset destination: Int) {
    let moving = source.map { favorites[$0] }
    var remaining = favorites.enumerated().filter { source.contains($0.offset) == false }.map(\.element)
    let insertionIndex = destination - source.count { $0 < destination }
    remaining.insert(contentsOf: moving, at: min(max(insertionIndex, 0), remaining.count))
    favorites = remaining
    save()
  }

  // MARK: - Resolving

  /// Resolves every bookmark: renamed or moved items get their new path, and items that cannot be resolved
  /// become unavailable. Volumes are never mounted for this.
  internal func refresh() async {
    let current = favorites
    let results = await Self.resolve(current)
    // A favorite added or removed meanwhile wins over this refresh; the next one catches up.
    guard favorites.map(\.id) == current.map(\.id) else {
      return
    }
    let refreshed = results.map(\.favorite)
    let unavailable = Set(results.filter { $0.isAvailable == false }.map(\.favorite.id))
    // Unchanged values are not assigned, so that the sidebar is not updated for nothing.
    if unavailable != unavailableIDs {
      unavailableIDs = unavailable
    }
    if refreshed.map(\.reference.lastKnownPath) != current.map(\.reference.lastKnownPath) {
      favorites = refreshed
      save()
    }
  }

  /// Resolves the favorite `id` right before it is opened.
  internal func target(of id: Favorite.ID) async -> FavoriteTarget {
    guard let favorite = favorites.first(where: { $0.id == id }) else {
      return .unavailable
    }
    let result = await Self.resolve([favorite])
    guard let resolved = result.first, resolved.isAvailable else {
      unavailableIDs.insert(id)
      return .unavailable
    }
    unavailableIDs.remove(id)
    if let index = favorites.firstIndex(where: { $0.id == id }), favorites[index].reference.lastKnownPath != resolved.favorite.reference.lastKnownPath {
      favorites[index] = resolved.favorite
      save()
    }
    return resolved.isFolder ? .folder(resolved.favorite.reference) : .file(resolved.favorite.url)
  }

  /// Waits until every change so far is written to the file.
  internal func waitForPendingWrites() async {
    await writer?.waitForPendingWrites()
  }

  // MARK: - Private

  private func save() {
    guard let writer, hasLoaded else {
      return
    }
    guard let data = try? JSONEncoder().encode(Contents(version: Self.currentVersion, favorites: favorites)) else {
      return
    }
    writer.write(data)
  }

  /// Favorites for the existing items among `urls`.
  @concurrent
  private static func favorites(for urls: [URL]) async -> [Favorite] {
    urls.compactMap { url in
      (try? FileReference(url: url)).map { Favorite(id: UUID(), reference: $0) }
    }
  }

  /// Each favorite with its refreshed bookmark, whether its item exists, and whether it opens as a folder.
  @concurrent
  private static func resolve(_ favorites: [Favorite]) async -> [(favorite: Favorite, isAvailable: Bool, isFolder: Bool)] {
    favorites.map { favorite in
      var refreshed = favorite
      guard let url = try? refreshed.reference.refresh() else {
        return (favorite, false, false)
      }
      let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
      guard let values else {
        return (refreshed, false, false)
      }
      return (refreshed, true, values.isDirectory == true && values.isPackage != true)
    }
  }
}

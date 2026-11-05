/*
 * ShelfStore.swift
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

/// One item on the shelf: a reference to a file or folder, never a copy.
nonisolated internal struct ShelfItem: Identifiable, Codable, Hashable, Sendable {
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

/// The shelf's items, shared by all browser windows and stored as a versioned JSON file in Application Support
/// (shelf spec).
///
/// Items are bookmarks: `refresh()` gives renamed or moved items their new path and marks items that no longer
/// exist or cannot be reached as unavailable, so that the shelf shows them dimmed.
@Observable
internal final class ShelfStore {

  // MARK: - Types

  /// The file format.
  nonisolated private struct Contents: Codable {
    var version: Int
    var items: [ShelfItem]
  }

  // MARK: - Properties

  /// The shelf of the app, shared by all windows.
  internal static let shared = ShelfStore(storage: JSONFileStorage(fileName: "Shelf.json"))
  private static let currentVersion = 1

  /// The items in shelf order.
  internal private(set) var items: [ShelfItem] = []
  /// The items that could not be resolved at the last refresh.
  internal private(set) var unavailableIDs: Set<ShelfItem.ID> = []

  /// Writes the file; nil for a store that lives only in memory, as in previews.
  @ObservationIgnored private let writer: StoreWriter?
  @ObservationIgnored private var hasLoaded = false

  // MARK: - Initialization

  /// - Parameter storage: The store file, or nil for a store that is never read or written.
  internal init(storage: JSONFileStorage?) {
    writer = storage.map(StoreWriter.init(storage:))
  }

  /// A store with fixed items that never touches the file system, for previews.
  internal convenience init(previewItems urls: [URL], unavailable: Set<URL> = []) {
    self.init(storage: nil)
    items = urls.map { ShelfItem(id: UUID(), reference: FileReference(unresolvedURL: $0)) }
    unavailableIDs = Set(items.filter { unavailable.contains($0.url) }.map(\.id))
    hasLoaded = true
  }

  // MARK: - Loading

  /// Reads the file once and then refreshes the items.
  internal func loadIfNeeded() async {
    guard hasLoaded == false, let writer else {
      return
    }
    hasLoaded = true
    let data = await writer.read()
    let stored = data.flatMap { try? JSONDecoder().decode(Contents.self, from: $0) }
    if let stored, stored.version == Self.currentVersion {
      // Items added while the file was read stay behind the stored ones.
      let storedPaths = Set(stored.items.map(\.reference.lastKnownPath.comparablePath))
      items = stored.items + items.filter { storedPaths.contains($0.reference.lastKnownPath.comparablePath) == false }
    }
    save()
    await refresh()
  }

  // MARK: - Editing

  /// Adds the existing items at `urls` at the end; items that are on the shelf already are skipped.
  internal func add(_ urls: [URL]) async {
    var seenPaths = Set(items.map(\.reference.lastKnownPath.comparablePath))
    let newURLs = urls.filter { seenPaths.insert($0.comparablePath).inserted }
    let newItems = await Self.items(for: newURLs)
    guard newItems.isEmpty == false else {
      return
    }
    items.append(contentsOf: newItems)
    save()
  }

  /// Remove from Shelf.
  internal func remove(_ ids: Set<ShelfItem.ID>) {
    guard ids.isEmpty == false else {
      return
    }
    items.removeAll { ids.contains($0.id) }
    unavailableIDs.subtract(ids)
    save()
  }

  /// Removes the items at `urls`, for example after they were dragged out of the shelf.
  internal func remove(itemsAt urls: [URL]) {
    let paths = Set(urls.map(\.comparablePath))
    remove(Set(items.filter { paths.contains($0.url.comparablePath) }.map(\.id)))
  }

  /// Clear Shelf.
  internal func clear() {
    guard items.isEmpty == false else {
      return
    }
    items.removeAll()
    unavailableIDs.removeAll()
    save()
  }

  /// Points the items that `moves` moved to their new places. A bookmark finds an item moved on the same volume
  /// by itself, but not one that was copied to another volume and deleted.
  internal func relocate(_ moves: [ItemMove]) async {
    let destinations = Dictionary(moves.map { ($0.from.comparablePath, $0.to) }, uniquingKeysWith: { first, _ in first })
    let moved = items.filter { destinations[$0.url.comparablePath] != nil }
    let references = await Self.references(for: moved.compactMap { destinations[$0.url.comparablePath] })
    var changed = false
    for item in moved {
      guard
        let destination = destinations[item.url.comparablePath],
        let reference = references[destination.comparablePath],
        let index = items.firstIndex(where: { $0.id == item.id })
      else {
        continue
      }
      items[index].reference = reference
      unavailableIDs.remove(item.id)
      changed = true
    }
    if changed {
      save()
    }
  }

  // MARK: - Resolving

  /// Resolves every bookmark: renamed or moved items get their new path, and items that cannot be resolved
  /// become unavailable. Volumes are never mounted for this.
  internal func refresh() async {
    // A store without a file, as in previews, keeps its fixed items as they are.
    guard writer != nil else {
      return
    }
    let current = items
    let results = await Self.resolve(current)
    // An item added or removed meanwhile wins over this refresh; the next one catches up.
    guard items.map(\.id) == current.map(\.id) else {
      return
    }
    let refreshed = results.map(\.item)
    let unavailable = Set(results.filter { $0.isAvailable == false }.map(\.item.id))
    // Unchanged values are not assigned, so that the shelf is not updated for nothing.
    if unavailable != unavailableIDs {
      unavailableIDs = unavailable
    }
    if refreshed.map(\.reference.lastKnownPath) != current.map(\.reference.lastKnownPath) {
      items = refreshed
      save()
    }
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
    guard let data = try? JSONEncoder().encode(Contents(version: Self.currentVersion, items: items)) else {
      return
    }
    writer.write(data)
  }

  /// Shelf items for the existing items among `urls`.
  @concurrent
  private static func items(for urls: [URL]) async -> [ShelfItem] {
    urls.compactMap { url in
      (try? FileReference(url: url)).map { ShelfItem(id: UUID(), reference: $0) }
    }
  }

  /// References to the existing items among `urls`, by their comparable path.
  @concurrent
  private static func references(for urls: [URL]) async -> [String: FileReference] {
    var references: [String: FileReference] = [:]
    for url in urls {
      references[url.comparablePath] = try? FileReference(url: url)
    }
    return references
  }

  /// Each item with its refreshed bookmark and whether it still exists.
  @concurrent
  private static func resolve(_ items: [ShelfItem]) async -> [(item: ShelfItem, isAvailable: Bool)] {
    items.map { item in
      var refreshed = item
      guard let url = try? refreshed.reference.refresh() else {
        return (item, false)
      }
      return (refreshed, (try? url.checkResourceIsReachable()) == true)
    }
  }
}

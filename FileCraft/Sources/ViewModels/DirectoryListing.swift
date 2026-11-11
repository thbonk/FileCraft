/*
 * DirectoryListing.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-10-30.
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

/// Why a folder could not be listed.
nonisolated internal struct LoadFailure: Equatable, Sendable {

  internal enum Kind: Sendable {
    case notFound
    case noPermission
    case other
  }

  internal let kind: Kind
  /// The localized description of the underlying error.
  internal let message: String

  internal init(kind: Kind, message: String) {
    self.kind = kind
    self.message = message
  }

  internal init(error: any Error) {
    let nsError = error as NSError
    let posixCode = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError).flatMap { underlying in
      underlying.domain == NSPOSIXErrorDomain ? underlying.code : nil
    }
    switch (nsError.domain, nsError.code, posixCode) {
    case (NSCocoaErrorDomain, CocoaError.fileReadNoPermission.rawValue, _), (_, _, Int(EPERM)), (_, _, Int(EACCES)):
      kind = .noPermission
    case (NSCocoaErrorDomain, CocoaError.fileReadNoSuchFile.rawValue, _), (NSCocoaErrorDomain, CocoaError.fileNoSuchFile.rawValue, _),
      (_, _, Int(ENOENT)):
      kind = .notFound
    default:
      kind = .other
    }
    message = nsError.localizedDescription
  }
}

/// The items of one folder, kept current with FSEvents while a view observes it.
@Observable
internal final class DirectoryListing {

  // MARK: - Types

  internal enum State: Equatable {
    case idle
    case loading
    case loaded
    case failed(LoadFailure)
  }

  // MARK: - Properties

  /// The folder's items in no particular order.
  internal private(set) var items: [FileItem] = [] {
    didSet {
      itemsRevision &+= 1
    }
  }
  /// Increases with every change of `items`, so that values derived from them know when to compute again.
  internal private(set) var itemsRevision = 0
  internal private(set) var state: State = .idle
  /// The space available on the folder's volume.
  internal private(set) var availableCapacity: Int64?
  /// Whether a search is still looking for results; it stays false while a This Mac search only watches for changes.
  internal private(set) var isSearching = false

  @ObservationIgnored private let service = FileSystemService()
  @ObservationIgnored private let searchService = SearchService()
  /// The running search, which Stop cancels.
  @ObservationIgnored private var searchTask: Task<Void, Never>?
  /// Increases with every load, so that a load that was replaced no longer changes the items.
  @ObservationIgnored private var loadGeneration = 0
  @ObservationIgnored private let isStatic: Bool

  // MARK: - Initialization

  internal init() {
    isStatic = false
  }

  /// Creates a listing with fixed items that never touches the file system, for previews and tests.
  internal init(staticItems: [FileItem], availableCapacity: Int64? = nil) {
    items = staticItems
    state = .loaded
    self.availableCapacity = availableCapacity
    isStatic = true
  }

  // MARK: - Loading

  /// Loads `folder` and reloads it after every change FSEvents reports, until the calling task is cancelled.
  ///
  /// Call it from a view's `.task` so that loading follows the view's lifetime.
  internal func observe(_ folder: URL, includingHiddenItems: Bool) async {
    guard isStatic == false else {
      return
    }
    loadGeneration += 1
    // Watch before the first load, so that changes during loading are not missed.
    let changes = DirectoryWatcher.changes(in: folder)
    state = .loading
    await reload(folder, includingHiddenItems: includingHiddenItems)
    for await change in changes {
      await invalidateFolderSizes(in: folder, for: change)
      await reload(folder, includingHiddenItems: includingHiddenItems)
    }
  }

  /// Lists the mounted volumes for the Computer location and lists them again after every mount, unmount
  /// or rename, until the calling task is cancelled.
  internal func observeVolumes(using monitor: VolumeMonitor = VolumeMonitor()) async {
    guard isStatic == false else {
      return
    }
    loadGeneration += 1
    // Subscribe before the first load, so that a volume mounted during loading is not missed.
    let events = monitor.events()
    state = .loading
    await loadVolumes(using: monitor)
    for await _ in events {
      await loadVolumes(using: monitor)
    }
  }

  /// Lists the mounted volumes once, each as the item of its root folder.
  internal func loadVolumes(using monitor: VolumeMonitor = VolumeMonitor()) async {
    let volumes = await monitor.mountedVolumes()
    let loadedItems = await service.items(at: volumes.map(\.url))
    guard Task.isCancelled == false else {
      return
    }
    items = loadedItems
    availableCapacity = nil
    state = .loaded
  }

  /// Shows `items` that the privileged helper listed for a folder FileCraft may not read, as Authenticate to View
  /// does; the next change on disk loads the folder normally again.
  internal func showPrivilegedItems(_ items: [FileItem]) {
    self.items = items
    availableCapacity = nil
    state = .loaded
  }

  /// Lists the items carrying `tag`, found through Spotlight. The list is read once each time the tag is shown.
  internal func loadTaggedItems(_ tag: String) async {
    guard isStatic == false else {
      return
    }
    loadGeneration += 1
    state = .loading
    let urls = await TagLibrary.items(taggedWith: tag)
    let loadedItems = await service.items(at: urls)
    guard Task.isCancelled == false else {
      return
    }
    items = loadedItems
    availableCapacity = nil
    state = .loaded
  }

  // MARK: - Searching

  /// Runs `query` and shows its results as they are found, until the search ends, Stop is chosen or the calling task
  /// is cancelled. This Mac searches keep their results current until then.
  internal func observeSearch(_ query: SearchQuery, sizeUnits: SizeUnits) async {
    guard isStatic == false else {
      return
    }
    loadGeneration += 1
    let generation = loadGeneration
    items = []
    availableCapacity = nil
    state = .loading
    isSearching = true
    let task = Task {
      await performSearch(query, sizeUnits: sizeUnits, generation: generation)
    }
    searchTask = task
    await withTaskCancellationHandler {
      await task.value
    } onCancel: {
      task.cancel()
    }
    if generation == loadGeneration {
      searchTask = nil
      isSearching = false
      if state == .loading {
        state = .loaded
      }
    }
  }

  /// Ends the running search; the results found so far stay.
  internal func stopSearch() {
    searchTask?.cancel()
    searchTask = nil
    isSearching = false
    if state == .loading {
      state = .loaded
    }
  }

  private func performSearch(_ query: SearchQuery, sizeUnits: SizeUnits, generation: Int) async {
    let parameters = query.parameters
    let matcher = SearchMatcher(parameters: parameters, sizeUnits: sizeUnits)
    switch parameters.scope {
    case .thisFolder:
      return
    case .subfolders:
      guard let root = query.origin?.lastKnownURL else {
        return
      }
      state = .loaded
      await searchService.searchSubfolders(of: root, parameters: parameters, matcher: matcher) { [weak self] batch in
        guard let self, generation == loadGeneration else {
          return
        }
        items.append(contentsOf: batch)
      }
    case .thisMac:
      let predicate = SpotlightPredicate.predicate(for: parameters, sizeUnits: sizeUnits)
      // Found items by path; nil marks paths that the matcher rejected, so that updates read only new paths.
      var known: [String: FileItem?] = [:]
      await SpotlightSearch.run(predicate: predicate) { urls, isGathering in
        let newURLs = urls.filter { known[$0.path(percentEncoded: false)] == nil }
        let found = await searchService.items(
          at: newURLs, matcher: matcher, includesPackageContents: parameters.includesPackageContents)
        guard Task.isCancelled == false, generation == loadGeneration else {
          return
        }
        for url in newURLs {
          known[url.path(percentEncoded: false)] = .some(nil)
        }
        for item in found {
          known[item.id] = item
        }
        items = urls.compactMap { known[$0.path(percentEncoded: false)] ?? nil }
        state = .loaded
        isSearching = isGathering
      }
    }
  }

  // MARK: - Private

  private func reload(_ folder: URL, includingHiddenItems: Bool) async {
    do {
      let loadedItems = try await service.contentsOfDirectory(at: folder, includingHiddenItems: includingHiddenItems)
      let capacity = await service.availableCapacity(of: folder)
      guard Task.isCancelled == false else {
        return
      }
      items = loadedItems
      availableCapacity = capacity
      state = .loaded
    } catch is CancellationError {
      return
    } catch {
      guard Task.isCancelled == false else {
        return
      }
      items = []
      state = .failed(LoadFailure(error: error))
    }
  }

  private func invalidateFolderSizes(in folder: URL, for change: DirectoryChange) async {
    await FolderSizeService.shared.invalidate(folder)
    for name in change.changedNames {
      await FolderSizeService.shared.invalidate(folder.appending(path: name))
    }
  }
}

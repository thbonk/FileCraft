/*
 * SearchService.swift
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

/// Runs Subfolders searches by enumerating folders and This Mac searches through Spotlight.
///
/// Both report results progressively and end when the calling task is cancelled.
nonisolated internal struct SearchService: Sendable {

  // MARK: - Properties

  /// The most results a This Mac search shows.
  internal static let spotlightResultLimit = 10_000
  /// The most matches handed over at once by a Subfolders search.
  private static let batchSize = 200
  /// The longest a found match waits before it is handed over.
  private static let batchInterval = Duration.milliseconds(250)

  // MARK: - Subfolders

  /// Searches the folders below `root` for items that `matcher` accepts and hands them over in batches.
  ///
  /// Hidden items and package contents are skipped unless `parameters` include them. The search ends when
  /// everything is searched or the calling task is cancelled.
  @concurrent
  internal func searchSubfolders(
    of root: URL,
    parameters: SearchParameters,
    matcher: SearchMatcher,
    onBatch: @escaping @MainActor @Sendable ([FileItem]) -> Void
  ) async {
    var options: FileManager.DirectoryEnumerationOptions = []
    if parameters.includesHiddenItems == false {
      options.insert(.skipsHiddenFiles)
    }
    if parameters.includesPackageContents == false {
      options.insert(.skipsPackageDescendants)
    }
    guard
      let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: FileSystemService.resourceKeys,
        options: options,
        errorHandler: { _, _ in true })
    else {
      return
    }
    let clock = ContinuousClock()
    var batch: [FileItem] = []
    var lastHandover = clock.now
    while let url = enumerator.nextObject() as? URL {
      guard Task.isCancelled == false else {
        return
      }
      let names = try? url.resourceValues(forKeys: [.nameKey, .localizedNameKey])
      let name = names?.name ?? url.lastPathComponent
      guard matcher.mayMatch(name: name, localizedName: names?.localizedName ?? name),
        let item = try? FileSystemService.makeItem(at: url),
        matcher.matches(item)
      else {
        continue
      }
      batch.append(item)
      if batch.count >= Self.batchSize || clock.now - lastHandover >= Self.batchInterval {
        await onBatch(batch)
        batch.removeAll(keepingCapacity: true)
        lastHandover = clock.now
      }
    }
    if batch.isEmpty == false, Task.isCancelled == false {
      await onBatch(batch)
    }
  }

  // MARK: - This Mac

  /// Reads the items at `urls` that `matcher` accepts, skipping package contents unless `includesPackageContents`.
  @concurrent
  internal func items(at urls: [URL], matcher: SearchMatcher, includesPackageContents: Bool) async -> [FileItem] {
    var packageFolders: [String: Bool] = [:]
    var items: [FileItem] = []
    for (index, url) in urls.enumerated() {
      if index.isMultiple(of: 256), Task.isCancelled {
        return items
      }
      if includesPackageContents == false, Self.isInsidePackage(url, cache: &packageFolders) {
        continue
      }
      guard let item = try? FileSystemService.makeItem(at: url), matcher.matches(item) else {
        continue
      }
      items.append(item)
    }
    return items
  }

  /// Whether one of the folders containing `url` is a package, such as an application bundle.
  private static func isInsidePackage(_ url: URL, cache: inout [String: Bool]) -> Bool {
    var folder = url.deletingLastPathComponent()
    while folder.path(percentEncoded: false) != "/" {
      let path = folder.path(percentEncoded: false)
      if let isPackage = cache[path] {
        if isPackage {
          return true
        }
      } else {
        let isPackage = (try? folder.resourceValues(forKeys: [.isPackageKey]).isPackage) == true
        cache[path] = isPackage
        if isPackage {
          return true
        }
      }
      folder = folder.deletingLastPathComponent()
    }
    return false
  }
}

/// Runs a Spotlight query with `NSMetadataQuery` on the main actor, which the query's notifications need.
internal enum SpotlightSearch {

  /// Starts a query for `predicate` on the whole Mac and reports the paths of all results whenever they change,
  /// while gathering and afterwards, until the calling task is cancelled. `onResults` also learns whether the query
  /// is still gathering its initial results.
  internal static func run(predicate: NSPredicate, onResults: (_ urls: [URL], _ isGathering: Bool) async -> Void) async {
    let query = NSMetadataQuery()
    query.predicate = predicate
    query.searchScopes = [NSMetadataQueryLocalComputerScope]
    query.notificationBatchingInterval = 0.3
    let (changes, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    let center = NotificationCenter.default
    let names: [Notification.Name] = [
      .NSMetadataQueryGatheringProgress, .NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate,
    ]
    let observers = names.map { name in
      center.addObserver(forName: name, object: query, queue: .main) { _ in
        continuation.yield()
      }
    }
    defer {
      for observer in observers {
        center.removeObserver(observer)
      }
      query.stop()
      continuation.finish()
    }
    guard query.start() else {
      return
    }
    // The stream ends when the task is cancelled.
    for await _ in changes {
      query.disableUpdates()
      let count = min(query.resultCount, SearchService.spotlightResultLimit)
      let urls = (0..<count).compactMap { index -> URL? in
        guard let item = query.result(at: index) as? NSMetadataItem,
          let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
        else {
          return nil
        }
        return URL(filePath: path)
      }
      let isGathering = query.isGathering
      query.enableUpdates()
      await onResults(urls, isGathering)
    }
  }
}

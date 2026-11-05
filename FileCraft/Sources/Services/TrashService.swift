/*
 * TrashService.swift
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

import Darwin
import Foundation

/// Moves items to the Trash and back, and finds the Trash folders for Empty Trash (design decision D10).
///
/// Items are recycled through `NSWorkspace`, so that Finder's Put Back keeps working for them too.
nonisolated internal struct TrashService: Sendable {

  // MARK: - Types

  /// Moves items to the Trash and reports where each one went; items that could not be moved are missing.
  internal typealias Recycle = @Sendable ([URL]) async -> [URL: URL]

  /// The outcome of moving items to the Trash.
  internal struct TrashResult: Hashable, Sendable {
    /// From the original place to the place in the Trash.
    internal var moves: [ItemMove] = []
    /// The items that could not be moved to the Trash, for example on a volume without one.
    internal var failures: [URL] = []
    /// The items that cannot change at all: in a location macOS protects, or on a read-only volume. Deleting them
    /// immediately would fail too.
    internal var unchangeable: [URL] = []
  }

  /// The contents of one Trash folder.
  internal struct TrashContents: Hashable, Sendable {
    internal let folder: URL
    internal let items: [URL]
    /// Whether the folder could be read; reading the Trash of the home folder needs Full Disk Access.
    internal let isReadable: Bool
  }

  // MARK: - Properties

  internal var recycle: Recycle = { await WorkspaceActions.recycle($0) }

  // MARK: - Trash

  /// Moves `urls` to the Trash of their volumes.
  ///
  /// Items that cannot change are refused without trying, because the system would copy them into the Trash and
  /// leave the original. An item whose original is still there after recycling counts as failed, and the copy the
  /// system left in the Trash is removed.
  internal func moveToTrash(_ urls: [URL]) async -> TrashResult {
    var result = TrashResult()
    let changeable = await Self.changeableItems(urls)
    result.unchangeable = urls.filter { changeable.contains($0) == false }
    guard changeable.isEmpty == false else {
      return result
    }
    let trashed = await recycle(changeable)
    let trashedByPath = Dictionary(trashed.map { ($0.key.comparablePath, $0.value) }, uniquingKeysWith: { first, _ in first })
    for url in changeable {
      guard let trashedURL = trashedByPath[url.comparablePath] else {
        result.failures.append(url)
        continue
      }
      if await Self.exists(url) {
        await Self.remove(trashedURL)
        result.failures.append(url)
      } else {
        result.moves.append(ItemMove(from: url, to: trashedURL))
      }
    }
    return result
  }

  /// The items among `urls` that may change: not in a location macOS protects and not on a read-only volume.
  @concurrent
  private static func changeableItems(_ urls: [URL]) async -> [URL] {
    urls.filter { url in
      let isReadOnly = (try? url.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) == true
      let folder = url.deletingLastPathComponent().resolvingSymlinksInPath().path(percentEncoded: false)
      let path = (folder as NSString).appendingPathComponent(url.lastPathComponent)
      return isReadOnly == false && HelperFileSystem.isProtected(path) == false
    }
  }

  @concurrent
  private static func exists(_ url: URL) async -> Bool {
    var status = stat()
    return lstat(url.path(percentEncoded: false), &status) == 0
  }

  @concurrent
  private static func remove(_ url: URL) async {
    try? FileManager.default.removeItem(at: url)
  }

  /// Moves trashed items back to their original places, never replacing anything there.
  ///
  /// - Parameter moves: The moves into the Trash, from the original place to the place in the Trash.
  /// - Returns: The moves whose items could not be put back, for example because their place is taken.
  @concurrent
  internal func putBack(_ moves: [ItemMove]) async -> [ItemMove] {
    moves.filter { move in
      (try? FileOperationWorker.renameWithinVolume(move.to, move.from)) != true
    }
  }

  // MARK: - Empty Trash

  /// The Trash folders of the user on all mounted volumes that have one, the home folder's first.
  @concurrent
  internal static func trashFolders() async -> [URL] {
    var folders = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask)
    let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? []
    for volume in volumes {
      guard
        let trash = try? FileManager.default.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: volume, create: false),
        folders.contains(where: { $0.comparablePath == trash.comparablePath }) == false
      else {
        continue
      }
      folders.append(trash)
    }
    return folders
  }

  /// The items in each of `folders`, hidden ones included.
  @concurrent
  internal static func contents(of folders: [URL]) async -> [TrashContents] {
    folders.map { folder in
      guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)) else {
        return TrashContents(folder: folder, items: [], isReadable: false)
      }
      return TrashContents(folder: folder, items: names.map { folder.appending(path: $0) }, isReadable: true)
    }
  }
}

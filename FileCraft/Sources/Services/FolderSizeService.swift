/*
 * FolderSizeService.swift
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

/// The recursive size of a folder.
nonisolated internal struct FolderSize: Hashable, Sendable {
  /// The number of files and folders inside the folder, at any depth.
  internal let itemCount: Int
  internal let logicalBytes: Int64
  internal let physicalBytes: Int64
}

/// Calculates folder sizes in the background and caches them until the folder changes.
internal actor FolderSizeService {

  // MARK: - Types

  nonisolated private struct Entry {
    let modificationDate: Date?
    let size: FolderSize
  }

  // MARK: - Properties

  /// The cache shared by all windows.
  nonisolated internal static let shared = FolderSizeService()

  private var entries: [String: Entry] = [:]

  // MARK: - Sizes

  /// Returns the size of `folder`. Cancelling the calling task stops the calculation.
  ///
  /// A cached size is reused while the folder's modification date is unchanged. Changes deeper inside the
  /// folder do not change that date, so callers report them with `invalidate(_:)`.
  internal func size(of folder: URL) async throws -> FolderSize {
    let path = folder.path(percentEncoded: false)
    let modificationDate = try await FolderSizeCalculator.modificationDate(of: folder)
    if let entry = entries[path], entry.modificationDate == modificationDate {
      return entry.size
    }
    let size = try await FolderSizeCalculator.calculate(folder)
    entries[path] = Entry(modificationDate: modificationDate, size: size)
    return size
  }

  /// Drops the cached sizes of `url` and of every cached folder that contains it.
  internal func invalidate(_ url: URL) {
    let path = url.path(percentEncoded: false)
    entries = entries.filter { cachedPath, _ in
      let folderPrefix = cachedPath.hasSuffix("/") ? cachedPath : cachedPath + "/"
      return path != cachedPath && path.hasPrefix(folderPrefix) == false
    }
  }
}

/// Walks folder trees off the caller's actor.
nonisolated internal enum FolderSizeCalculator {

  @concurrent
  static func modificationDate(of folder: URL) async throws -> Date? {
    try folder.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
  }

  @concurrent
  static func calculate(_ folder: URL) async throws -> FolderSize {
    try calculateSynchronously(folder)
  }

  /// Directory enumerators cannot be iterated in async code, so the walk is synchronous.
  private static func calculateSynchronously(_ folder: URL) throws -> FolderSize {
    try Task.checkCancellation()
    let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileSizeKey, .totalFileAllocatedSizeKey]
    guard
      let enumerator = FileManager.default.enumerator(
        at: folder,
        includingPropertiesForKeys: keys,
        options: [],
        errorHandler: { _, _ in true })
    else {
      throw CocoaError(.fileReadNoSuchFile, userInfo: [NSURLErrorKey: folder])
    }
    var itemCount = 0
    var logicalBytes: Int64 = 0
    var physicalBytes: Int64 = 0
    for case let url as URL in enumerator {
      itemCount += 1
      if itemCount.isMultiple(of: 256) {
        try Task.checkCancellation()
      }
      guard
        let values = try? url.resourceValues(forKeys: Set(keys)),
        values.isRegularFile == true
      else {
        continue
      }
      logicalBytes += Int64(values.totalFileSize ?? 0)
      physicalBytes += Int64(values.totalFileAllocatedSize ?? 0)
    }
    return FolderSize(itemCount: itemCount, logicalBytes: logicalBytes, physicalBytes: physicalBytes)
  }
}

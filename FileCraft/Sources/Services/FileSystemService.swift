/*
 * FileSystemService.swift
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

import Darwin
import Foundation
import UniformTypeIdentifiers

/// Reads folder contents and item metadata from the file system.
///
/// The blocking file system calls run on the concurrent executor, so callers on the main actor never wait on disk I/O.
nonisolated internal struct FileSystemService: Sendable {

  // MARK: - Properties

  /// The resource values prefetched for every listed item.
  internal static let resourceKeys: [URLResourceKey] = [
    .nameKey,
    .localizedNameKey,
    .isDirectoryKey,
    .isPackageKey,
    .isHiddenKey,
    .hasHiddenExtensionKey,
    .isSymbolicLinkKey,
    .isAliasFileKey,
    .contentTypeKey,
    .localizedTypeDescriptionKey,
    .totalFileSizeKey,
    .totalFileAllocatedSizeKey,
    .creationDateKey,
    .contentModificationDateKey,
    .addedToDirectoryDateKey,
    .tagNamesKey,
  ]

  // MARK: - Reading

  /// Returns the items directly inside `directory`, in no particular order.
  ///
  /// Items that disappear while the folder is read are skipped.
  @concurrent
  internal func contentsOfDirectory(at directory: URL, includingHiddenItems: Bool) async throws -> [FileItem] {
    let urls = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: Self.resourceKeys,
      options: [])
    var items: [FileItem] = []
    items.reserveCapacity(urls.count)
    for (index, url) in urls.enumerated() {
      if index.isMultiple(of: 512) {
        try Task.checkCancellation()
      }
      guard let item = try? Self.makeItem(at: url) else {
        continue
      }
      if includingHiddenItems || item.isHidden == false {
        items.append(item)
      }
    }
    return items
  }

  /// Returns the item at `url`.
  @concurrent
  internal func item(at url: URL) async throws -> FileItem {
    try Self.makeItem(at: url)
  }

  /// Returns the items at `urls` that can be read, in the same order.
  @concurrent
  internal func items(at urls: [URL]) async -> [FileItem] {
    urls.compactMap { try? Self.makeItem(at: $0) }
  }

  /// Returns the space available on the volume containing `url`; see `Volume.availableCapacity(importantUsage:plain:)`.
  @concurrent
  internal func availableCapacity(of url: URL) async -> Int64? {
    let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
    return Volume.availableCapacity(importantUsage: values?.volumeAvailableCapacityForImportantUsage, plain: values?.volumeAvailableCapacity)
  }

  // MARK: - Items

  /// Reads the item at `url` synchronously, for callers that already run off the main actor.
  internal static func makeItem(at url: URL) throws -> FileItem {
    let values = try url.resourceValues(forKeys: Set(resourceKeys))
    let status = fileStatus(of: url)
    let isDirectory = values.isDirectory ?? false
    return FileItem(
      url: url,
      name: values.name,
      localizedName: values.localizedName,
      isDirectory: isDirectory,
      isPackage: values.isPackage ?? false,
      isHidden: values.isHidden ?? false,
      hasHiddenExtension: values.hasHiddenExtension ?? false,
      isSymbolicLink: values.isSymbolicLink ?? false,
      isAliasFile: values.isAliasFile ?? false,
      contentType: values.contentType,
      kind: values.localizedTypeDescription ?? "",
      size: isDirectory ? nil : values.totalFileSize.map(Int64.init),
      allocatedSize: isDirectory ? nil : values.totalFileAllocatedSize.map(Int64.init),
      creationDate: values.creationDate,
      modificationDate: values.contentModificationDate,
      addedDate: values.addedToDirectoryDate,
      tagNames: values.tagNames ?? [],
      permissions: status.map { UInt16($0.st_mode & 0o7777) },
      ownerID: status?.st_uid,
      groupID: status?.st_gid)
  }

  // MARK: - Private

  /// Reads the item's own status without following a symbolic link.
  private static func fileStatus(of url: URL) -> stat? {
    var status = stat()
    let result = url.withUnsafeFileSystemRepresentation { path -> Int32 in
      guard let path else {
        return -1
      }
      return lstat(path, &status)
    }
    return result == 0 ? status : nil
  }
}

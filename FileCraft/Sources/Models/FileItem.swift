/*
 * FileItem.swift
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
import UniformTypeIdentifiers

/// An immutable snapshot of a file system item with the metadata the views display.
nonisolated internal struct FileItem: Identifiable, Hashable, Sendable {

  // MARK: - Properties

  internal let url: URL
  /// The name on disk.
  internal let name: String
  /// The name macOS shows, which can be localized or lack a hidden extension.
  internal let localizedName: String
  internal let isDirectory: Bool
  internal let isPackage: Bool
  internal let isHidden: Bool
  internal let hasHiddenExtension: Bool
  internal let isSymbolicLink: Bool
  internal let isAliasFile: Bool
  internal let contentType: UTType?
  /// The localized kind, for example "PDF document".
  internal let kind: String
  /// The logical size of a file in bytes, or nil for folders.
  internal let size: Int64?
  /// The size on disk of a file in bytes, or nil for folders.
  internal let allocatedSize: Int64?
  internal let creationDate: Date?
  internal let modificationDate: Date?
  internal let addedDate: Date?
  /// The date the item was last opened. Spotlight provides it on demand, so folder listings leave it nil.
  internal let lastOpenedDate: Date?
  internal let tagNames: [String]
  /// The POSIX permission bits, for example `0o755`.
  internal let permissions: UInt16?
  internal let ownerID: UInt32?
  internal let groupID: UInt32?

  /// The item's path. Stored, because sets, dictionaries and filters of large folders look it up very often.
  internal let id: String

  internal var pathExtension: String {
    url.pathExtension
  }

  // MARK: - Initialization

  internal init(
    url: URL,
    name: String? = nil,
    localizedName: String? = nil,
    isDirectory: Bool = false,
    isPackage: Bool = false,
    isHidden: Bool = false,
    hasHiddenExtension: Bool = false,
    isSymbolicLink: Bool = false,
    isAliasFile: Bool = false,
    contentType: UTType? = nil,
    kind: String = "",
    size: Int64? = nil,
    allocatedSize: Int64? = nil,
    creationDate: Date? = nil,
    modificationDate: Date? = nil,
    addedDate: Date? = nil,
    lastOpenedDate: Date? = nil,
    tagNames: [String] = [],
    permissions: UInt16? = nil,
    ownerID: UInt32? = nil,
    groupID: UInt32? = nil
  ) {
    let resolvedName = name ?? url.lastPathComponent
    self.url = url
    self.id = url.path(percentEncoded: false)
    self.name = resolvedName
    self.localizedName = localizedName ?? resolvedName
    self.isDirectory = isDirectory
    self.isPackage = isPackage
    self.isHidden = isHidden
    self.hasHiddenExtension = hasHiddenExtension
    self.isSymbolicLink = isSymbolicLink
    self.isAliasFile = isAliasFile
    self.contentType = contentType
    self.kind = kind
    self.size = size
    self.allocatedSize = allocatedSize
    self.creationDate = creationDate
    self.modificationDate = modificationDate
    self.addedDate = addedDate
    self.lastOpenedDate = lastOpenedDate
    self.tagNames = tagNames
    self.permissions = permissions
    self.ownerID = ownerID
    self.groupID = groupID
  }

  // MARK: - Copies

  /// A copy of the item with `lastOpenedDate`, which Spotlight provides after listing.
  internal func with(lastOpenedDate: Date?) -> FileItem {
    FileItem(
      url: url, name: name, localizedName: localizedName, isDirectory: isDirectory, isPackage: isPackage,
      isHidden: isHidden, hasHiddenExtension: hasHiddenExtension, isSymbolicLink: isSymbolicLink,
      isAliasFile: isAliasFile, contentType: contentType, kind: kind, size: size, allocatedSize: allocatedSize,
      creationDate: creationDate, modificationDate: modificationDate, addedDate: addedDate,
      lastOpenedDate: lastOpenedDate, tagNames: tagNames, permissions: permissions, ownerID: ownerID,
      groupID: groupID)
  }
}

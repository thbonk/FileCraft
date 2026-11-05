/*
 * ItemCreator.swift
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

/// Creates new items: folders, empty text files, aliases and symbolic links, each under a free localized name such
/// as "untitled folder 2" or "Projects alias". Nothing existing is ever replaced.
nonisolated internal struct ItemCreator: Sendable {

  // MARK: - Properties

  internal var names = UniqueNameGenerator()

  // MARK: - Creating

  /// Creates a folder named "untitled folder", or the next free variant, in `folder`.
  @concurrent
  internal func makeFolder(in folder: URL) async throws -> URL {
    try create(in: folder, name: { names.untitledFolderName(existingNames: $0) }) { url in
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    }
  }

  /// Creates an empty plain-text file named "untitled.txt", or the next free variant, in `folder`.
  @concurrent
  internal func makeTextFile(in folder: URL) async throws -> URL {
    try create(in: folder, name: { names.untitledTextFileName(existingNames: $0) }, make: Self.makeEmptyFile)
  }

  /// Creates a Finder alias of `item`, named "<name> alias", next to it or in `folder`, as a drop with ⌥⌘ does.
  @concurrent
  internal func makeAlias(of item: URL, in folder: URL? = nil) async throws -> URL {
    let bookmark = try item.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
    return try create(in: folder ?? item.deletingLastPathComponent(), name: aliasName(of: item)) { url in
      // The empty file claims the name; writing the bookmark turns it into the alias.
      try Self.makeEmptyFile(at: url)
      do {
        try URL.writeBookmarkData(bookmark, to: url)
      } catch {
        try? FileManager.default.removeItem(at: url)
        throw error
      }
    }
  }

  /// Creates a symbolic link to `item` next to it, named like an alias. The link holds the absolute path of `item`,
  /// so that it keeps working when the link alone moves elsewhere.
  @concurrent
  internal func makeSymbolicLink(to item: URL) async throws -> URL {
    try create(in: item.deletingLastPathComponent(), name: aliasName(of: item)) { url in
      // A folder's URL ends with a slash, which the link's path leaves out.
      let destination = (item.path(percentEncoded: false) as NSString).standardizingPath
      try FileManager.default.createSymbolicLink(atPath: url.path(percentEncoded: false), withDestinationPath: destination)
    }
  }

  // MARK: - Private

  private func aliasName(of item: URL) -> ([String]) -> String {
    { names.aliasName(of: item.lastPathComponent, existingNames: $0) }
  }

  /// Creates an item under a free name; when another process takes the name meanwhile, the next free name follows.
  private func create(in folder: URL, name: ([String]) -> String, make: (URL) throws -> Void) throws -> URL {
    let maximumAttempts = 10
    for _ in 0..<maximumAttempts {
      let existingNames = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
      let url = folder.appending(path: name(existingNames))
      do {
        try make(url)
        return url
      } catch where Self.isNameTaken(error) {
        continue
      }
    }
    throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: folder.path(percentEncoded: false)])
  }

  /// Creates an empty file and fails when an item with its name exists.
  @Sendable
  private static func makeEmptyFile(at url: URL) throws {
    let descriptor = open(url.path(percentEncoded: false), O_CREAT | O_EXCL | O_WRONLY, 0o644)
    guard descriptor >= 0 else {
      throw OperationFailure.error(code: errno, item: url)
    }
    close(descriptor)
  }

  private static func isNameTaken(_ error: any Error) -> Bool {
    if let posixError = error as? POSIXError {
      return posixError.code == .EEXIST
    }
    if let cocoaError = error as? CocoaError {
      return cocoaError.code == .fileWriteFileExists
    }
    return false
  }
}

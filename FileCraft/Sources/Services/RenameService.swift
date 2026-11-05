/*
 * RenameService.swift
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

/// Renames items within their folder.
///
/// The file operation engine takes over renaming, with undo and the extension confirmation, in task group 9.
nonisolated internal struct RenameService: Sendable {

  /// Renames the item at `url` to `newName` and returns its new URL.
  ///
  /// An existing item with the new name is never replaced; changing only the case of a name is allowed.
  @concurrent
  internal func rename(_ url: URL, to newName: String) async throws -> URL {
    let destination = url.deletingLastPathComponent().appending(path: newName)
    let isCaseChangeOnly = url.lastPathComponent.lowercased() == newName.lowercased()
    let result = url.withUnsafeFileSystemRepresentation { sourcePath in
      destination.withUnsafeFileSystemRepresentation { destinationPath -> Int32 in
        guard let sourcePath, let destinationPath else {
          return -1
        }
        // RENAME_EXCL refuses to replace an existing item; a case-only change renames the item onto itself.
        return renamex_np(sourcePath, destinationPath, isCaseChangeOnly ? 0 : UInt32(RENAME_EXCL))
      }
    }
    guard result == 0 else {
      throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: url.path(percentEncoded: false)])
    }
    return destination
  }
}

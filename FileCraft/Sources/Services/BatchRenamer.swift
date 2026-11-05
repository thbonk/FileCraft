/*
 * BatchRenamer.swift
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

import Darwin
import Foundation

/// Why a batch rename failed; the renames already made were reverted.
nonisolated internal struct BatchRenameFailure: Error, Sendable {
  /// The item that could not be renamed.
  internal let url: URL
  /// The POSIX error code of the failed rename.
  internal let code: Int32

  internal var underlyingError: NSError {
    NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: [NSFilePathErrorKey: url.path(percentEncoded: false)])
  }
}

/// Renames a batch of items within their folders, all or nothing.
///
/// Every item first gets a temporary name in its folder and then its new name, so that names can be exchanged
/// within the batch, as "a" to "b" and "b" to "a". No rename replaces an existing item. When a rename fails, the
/// renames already made are reverted in reverse order.
nonisolated internal struct BatchRenamer: Sendable {

  // MARK: - Renaming

  /// Performs `moves`, each from an item's current URL to its new URL in the same folder. Moves that keep the
  /// name are skipped.
  @concurrent
  internal func rename(_ moves: [ItemMove]) async throws(BatchRenameFailure) {
    let moves = moves.filter { $0.from != $0.to }
    var temporary: [ItemMove] = []
    for move in moves {
      let parking = move.from.deletingLastPathComponent()
        .appending(path: ".filecraft-rename-\(UUID().uuidString)", directoryHint: .notDirectory)
      let code = Self.renameExclusively(move.from, to: parking)
      guard code == 0 else {
        Self.revert(temporary)
        throw BatchRenameFailure(url: move.from, code: code)
      }
      temporary.append(ItemMove(from: move.from, to: parking))
    }
    var finished: [ItemMove] = []
    for (move, parked) in zip(moves, temporary) {
      let code = Self.renameExclusively(parked.to, to: move.to)
      guard code == 0 else {
        Self.revert(finished)
        Self.revert(temporary)
        throw BatchRenameFailure(url: move.from, code: code)
      }
      finished.append(ItemMove(from: parked.to, to: move.to))
    }
  }

  // MARK: - Private

  /// Moves every item of `moves` back, last move first.
  private static func revert(_ moves: [ItemMove]) {
    for move in moves.reversed() {
      _ = renameExclusively(move.to, to: move.from)
    }
  }

  /// Renames without replacing an existing item and returns 0 or the POSIX error code.
  private static func renameExclusively(_ source: URL, to destination: URL) -> Int32 {
    source.withUnsafeFileSystemRepresentation { sourcePath in
      destination.withUnsafeFileSystemRepresentation { destinationPath -> Int32 in
        guard let sourcePath, let destinationPath else {
          return EINVAL
        }
        return renamex_np(sourcePath, destinationPath, UInt32(RENAME_EXCL)) == 0 ? 0 : errno
      }
    }
  }
}

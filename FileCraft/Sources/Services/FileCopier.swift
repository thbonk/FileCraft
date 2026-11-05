/*
 * FileCopier.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-03.
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
import Synchronization

/// Copies single items with `copyfile(3)` (design decision D10): data, extended attributes, access control lists,
/// permissions and dates, cloning on APFS where possible. Symbolic links are copied as links, never followed.
///
/// `FileOperationWorker` walks folders itself, so that every item inside them can be retried, skipped or merged:
/// it creates each folder with `makeFolder(at:)` and copies the folder's metadata with `copyMetadata(from:to:)`
/// after its contents. The calls block, so they run on a thread of their own.
nonisolated internal enum FileCopier {

  // MARK: - Copying

  /// Copies the file or symbolic link at `source` to `destination`, which must not exist.
  ///
  /// Pausing `control` holds the copy at its next progress report; cancelling it stops the copy. A partial copy is
  /// removed when the copy is cancelled or fails.
  ///
  /// - Throws: `CancellationError` when cancelled, `UnsupportedItemError` for items such as sockets, otherwise
  ///   the POSIX error of the failed copy.
  internal static func copyItem(_ source: URL, to destination: URL, cloning: Bool, control: OperationControl) throws {
    guard isCopyableItem(source) else {
      throw UnsupportedItemError()
    }
    guard let state = copyfile_state_alloc() else {
      throw POSIXError(.ENOMEM)
    }
    defer {
      copyfile_state_free(state)
    }
    let context = CopyCallbackContext(control: control)
    let callback: copyfile_callback_t = { what, stage, state, _, _, context in
      guard let context else {
        return COPYFILE_CONTINUE
      }
      return Unmanaged<CopyCallbackContext>.fromOpaque(context).takeUnretainedValue()
        .handle(what: what, stage: stage, state: state)
    }
    copyfile_state_set(state, UInt32(COPYFILE_STATE_STATUS_CB), unsafeBitCast(callback, to: UnsafeRawPointer.self))
    copyfile_state_set(state, UInt32(COPYFILE_STATE_STATUS_CTX), Unmanaged.passUnretained(context).toOpaque())

    var flags = COPYFILE_ALL | COPYFILE_NOFOLLOW | COPYFILE_EXCL
    if cloning {
      flags |= COPYFILE_CLONE
    }
    let code: Int32 = withExtendedLifetime(context) {
      source.withUnsafeFileSystemRepresentation { sourcePath in
        destination.withUnsafeFileSystemRepresentation { destinationPath in
          guard let sourcePath, let destinationPath else {
            return EINVAL
          }
          return copyfile(sourcePath, destinationPath, state, copyfile_flags_t(flags)) == 0 ? 0 : errno
        }
      }
    }
    if control.isCancelled {
      removePartialCopy(at: destination)
      throw CancellationError()
    }
    guard code == 0 else {
      // The callback stops a failed data copy, which makes copyfile report ECANCELED instead of the cause.
      let cause = context.failureCode.withLock { $0 } ?? code
      // An existing destination was not created by this call and stays.
      if cause != EEXIST {
        removePartialCopy(at: destination)
      }
      throw OperationFailure.error(code: cause, item: source)
    }
  }

  /// Creates the folder of a copied folder, accessible to the user while its contents are copied; the folder's
  /// own permissions follow with `copyMetadata(from:to:)`.
  internal static func makeFolder(at url: URL) throws {
    let code: Int32 = url.withUnsafeFileSystemRepresentation { path in
      guard let path else {
        return EINVAL
      }
      return mkdir(path, 0o700) == 0 ? 0 : errno
    }
    guard code == 0 else {
      throw OperationFailure.error(code: code, item: url)
    }
  }

  /// Copies the extended attributes, access control list, permissions, flags and dates of the folder `source` to
  /// the folder `destination`.
  internal static func copyMetadata(from source: URL, to destination: URL) throws {
    let code: Int32 = source.withUnsafeFileSystemRepresentation { sourcePath in
      destination.withUnsafeFileSystemRepresentation { destinationPath in
        guard let sourcePath, let destinationPath else {
          return EINVAL
        }
        let flags = copyfile_flags_t(COPYFILE_METADATA | COPYFILE_NOFOLLOW)
        return copyfile(sourcePath, destinationPath, nil, flags) == 0 ? 0 : errno
      }
    }
    guard code == 0 else {
      throw OperationFailure.error(code: code, item: source)
    }
  }

  /// The names of the items in `folder`, hidden ones included, in Finder order.
  internal static func childNames(of folder: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
      .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
  }

  // MARK: - Removing

  /// Removes the folder at `url` when it is empty.
  ///
  /// - Returns: false when the folder still contains items.
  @discardableResult
  internal static func removeFolderIfEmpty(at url: URL) throws -> Bool {
    let code: Int32 = url.withUnsafeFileSystemRepresentation { path in
      guard let path else {
        return EINVAL
      }
      return rmdir(path) == 0 ? 0 : errno
    }
    if code == ENOTEMPTY || code == EEXIST {
      return false
    }
    guard code == 0 else {
      throw OperationFailure.error(code: code, item: url)
    }
    return true
  }

  /// Deletes the file or symbolic link at `url`, never what a link points to.
  internal static func removeFile(at url: URL) throws {
    let code: Int32 = url.withUnsafeFileSystemRepresentation { path in
      guard let path else {
        return EINVAL
      }
      return unlink(path) == 0 ? 0 : errno
    }
    guard code == 0 else {
      throw OperationFailure.error(code: code, item: url)
    }
  }

  /// Removes a partial copy, also when folders inside it already got read-only permissions.
  internal static func removePartialCopy(at url: URL) {
    let path = url.path(percentEncoded: false)
    if isDirectory(url) {
      chmod(path, 0o700)
      let enumerator = FileManager.default.enumerator(atPath: path)
      while let relativePath = enumerator?.nextObject() as? String {
        let itemPath = (path as NSString).appendingPathComponent(relativePath)
        var status = stat()
        if lstat(itemPath, &status) == 0, status.st_mode & S_IFMT == S_IFDIR {
          chmod(itemPath, 0o700)
        }
      }
    }
    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Inspecting

  /// Whether `url` is a folder and not a link to one.
  internal static func isDirectory(_ url: URL) -> Bool {
    var status = stat()
    return lstat(url.path(percentEncoded: false), &status) == 0 && status.st_mode & S_IFMT == S_IFDIR
  }

  /// Whether `url` is a regular file and not a link or folder.
  internal static func isRegularFile(_ url: URL) -> Bool {
    var status = stat()
    return lstat(url.path(percentEncoded: false), &status) == 0 && status.st_mode & S_IFMT == S_IFREG
  }

  /// The size of the regular file at `path`, or 0.
  internal static func fileSize(atPath path: String) -> Int64 {
    var status = stat()
    guard lstat(path, &status) == 0, status.st_mode & S_IFMT == S_IFREG else {
      return 0
    }
    return Int64(status.st_size)
  }

  /// Whether `copyItem` copies the item at `url`: a regular file or a symbolic link. When the item cannot be
  /// inspected, the copy itself reports why.
  private static func isCopyableItem(_ url: URL) -> Bool {
    var status = stat()
    guard lstat(url.path(percentEncoded: false), &status) == 0 else {
      return true
    }
    let type = status.st_mode & S_IFMT
    return type == S_IFREG || type == S_IFLNK
  }
}

/// Receives the status callbacks of one `copyfile(3)` call: data progress, pausing and cancelling.
nonisolated private final class CopyCallbackContext: Sendable {

  let control: OperationControl
  /// The cause of a failed data copy, which copyfile replaces with ECANCELED once the callback stops it.
  let failureCode = Mutex<Int32?>(nil)

  init(control: OperationControl) {
    self.control = control
  }

  func handle(what: Int32, stage: Int32, state: copyfile_state_t?) -> Int32 {
    guard control.waitWhilePaused() else {
      return COPYFILE_QUIT
    }
    switch (what, stage) {
    case (COPYFILE_COPY_DATA, COPYFILE_PROGRESS):
      var copied: off_t = 0
      if let state, copyfile_state_get(state, UInt32(COPYFILE_STATE_COPIED), &copied) == 0 {
        control.update { $0.fileBytes = Int64(copied) }
      }
    case (COPYFILE_COPY_DATA, COPYFILE_ERR):
      let code = errno
      failureCode.withLock { $0 = code }
      return COPYFILE_QUIT
    case (COPYFILE_COPY_XATTR, COPYFILE_ERR):
      // An attribute that the destination refuses, such as one the system protects, is left out.
      return COPYFILE_SKIP
    default:
      break
    }
    return COPYFILE_CONTINUE
  }
}

/*
 * OperationFailure.swift
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

/// Turns the errors of file system calls into the reasons that the error dialog and the summary show.
///
/// POSIX errors become Cocoa errors, whose descriptions Foundation localizes and which name the item.
nonisolated internal enum OperationFailure {

  /// The error of a failed call with the POSIX `code`, carrying the path of `item`.
  internal static func error(code: Int32, item: URL) -> POSIXError {
    POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO, userInfo: [NSFilePathErrorKey: item.path(percentEncoded: false)])
  }

  /// The localized reason for `error`, which occurred while `item` was copied or moved to `target`.
  internal static func reason(for error: any Error, item: URL, target: URL) -> String {
    guard let posixError = error as? POSIXError else {
      return error.localizedDescription
    }
    return describe(code: posixError.code.rawValue, item: item, target: target)
  }

  /// Whether `error` means missing permissions, which "Authenticate and Retry" can overcome.
  internal static func isPermissionError(_ error: any Error) -> Bool {
    if let posixError = error as? POSIXError {
      return posixError.code == .EACCES || posixError.code == .EPERM
    }
    if let cocoaError = error as? CocoaError {
      return cocoaError.code == .fileReadNoPermission || cocoaError.code == .fileWriteNoPermission
    }
    return false
  }

  // MARK: - Private

  private static func describe(code: Int32, item: URL, target: URL) -> String {
    let readInfo: [String: Any] = [NSFilePathErrorKey: item.path(percentEncoded: false)]
    let writeInfo: [String: Any] = [NSFilePathErrorKey: target.path(percentEncoded: false)]
    switch code {
    case EACCES, EPERM:
      // Either the item cannot be read, or the destination folder cannot be written.
      if access(item.path(percentEncoded: false), R_OK) != 0 {
        return CocoaError(.fileReadNoPermission, userInfo: readInfo).localizedDescription
      }
      return CocoaError(.fileWriteNoPermission, userInfo: writeInfo).localizedDescription
    case ENOSPC, EDQUOT:
      return CocoaError(.fileWriteOutOfSpace, userInfo: writeInfo).localizedDescription
    case EROFS:
      return CocoaError(.fileWriteVolumeReadOnly, userInfo: writeInfo).localizedDescription
    case ENOENT:
      return CocoaError(.fileReadNoSuchFile, userInfo: readInfo).localizedDescription
    case EEXIST:
      return CocoaError(.fileWriteFileExists, userInfo: writeInfo).localizedDescription
    case ENAMETOOLONG:
      return CocoaError(.fileWriteInvalidFileName, userInfo: writeInfo).localizedDescription
    case EFBIG:
      // For example a file of more than 4 GB for a FAT32 volume.
      return String(localized: "The item is too large for the format of the destination volume.")
    default:
      var info = writeInfo
      info[NSUnderlyingErrorKey] = POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
      return CocoaError(.fileWriteUnknown, userInfo: info).localizedDescription
    }
  }
}

/// An item such as a socket or device file, which FileCraft does not copy.
nonisolated internal struct UnsupportedItemError: LocalizedError, Hashable, Sendable {

  internal var errorDescription: String? {
    String(localized: "Items of this kind can’t be copied.")
  }
}

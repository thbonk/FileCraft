/*
 * Quarantine.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-13.
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

/// The download quarantine of files, the `com.apple.quarantine` extended attribute, as far as App Translocation goes.
///
/// macOS runs a quarantined app from a temporary, read-only copy while its quarantine has the translocate flag and
/// lacks the do-not-translocate flag. Finder sets the latter when the user moves the app, and so does `copyfile(3)`
/// with `COPYFILE_RUN_IN_PLACE`; the quarantine itself stays, and with it Gatekeeper's checks. The flag values come
/// from Apple's SecTranslocate sources.
nonisolated internal enum Quarantine {

  // MARK: - Properties

  internal static let attributeName = "com.apple.quarantine"
  /// `QTN_FLAG_DO_NOT_TRANSLOCATE`.
  internal static let doNotTranslocateFlag: UInt32 = 0x0100

  // MARK: - Running in Place

  /// Lets the item at `url` run in place, as a move in Finder does; an item without quarantine stays without.
  ///
  /// - Returns: whether the quarantine changed.
  @discardableResult
  internal static func allowRunningInPlace(at url: URL) throws -> Bool {
    guard let value = try attributeValue(of: url), let updated = valueAllowingRunningInPlace(value) else {
      return false
    }
    try setAttributeValue(updated, of: url)
    return true
  }

  /// The quarantine `value`, "flags;time;agent;identifier", with the do-not-translocate flag added; nil when it has
  /// the flag already or is no quarantine value.
  internal static func valueAllowingRunningInPlace(_ value: String) -> String? {
    let fields = value.split(separator: ";", omittingEmptySubsequences: false)
    guard
      let flagsField = fields.first, (1...8).contains(flagsField.count), flagsField.allSatisfy(\.isHexDigit),
      let flags = UInt32(flagsField, radix: 16), flags & doNotTranslocateFlag == 0
    else {
      return nil
    }
    let updatedFlags = String(flags | doNotTranslocateFlag, radix: 16)
    let padding = String(repeating: "0", count: max(0, flagsField.count - updatedFlags.count))
    return ([padding + updatedFlags] + fields.dropFirst().map(String.init)).joined(separator: ";")
  }

  /// Whether `url` is an application bundle, whose quarantine decides about translocation.
  internal static func isApplicationBundle(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return url.pathExtension.caseInsensitiveCompare("app") == .orderedSame
      && FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
      && isDirectory.boolValue
  }

  // MARK: - Private

  private static func attributeValue(of url: URL) throws -> String? {
    let path = url.path(percentEncoded: false)
    let size = getxattr(path, attributeName, nil, 0, 0, XATTR_NOFOLLOW)
    guard size >= 0 else {
      if errno == ENOATTR {
        return nil
      }
      throw OperationFailure.error(code: errno, item: url)
    }
    var buffer = [UInt8](repeating: 0, count: size)
    let read = getxattr(path, attributeName, &buffer, size, 0, XATTR_NOFOLLOW)
    guard read >= 0 else {
      throw OperationFailure.error(code: errno, item: url)
    }
    return String(decoding: buffer.prefix(read), as: UTF8.self)
  }

  private static func setAttributeValue(_ value: String, of url: URL) throws {
    let result = setxattr(url.path(percentEncoded: false), attributeName, value, value.utf8.count, 0, XATTR_NOFOLLOW)
    guard result == 0 else {
      throw OperationFailure.error(code: errno, item: url)
    }
  }
}

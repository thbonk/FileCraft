/*
 * NameValidator.swift
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

/// Why a new name cannot be used.
nonisolated internal enum NameValidationError: Error, Hashable, Sendable {
  case empty
  /// The name contains ":" or "/".
  case invalidCharacter
  /// The name is longer than 255 bytes in UTF-8.
  case tooLong
  /// Another item in the folder already has this name.
  case alreadyExists(String)
}

/// Checks names entered for renaming against the rules of the `file-operations` capability.
nonisolated internal enum NameValidator {

  /// The longest name APFS and HFS+ accept, in UTF-8 bytes.
  internal static let maximumByteCount = 255

  /// Returns why `name` cannot replace `originalName`, or nil when it can.
  ///
  /// Names are compared case- and normalization-insensitively, so changing only the case of the
  /// original name is allowed.
  internal static func validate(
    _ name: String,
    originalName: String,
    existingNames: some Sequence<String>
  ) -> NameValidationError? {
    if name.trimmingCharacters(in: .whitespaces).isEmpty {
      return .empty
    }
    if name.contains(":") || name.contains("/") {
      return .invalidCharacter
    }
    if name.utf8.count > maximumByteCount {
      return .tooLong
    }
    let normalizedName = normalized(name)
    guard normalizedName != normalized(originalName) else {
      return nil
    }
    if existingNames.contains(where: { normalized($0) == normalizedName }) {
      return .alreadyExists(name)
    }
    return nil
  }

  private static func normalized(_ name: String) -> String {
    name.precomposedStringWithCanonicalMapping.lowercased()
  }
}

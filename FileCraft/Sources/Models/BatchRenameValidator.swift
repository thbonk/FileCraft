/*
 * BatchRenameValidator.swift
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

import Foundation

/// The outcome of one row of a batch rename preview.
nonisolated internal enum BatchRenameStatus: Hashable, Sendable {

  /// Why a new name cannot be used.
  internal enum Issue: Hashable, Sendable {
    case empty
    /// The name contains ":" or "/", or is "." or "..".
    case invalidCharacter
    /// The name is longer than 255 bytes in UTF-8.
    case tooLong
    /// Another item of the batch in the same folder gets the same name.
    case duplicate
    /// An item outside the batch in the same folder already has the name.
    case alreadyExists
  }

  case unchanged
  case renamed
  case invalid(Issue)

  internal var isError: Bool {
    if case .invalid = self {
      return true
    }
    return false
  }
}

/// One item of a batch: where it is and the name the rules give it.
nonisolated internal struct BatchRenameEntry: Hashable, Sendable {
  internal let url: URL
  internal let newName: String

  internal var folder: URL {
    url.deletingLastPathComponent()
  }

  internal var name: String {
    url.lastPathComponent
  }
}

/// Checks the new names of a batch rename against each other and against the other items of their folders.
nonisolated internal enum BatchRenameValidator {

  /// The status of each entry, in the same order.
  ///
  /// - Parameters:
  ///   - existingNames: The names of all items in each folder of the batch, by folder path, including the batch's
  ///     own items; names that the batch frees count as free.
  ///   - caseSensitiveFolders: The paths of the folders on case-sensitive volumes; other folders compare names
  ///     ignoring case.
  internal static func validate(
    _ entries: [BatchRenameEntry],
    existingNames: [String: [String]],
    caseSensitiveFolders: Set<String> = []
  ) -> [BatchRenameStatus] {
    // Final names per folder: every item of the batch ends up with its new name, changed or not.
    var finalNameCounts: [String: [String: Int]] = [:]
    var batchNames: [String: Set<String>] = [:]
    for entry in entries {
      let folder = folderKey(entry)
      let isCaseSensitive = caseSensitiveFolders.contains(folder)
      finalNameCounts[folder, default: [:]][normalized(entry.newName, isCaseSensitive), default: 0] += 1
      batchNames[folder, default: []].insert(normalized(entry.name, isCaseSensitive))
    }
    var outsideNames: [String: Set<String>] = [:]
    for (folder, names) in existingNames {
      let isCaseSensitive = caseSensitiveFolders.contains(folder)
      let own = batchNames[folder] ?? []
      outsideNames[folder] = Set(names.map { normalized($0, isCaseSensitive) }).subtracting(own)
    }
    return entries.map { entry in
      let folder = folderKey(entry)
      let isCaseSensitive = caseSensitiveFolders.contains(folder)
      if let issue = basicIssue(of: entry.newName) {
        return .invalid(issue)
      }
      let key = normalized(entry.newName, isCaseSensitive)
      if (finalNameCounts[folder]?[key] ?? 0) > 1 {
        return .invalid(.duplicate)
      }
      if entry.newName == entry.name {
        return .unchanged
      }
      if outsideNames[folder]?.contains(key) == true {
        return .invalid(.alreadyExists)
      }
      return .renamed
    }
  }

  /// The key of an entry's folder in `existingNames` and `caseSensitiveFolders`.
  internal static func folderKey(_ entry: BatchRenameEntry) -> String {
    entry.folder.path(percentEncoded: false)
  }

  // MARK: - Private

  private static func basicIssue(of name: String) -> BatchRenameStatus.Issue? {
    if name.trimmingCharacters(in: .whitespaces).isEmpty {
      return .empty
    }
    if name.contains(":") || name.contains("/") || name == "." || name == ".." {
      return .invalidCharacter
    }
    if name.utf8.count > NameValidator.maximumByteCount {
      return .tooLong
    }
    return nil
  }

  private static func normalized(_ name: String, _ isCaseSensitive: Bool) -> String {
    let composed = name.precomposedStringWithCanonicalMapping
    return isCaseSensitive ? composed : composed.lowercased()
  }
}

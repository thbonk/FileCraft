/*
 * FileReference.swift
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

/// A persistent reference to a file or folder that survives renames and moves.
///
/// The reference stores bookmark data together with the path at which the item
/// was last found. Equality and hashing use that last known path.
nonisolated internal struct FileReference: Codable, Hashable, Sendable {

  // MARK: - Types

  /// The result of resolving a reference.
  internal struct Resolution: Sendable {
    /// The item's current location.
    internal let url: URL
    /// Whether the bookmark data should be recreated.
    internal let isStale: Bool
  }

  // MARK: - Properties

  internal private(set) var bookmarkData: Data
  internal private(set) var lastKnownPath: String

  /// The item's URL at its last known location.
  internal var lastKnownURL: URL {
    URL(filePath: lastKnownPath)
  }

  // MARK: - Initialization

  /// Creates a reference to the item at `url`.
  internal init(url: URL) throws {
    bookmarkData = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    lastKnownPath = url.standardizedFileURL.path(percentEncoded: false)
  }

  /// Creates a reference that only knows the path, for items that may not exist.
  ///
  /// Resolving such a reference fails; callers fall back to `lastKnownURL`.
  internal init(unresolvedURL url: URL) {
    bookmarkData = Data()
    lastKnownPath = url.standardizedFileURL.path(percentEncoded: false)
  }

  // MARK: - Resolution

  /// Resolves the bookmark to the item's current location without mounting volumes or showing UI.
  internal func resolve() throws -> Resolution {
    var isStale = false
    let url = try URL(
      resolvingBookmarkData: bookmarkData,
      options: [.withoutUI, .withoutMounting],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale)
    return Resolution(url: url.standardizedFileURL, isStale: isStale)
  }

  /// Resolves the reference and updates the stored path and, when needed, the bookmark data.
  ///
  /// - Returns: The item's current location.
  @discardableResult
  internal mutating func refresh() throws -> URL {
    let resolution = try resolve()
    let path = resolution.url.path(percentEncoded: false)
    if resolution.isStale || path != lastKnownPath {
      bookmarkData = try resolution.url.bookmarkData(
        options: [],
        includingResourceValuesForKeys: nil,
        relativeTo: nil)
      lastKnownPath = path
    }
    return resolution.url
  }

  // MARK: - Equatable, Hashable

  internal static func == (lhs: FileReference, rhs: FileReference) -> Bool {
    lhs.lastKnownPath == rhs.lastKnownPath
  }

  internal func hash(into hasher: inout Hasher) {
    hasher.combine(lastKnownPath)
  }
}

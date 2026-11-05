/*
 * Location.swift
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

/// A place a tab can show.
nonisolated internal enum Location: Codable, Hashable, Sendable {
  /// A folder on disk.
  case folder(FileReference)
  /// The mounted volumes, like Finder's Computer location.
  case computer
  /// All items carrying a Finder tag, found through Spotlight.
  case tag(String)
  /// The results of a Subfolders or This Mac search.
  case search(SearchQuery)

  // MARK: - Properties

  /// The folder's URL at its last known location, or nil for virtual locations.
  internal var folderURL: URL? {
    switch self {
    case .folder(let reference):
      reference.lastKnownURL
    case .computer, .tag, .search:
      nil
    }
  }

  /// The name shown in tab titles and history menus.
  internal var displayName: String {
    switch self {
    case .folder(let reference):
      FileManager.default.displayName(atPath: reference.lastKnownPath)
    case .computer:
      ComputerName.current
    case .tag(let name):
      name
    case .search(let query):
      Self.searchTitle(for: query.parameters)
    }
  }

  /// The SF Symbol shown next to the location in menus.
  internal var systemImage: String {
    switch self {
    case .folder:
      "folder"
    case .computer:
      "desktopcomputer"
    case .tag:
      "tag"
    case .search:
      "magnifyingglass"
    }
  }

  /// The search shown at this location, or nil for other locations.
  internal var searchQuery: SearchQuery? {
    if case .search(let query) = self {
      return query
    }
    return nil
  }

  private static func searchTitle(for parameters: SearchParameters) -> String {
    guard parameters.text.isEmpty == false else {
      return String(localized: "Search Results")
    }
    return String(localized: "Search for “\(parameters.text)”")
  }
}

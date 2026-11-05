/*
 * SidebarItem.swift
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

import Foundation

/// An entry of the sidebar, used as its selection value.
nonisolated internal enum SidebarItem: Hashable, Sendable {
  case favorite(Favorite.ID)
  case computer
  /// A mounted volume, by its root folder.
  case volume(URL)
  case iCloudDrive
  case tag(String)

  // MARK: - Matching

  /// The entry that shows `location`, which the sidebar highlights: a favorite with the same folder first, then
  /// iCloud Drive or a volume whose root it is, Computer or a tag. Nil when no entry shows the location.
  internal static func matching(
    _ location: Location,
    favorites: [Favorite],
    volumes: [URL],
    iCloudDrive: URL?
  ) -> SidebarItem? {
    switch location {
    case .computer:
      return .computer
    case .tag(let name):
      return .tag(name)
    case .search:
      return nil
    case .folder(let reference):
      let path = reference.lastKnownPath.comparablePath
      if let favorite = favorites.first(where: { $0.reference.lastKnownPath.comparablePath == path }) {
        return .favorite(favorite.id)
      }
      if let iCloudDrive, iCloudDrive.comparablePath == path {
        return .iCloudDrive
      }
      return volumes.first { $0.comparablePath == path }.map(SidebarItem.volume)
    }
  }
}

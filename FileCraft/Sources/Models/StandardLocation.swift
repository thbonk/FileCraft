/*
 * StandardLocation.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-10-31.
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

/// The places the Go menu jumps to.
nonisolated internal enum StandardLocation: String, CaseIterable, Sendable {
  case computer
  case home
  case desktop
  case documents
  case downloads
  case applications
  case utilities
  case iCloudDrive
  /// The user's Library folder, shown while ⌥ is held.
  case library

  // MARK: - Properties

  /// The iCloud Drive folder inside the home folder.
  private static let iCloudDrivePath = "Library/Mobile Documents/com~apple~CloudDocs"

  // MARK: - Locations

  /// The folder of this location for the user whose home folder is `home`, or nil for Computer.
  internal func url(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL? {
    switch self {
    case .computer:
      nil
    case .home:
      home
    case .desktop:
      home.appending(path: "Desktop", directoryHint: .isDirectory)
    case .documents:
      home.appending(path: "Documents", directoryHint: .isDirectory)
    case .downloads:
      home.appending(path: "Downloads", directoryHint: .isDirectory)
    case .applications:
      URL(filePath: "/Applications", directoryHint: .isDirectory)
    case .utilities:
      URL(filePath: "/Applications/Utilities", directoryHint: .isDirectory)
    case .iCloudDrive:
      home.appending(path: Self.iCloudDrivePath, directoryHint: .isDirectory)
    case .library:
      home.appending(path: "Library", directoryHint: .isDirectory)
    }
  }

  /// Whether iCloud Drive is turned on for the user, which is the case when its folder exists.
  internal static func isICloudDriveAvailable(
    home: URL = FileManager.default.homeDirectoryForCurrentUser,
    fileManager: FileManager = .default
  ) -> Bool {
    var isDirectory: ObjCBool = false
    let path = home.appending(path: iCloudDrivePath).path(percentEncoded: false)
    return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
  }
}

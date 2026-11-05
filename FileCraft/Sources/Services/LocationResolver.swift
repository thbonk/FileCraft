/*
 * LocationResolver.swift
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

/// Finds folders that still exist for restored windows and new windows.
nonisolated internal enum LocationResolver {

  // MARK: - Restoring

  /// Returns the folder of `reference` if it still exists outside the Trash, otherwise the nearest existing
  /// ancestor of its last known path, otherwise the home folder.
  internal static func nearestExistingFolder(to reference: FileReference) -> URL {
    if let url = try? reference.resolve().url, isDirectory(url), isInTrash(url) == false {
      return url
    }
    var candidate = reference.lastKnownURL
    while candidate.path(percentEncoded: false) != "/" {
      if isDirectory(candidate) {
        return candidate
      }
      candidate = candidate.deletingLastPathComponent()
    }
    return FileManager.default.homeDirectoryForCurrentUser
  }

  /// Replaces the current folder of every tab in `snapshot` with its nearest existing folder.
  @concurrent
  internal static func resolved(_ snapshot: BrowserWindowSnapshot) async -> BrowserWindowSnapshot {
    var snapshot = snapshot
    snapshot.primaryPane = resolved(snapshot.primaryPane)
    snapshot.secondaryPane = snapshot.secondaryPane.map(resolved)
    return snapshot
  }

  // MARK: - New Windows

  /// Returns the folder that new windows show according to the General settings, or the home folder
  /// when that folder does not exist.
  internal static func newWindowFolder(for setting: NewWindowLocation, chosenPath: String, lastPath: String) -> URL {
    let fileManager = FileManager.default
    let home = fileManager.homeDirectoryForCurrentUser
    let candidate: URL? =
      switch setting {
      case .home:
        home
      case .desktop:
        fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
      case .documents:
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
      case .lastLocation:
        lastPath.isEmpty ? nil : URL(filePath: lastPath, directoryHint: .isDirectory)
      case .chosenFolder:
        chosenPath.isEmpty ? nil : URL(filePath: chosenPath, directoryHint: .isDirectory)
      }
    guard let candidate, isDirectory(candidate) else {
      return home
    }
    return candidate
  }

  // MARK: - Private

  private static func resolved(_ pane: PaneSnapshot) -> PaneSnapshot {
    var pane = pane
    pane.tabs = pane.tabs.map { tab in
      guard case .folder(let reference) = tab.history.current else {
        return tab
      }
      let folder = nearestExistingFolder(to: reference)
      guard
        folder.standardizedFileURL.path(percentEncoded: false) != reference.lastKnownPath,
        let replacement = try? FileReference(url: folder)
      else {
        return tab
      }
      var tab = tab
      tab.history.replaceCurrent(with: .folder(replacement))
      return tab
    }
    return pane
  }

  private static func isDirectory(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
  }

  private static func isInTrash(_ url: URL) -> Bool {
    let components = url.pathComponents
    return components.contains(".Trash") || components.contains(".Trashes")
  }
}

/*
 * WorkspaceActions.swift
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

import AppKit
import Foundation

/// Hands items to other applications through `NSWorkspace`.
internal enum WorkspaceActions {

  private static let finderBundleIdentifier = "com.apple.finder"
  private static let terminalBundleIdentifier = "com.apple.Terminal"

  /// Opens `url` with its default application.
  internal static func open(_ url: URL) {
    NSWorkspace.shared.open(url)
  }

  /// Opens `urls` with the application at `application`.
  internal static func open(_ urls: [URL], withApplicationAt application: URL) {
    NSWorkspace.shared.open(urls, withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration())
  }

  /// Shows `urls` selected in Finder.
  ///
  /// While FileCraft is the default file viewer, a reveal request would come back to FileCraft, so Finder opens
  /// the enclosing folders instead, without selecting the items.
  internal static func revealInFinder(_ urls: [URL], fileCraftIsFileViewer: Bool) {
    guard urls.isEmpty == false else {
      return
    }
    guard fileCraftIsFileViewer else {
      NSWorkspace.shared.activateFileViewerSelecting(urls)
      return
    }
    guard let finder = NSWorkspace.shared.urlForApplication(withBundleIdentifier: finderBundleIdentifier) else {
      return
    }
    var seenPaths = Set<String>()
    let folders = urls.map { $0.deletingLastPathComponent() }.filter { seenPaths.insert($0.path(percentEncoded: false)).inserted }
    open(folders, withApplicationAt: finder)
  }

  /// Opens a terminal session in each of `folders` with the application `bundleIdentifier`, or with Terminal when
  /// that application is not installed.
  ///
  /// - Returns: false when no terminal application was found.
  @discardableResult
  internal static func openInTerminal(_ folders: [URL], bundleIdentifier: String) -> Bool {
    let workspace = NSWorkspace.shared
    guard
      let terminal = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
        ?? workspace.urlForApplication(withBundleIdentifier: terminalBundleIdentifier)
    else {
      return false
    }
    open(folders, withApplicationAt: terminal)
    return true
  }

  /// Moves `urls` to the Trash the way Finder does, so that Finder's Put Back works.
  internal static func moveToTrash(_ urls: [URL]) async throws {
    _ = try await NSWorkspace.shared.recycle(urls)
  }

  /// Opens Privacy & Security > Full Disk Access in System Settings.
  internal static func openFullDiskAccessSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
      return
    }
    NSWorkspace.shared.open(url)
  }

  /// Moves `urls` to the Trash the way Finder does and reports where each item went. Items that could not be moved
  /// are missing from the result; unlike `moveToTrash(_:)`, one failed item does not hide the others' new places.
  internal static func recycle(_ urls: [URL]) async -> [URL: URL] {
    await withCheckedContinuation { continuation in
      NSWorkspace.shared.recycle(urls) { trashedURLs, _ in
        continuation.resume(returning: trashedURLs)
      }
    }
  }
}

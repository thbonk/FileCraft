/*
 * GoCommands.swift
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

import SwiftUI

/// The Go menu: history, the enclosing folder, recent folders and the standard locations. Commands act on
/// the active tab of the key browser window.
internal struct GoCommands: Commands {

  // MARK: - Properties

  internal let recents: RecentsStore

  @FocusedValue(\.browserWindow) private var window

  /// Whether iCloud Drive is turned on; checked once per launch.
  private static let showsICloudDrive = StandardLocation.isICloudDriveAvailable()

  // MARK: - Body

  internal var body: some Commands {
    CommandMenu("Go") {
      Button("Back") {
        window?.activeTab.goBack()
      }
      .keyboardShortcut("[", modifiers: .command)
      .disabled(window?.activeTab.history.canGoBack != true)
      Button("Forward") {
        window?.activeTab.goForward()
      }
      .keyboardShortcut("]", modifiers: .command)
      .disabled(window?.activeTab.history.canGoForward != true)
      Button("Enclosing Folder") {
        window?.activeTab.goToEnclosingFolder()
      }
      .keyboardShortcut(.upArrow, modifiers: .command)
      .disabled(window?.activeTab.canGoToEnclosingFolder != true)
      Divider()
      recentFolders
      Divider()
      locationButton(.computer)
      locationButton(.home)
        .modifierKeyAlternate(.option) {
          locationButton(.library)
        }
      locationButton(.desktop)
      locationButton(.documents)
      locationButton(.downloads)
      locationButton(.applications)
      locationButton(.utilities)
      if Self.showsICloudDrive {
        locationButton(.iCloudDrive)
      }
      Divider()
      Button("Go to Folder…") {
        window?.isShowingGoToFolder = true
      }
      .keyboardShortcut("g", modifiers: [.shift, .command])
      .disabled(window == nil)
    }
  }

  // MARK: - Private

  private var recentFolders: some View {
    Menu("Recent Folders") {
      ForEach(recents.folders, id: \.lastKnownPath) { folder in
        Button(Location.folder(folder).displayName, systemImage: "folder") {
          window?.activeTab.navigate(to: .folder(folder))
        }
      }
      if recents.folders.isEmpty == false {
        Divider()
      }
      Button("Clear Menu") {
        recents.clear()
      }
      .disabled(recents.folders.isEmpty)
    }
    .disabled(window == nil)
  }

  private func locationButton(_ location: StandardLocation) -> some View {
    Button(location.title) {
      guard let tab = window?.activeTab else {
        return
      }
      if let url = location.url() {
        tab.navigate(toFolder: url)
      } else {
        tab.navigate(to: .computer)
      }
    }
    .keyboardShortcut(location.keyboardShortcut)
    .disabled(window == nil)
  }
}

extension StandardLocation {
  /// The Go menu shortcut from the menus-and-shortcuts spec; Library has none, it replaces Home while ⌥ is held.
  fileprivate var keyboardShortcut: KeyboardShortcut? {
    switch self {
    case .computer:
      KeyboardShortcut("c", modifiers: [.shift, .command])
    case .home:
      KeyboardShortcut("h", modifiers: [.shift, .command])
    case .desktop:
      KeyboardShortcut("d", modifiers: [.shift, .command])
    case .documents:
      KeyboardShortcut("o", modifiers: [.shift, .command])
    case .downloads:
      KeyboardShortcut("l", modifiers: [.option, .command])
    case .applications:
      KeyboardShortcut("a", modifiers: [.shift, .command])
    case .utilities:
      KeyboardShortcut("u", modifiers: [.shift, .command])
    case .iCloudDrive:
      KeyboardShortcut("i", modifiers: [.shift, .command])
    case .library:
      nil
    }
  }
}

/*
 * TabCommands.swift
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

import AppKit
import SwiftUI

/// The tab commands of the File and Window menus. They act on the active pane of the key browser window.
///
/// ⌃⇥ and ⌃⇧⇥ switch tabs too; the browser window handles them, because a menu item has only one shortcut.
internal struct TabCommands: Commands {

  // MARK: - Properties

  @FocusedValue(\.browserWindow) private var window
  @Environment(\.openWindow) private var openWindow

  // MARK: - Body

  internal var body: some Commands {
    // Declared before BrowserCommands, so that New Tab follows New Window directly.
    CommandGroup(after: .newItem) {
      Button("New Tab") {
        window?.newTab()
      }
      .keyboardShortcut("t", modifiers: .command)
      .disabled(window == nil)
    }
    // Replaces the standard Close items: ⌘W closes the tab, ⇧⌘W the window. While another window is in front, such as
    // Settings or Keyboard Shortcuts, ⌘W closes that window, as the replaced system item did.
    CommandGroup(replacing: .saveItem) {
      Button(window == nil ? "Close" : "Close Tab") {
        if let window {
          window.closeTab()
        } else {
          NSApp.keyWindow?.performClose(nil)
        }
      }
      .keyboardShortcut("w", modifiers: .command)
      Button("Close Window") {
        window?.requestClose()
      }
      .keyboardShortcut("w", modifiers: [.shift, .command])
      .disabled(window == nil)
    }
    CommandGroup(before: .windowList) {
      Button("Show Next Tab") {
        window?.selectNextTab()
      }
      .keyboardShortcut("]", modifiers: [.shift, .command])
      .disabled((window?.activePane.tabs.count ?? 0) < 2)
      Button("Show Previous Tab") {
        window?.selectPreviousTab()
      }
      .keyboardShortcut("[", modifiers: [.shift, .command])
      .disabled((window?.activePane.tabs.count ?? 0) < 2)
      Divider()
      Button("Reopen Closed Tab") {
        window?.reopenClosedTab()
      }
      .keyboardShortcut("t", modifiers: [.shift, .command])
      .disabled(window?.closedTabs.isEmpty ?? true)
      Menu("Recently Closed Tabs") {
        ForEach(window?.closedTabs ?? []) { closedTab in
          Button(closedTab.title) {
            window?.reopenClosedTab(closedTab.id)
          }
        }
      }
      .disabled(window?.closedTabs.isEmpty ?? true)
      Button("Operations") {
        openWindow(id: OperationsView.windowID)
      }
      Divider()
    }
  }
}

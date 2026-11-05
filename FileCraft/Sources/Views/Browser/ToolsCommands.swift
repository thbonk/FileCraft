/*
 * ToolsCommands.swift
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

/// The Tools menu.
internal struct ToolsCommands: Commands {

  // MARK: - Properties

  @FocusedValue(\.browserWindow) private var window
  @FocusedValue(\.focusedFileTab) private var focusedFileTab
  @AppStorage(SettingsKeys.usesFunctionKeys.name) private var usesFunctionKeys = SettingsKeys.usesFunctionKeys.defaultValue

  // MARK: - Body

  internal var body: some Commands {
    CommandMenu("Tools") {
      Button("Batch Rename…") {
        window?.requestBatchRename()
      }
      .keyboardShortcut("r", modifiers: [.shift, .command])
      .disabled(window?.activeTab.selection.isEmpty ?? true)
      Divider()
      otherPaneButton("Copy to Other Pane", kind: .copy, key: FunctionKey.f5)
      otherPaneButton("Move to Other Pane", kind: .move, key: FunctionKey.f6)
      Button("Show Same Folder in Other Pane") {
        window?.showSameFolderInOtherPane()
      }
      .disabled(window?.otherPane == nil)
      Divider()
      Button("Open in Terminal") {
        window?.activeTab.openInTerminal()
      }
      .disabled(window?.activeTab.hasPathTargets != true)
      Button("Reveal in Finder") {
        window?.activeTab.revealInFinder()
      }
      .disabled(window?.activeTab.hasPathTargets != true)
    }
  }

  // MARK: - Private

  /// Copy or Move to Other Pane. Its function key acts only while a file view has focus and the function-key
  /// setting is on; the menu item works whenever dual pane is on and items are selected.
  private func otherPaneButton(_ title: LocalizedStringKey, kind: FileOperationKind, key: KeyEquivalent) -> some View {
    let urls = window?.fileCommands.selectedURLs ?? []
    let shortcut = usesFunctionKeys && focusedFileTab != nil ? KeyboardShortcut(key, modifiers: []) : nil
    return Button(title) {
      guard let commands = window?.fileCommands else {
        return
      }
      Task { await commands.transferToOtherPane(urls, kind: kind) }
    }
    .keyboardShortcut(shortcut)
    .disabled(urls.isEmpty || window?.fileCommands.otherPaneFolder == nil)
  }
}

/// The function keys of the file commands, as AppKit reports them.
internal enum FunctionKey {
  internal static let f5 = KeyEquivalent("\u{F708}")
  internal static let f6 = KeyEquivalent("\u{F709}")
  internal static let f7 = KeyEquivalent("\u{F70A}")
  internal static let f8 = KeyEquivalent("\u{F70B}")
}

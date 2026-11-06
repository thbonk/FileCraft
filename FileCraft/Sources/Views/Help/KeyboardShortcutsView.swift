/*
 * KeyboardShortcutsView.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-06.
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

/// Help > Keyboard Shortcuts: the default shortcuts grouped by menu, with a search field.
///
/// The keys are shown as on a US keyboard; the menus show them adapted to the active keyboard layout.
internal struct KeyboardShortcutsView: View {

  // MARK: - Properties

  internal static let windowID = "keyboardShortcuts"

  @State private var searchText = ""

  // MARK: - Body

  internal var body: some View {
    let sections = ShortcutCatalog.sections(matching: searchText)
    List {
      ForEach(sections, id: \.menu) { section in
        Section {
          ForEach(section.entries) { entry in
            LabeledContent {
              Text(verbatim: entry.shortcuts.map(\.symbols).joined(separator: ", "))
                .monospaced()
                .foregroundStyle(.secondary)
            } label: {
              Text(entry.title)
            }
          }
        } header: {
          Text(section.menu.title)
        }
      }
    }
    .overlay {
      if sections.isEmpty {
        ContentUnavailableView.search(text: searchText)
      }
    }
    .searchable(text: $searchText, placement: .toolbar, prompt: Text("Search Shortcuts"))
    .frame(minWidth: 420, idealWidth: 480, minHeight: 400, idealHeight: 560)
  }
}

/// Help menu commands.
internal struct HelpCommands: Commands {

  @Environment(\.openWindow) private var openWindow

  internal var body: some Commands {
    CommandGroup(after: .help) {
      Button("Keyboard Shortcuts") {
        openWindow(id: KeyboardShortcutsView.windowID)
      }
      Button("Welcome to FileCraft…") {
        openWindow(id: WelcomeView.windowID)
      }
    }
  }
}

#Preview {
  KeyboardShortcutsView()
}

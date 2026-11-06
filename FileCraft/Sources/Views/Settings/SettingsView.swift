/*
 * SettingsView.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-05.
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
import UniformTypeIdentifiers

/// The Settings window (⌘,) with its nine panes. Every control writes its preference at once, and all windows read
/// the preferences live, so changes apply without a relaunch.
internal struct SettingsView: View {

  // MARK: - Body

  internal var body: some View {
    TabView {
      Tab("General", systemImage: "gearshape") {
        GeneralSettingsPane()
      }
      Tab("Browser", systemImage: "folder") {
        BrowserSettingsPane()
      }
      Tab("Sidebar", systemImage: "sidebar.left") {
        SidebarSettingsPane()
      }
      Tab("Tabs & Panes", systemImage: "rectangle.split.2x1") {
        TabsAndPanesSettingsPane()
      }
      Tab("File Operations", systemImage: "doc.on.doc") {
        FileOperationsSettingsPane()
      }
      Tab("Compression", systemImage: "archivebox") {
        CompressionSettingsPane()
      }
      Tab("Integration", systemImage: "puzzlepiece.extension") {
        IntegrationSettingsPane()
      }
      Tab("Helper", systemImage: "lock.shield") {
        HelperSettingsPane()
      }
      Tab("Advanced", systemImage: "gearshape.2") {
        AdvancedSettingsPane()
      }
    }
    .scenePadding()
    // The window must be wide enough for all nine tab labels in the toolbar; at 600 pt the German labels pushed the
    // last tabs into the toolbar's overflow, where they could not be selected. German needs about 810 pt.
    .frame(width: Self.width)
  }

  /// The width of the Settings window, which fits the nine tab labels in English and German.
  internal static let width: CGFloat = 880
}

/// One pane of Settings: a grouped form followed by Restore Defaults for the pane's preferences.
internal struct SettingsPaneForm<Content: View>: View {

  // MARK: - Properties

  internal let pane: SettingsPane
  @ViewBuilder internal let content: Content

  // MARK: - Body

  internal var body: some View {
    VStack(spacing: 0) {
      Form {
        content
      }
      .formStyle(.grouped)
      .scrollDisabled(true)
      .fixedSize(horizontal: false, vertical: true)
      HStack {
        Spacer()
        Button("Restore Defaults") {
          SettingsStore().restoreDefaults(of: pane)
        }
        .help(Text("Restores the default values of this pane."))
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
    }
  }
}

/// A folder chosen in Settings: its path and a button that opens a folder chooser.
internal struct SettingsFolderChooser: View {

  // MARK: - Properties

  @Binding internal var path: String

  @State private var isChoosing = false

  // MARK: - Body

  internal var body: some View {
    LabeledContent {
      Button("Choose…") {
        isChoosing = true
      }
    } label: {
      Text(verbatim: path.isEmpty ? String(localized: "No folder chosen") : (path as NSString).abbreviatingWithTildeInPath)
        .lineLimit(1)
        .truncationMode(.middle)
        .foregroundStyle(.secondary)
    }
    .fileImporter(isPresented: $isChoosing, allowedContentTypes: [.folder]) { result in
      if case .success(let url) = result {
        path = url.path(percentEncoded: false)
      }
    }
  }
}

#Preview {
  SettingsView()
}

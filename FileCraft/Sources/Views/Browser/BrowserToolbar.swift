/*
 * BrowserToolbar.swift
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

import SwiftUI

/// The customizable toolbar of a browser window. Items act on the active pane.
///
/// Items whose features are not implemented yet are disabled.
internal struct BrowserToolbar: CustomizableToolbarContent {

  // MARK: - Properties

  internal let window: BrowserWindowModel

  // MARK: - Body

  internal var body: some CustomizableToolbarContent {
    ToolbarItem(id: "backForward", placement: .navigation) {
      BackForwardControl(tab: window.activeTab)
    }
    ToolbarItem(id: "viewMode") {
      ViewModePicker(tab: window.activeTab)
    }
    ToolbarItem(id: "groupSort") {
      GroupSortMenu(tab: window.activeTab)
    }
    ToolbarItem(id: "action") {
      ActionMenu(window: window)
    }
    ToolbarItem(id: "share") {
      ShareButton(tab: window.activeTab)
    }
    ToolbarItem(id: "dualPane") {
      DualPaneToggle(window: window)
    }
    ToolbarItem(id: "inspector") {
      InspectorToggle(window: window)
    }
    ToolbarItem(id: "newFolder", showsByDefault: false) {
      Button("New Folder", systemImage: "folder.badge.plus") {
        Task { await window.fileCommands.newFolder() }
      }
      .help("New Folder")
      .disabled(window.fileCommands.canCreateItems == false)
    }
    ToolbarItem(id: "moveToTrash", showsByDefault: false) {
      Button("Move to Trash", systemImage: "trash") {
        let urls = window.fileCommands.selectedURLs
        Task { await window.fileCommands.moveToTrash(urls) }
      }
      .help("Move to Trash")
      .disabled(window.fileCommands.selectedURLs.isEmpty)
    }
    ToolbarItem(id: "getInfo", showsByDefault: false) {
      Button("Get Info", systemImage: "info.circle") {
        window.requestInfoWindows()
      }
      .disabled(window.activeTab.hasPathTargets == false)
      .help(Text("Get Info"))
    }
    ToolbarItem(id: "shelf", showsByDefault: false) {
      ShelfToggle(window: window)
    }
    ToolbarItem(id: "hiddenFiles", showsByDefault: false) {
      HiddenFilesToggle()
    }
    ToolbarItem(id: "quickLook", showsByDefault: false) {
      QuickLookButton(tab: window.activeTab)
    }
    ToolbarItem(id: "compress", showsByDefault: false) {
      Button("Compress", systemImage: "archivebox") {
        let urls = window.fileCommands.selectedURLs
        Task { await window.fileCommands.compress(urls) }
      }
      .help("Compress")
      .disabled(window.fileCommands.selectedURLs.isEmpty)
    }
    ToolbarItem(id: "openInTerminal", showsByDefault: false) {
      OpenInTerminalButton(tab: window.activeTab)
    }
    ToolbarItem(id: "eject", showsByDefault: false) {
      Button("Eject", systemImage: "eject") {
        Task { await window.fileCommands.eject() }
      }
      .help("Eject")
      .disabled(window.fileCommands.ejectableVolume == nil)
    }
    ToolbarItem(id: "operations", showsByDefault: false) {
      OperationsToolbarButton(model: .shared)
    }
    ToolbarItem(id: "search") {
      SearchToolbarField(window: window)
    }
  }
}

// MARK: - Items

/// Back and Forward: a click goes one step, pressing and holding lists the history for direct jumps.
private struct BackForwardControl: View {

  let tab: TabModel

  var body: some View {
    ControlGroup {
      HistoryButton(title: "Back", systemImage: "chevron.backward", entries: tab.history.backMenu) {
        tab.goBack()
      } jump: { index in
        tab.goBack(toMenuIndex: index)
      }
      HistoryButton(title: "Forward", systemImage: "chevron.forward", entries: tab.history.forwardMenu) {
        tab.goForward()
      } jump: { index in
        tab.goForward(toMenuIndex: index)
      }
    } label: {
      Label("Back/Forward", systemImage: "chevron.backward")
    }
  }
}

private struct HistoryButton: View {

  let title: LocalizedStringKey
  let systemImage: String
  let entries: [NavigationHistory.MenuEntry]
  let step: () -> Void
  let jump: (Int) -> Void

  var body: some View {
    Menu {
      ForEach(entries) { entry in
        Button(entry.location.displayName, systemImage: entry.location.systemImage) {
          jump(entry.index)
        }
      }
    } label: {
      Label(title, systemImage: systemImage)
    } primaryAction: {
      step()
    }
    .menuIndicator(.hidden)
    .disabled(entries.isEmpty)
    .help(Text(title))
  }
}

private struct OpenInTerminalButton: View {

  let tab: TabModel

  var body: some View {
    Button("Open in Terminal", systemImage: "terminal") {
      tab.openInTerminal()
    }
    .disabled(tab.folderURL == nil && tab.selection.isEmpty)
    .help(Text("Open in Terminal"))
  }
}

private struct QuickLookButton: View {

  let tab: TabModel

  var body: some View {
    Button("Quick Look", systemImage: "eye") {
      tab.toggleQuickLook()
    }
    .disabled(tab.selection.isEmpty)
    .help(Text("Quick Look"))
  }
}

private struct ViewModePicker: View {

  @Bindable var tab: TabModel

  var body: some View {
    Picker("View", selection: $tab.viewSettings.viewMode) {
      Label("as Icons", systemImage: "square.grid.2x2")
        .tag(ViewMode.icons)
      Label("as List", systemImage: "list.bullet")
        .tag(ViewMode.list)
      Label("as Columns", systemImage: "rectangle.split.3x1")
        .tag(ViewMode.columns)
    }
    .pickerStyle(.segmented)
    .help(Text("View"))
  }
}

private struct GroupSortMenu: View {

  @Bindable var tab: TabModel

  var body: some View {
    Menu {
      Picker("Group By", selection: $tab.viewSettings.grouping) {
        ForEach(GroupingKey.allCases, id: \.self) { key in
          Text(key.title).tag(key)
        }
      }
      Picker("Sort By", selection: $tab.viewSettings.sortOrder.key) {
        ForEach(SortKey.allCases, id: \.self) { key in
          Text(key.title).tag(key)
        }
      }
      Picker("Order", selection: $tab.viewSettings.sortOrder.isAscending) {
        Text("Ascending").tag(true)
        Text("Descending").tag(false)
      }
      Toggle("Folders First", isOn: $tab.viewSettings.sortOrder.foldersFirst)
    } label: {
      Label("Group/Sort", systemImage: "square.grid.3x1.below.line.grid.1x2")
    }
    .help(Text("Group and Sort"))
  }
}

private struct ActionMenu: View {

  let window: BrowserWindowModel

  @AppStorage(SettingsKeys.showsHiddenFiles.name) private var showsHiddenFiles = SettingsKeys.showsHiddenFiles.defaultValue

  var body: some View {
    Menu {
      Button("New Folder") {
        Task { await window.fileCommands.newFolder() }
      }
      .disabled(window.fileCommands.canCreateItems == false)
      Button("Get Info") {
        window.requestInfoWindows()
      }
      .disabled(window.activeTab.hasPathTargets == false)
      Divider()
      Toggle("Show Hidden Files", isOn: $showsHiddenFiles)
    } label: {
      Label("Action", systemImage: "ellipsis.circle")
    }
    .help(Text("Action"))
  }
}

private struct ShareButton: View {

  let tab: TabModel

  var body: some View {
    let urls = tab.selectedItems.map(\.url)
    ShareLink(items: urls) {
      Label("Share", systemImage: "square.and.arrow.up")
    }
    .disabled(urls.isEmpty)
    .help(Text("Share"))
  }
}

private struct DualPaneToggle: View {

  let window: BrowserWindowModel

  var body: some View {
    Toggle(isOn: Binding(get: { window.isDualPaneVisible }, set: { window.setDualPaneVisible($0) })) {
      Label("Dual Pane", systemImage: "rectangle.split.2x1")
    }
    .toggleStyle(.button)
    .help(Text("Dual Pane"))
  }
}

private struct InspectorToggle: View {

  @Bindable var window: BrowserWindowModel

  var body: some View {
    Toggle(isOn: $window.layout.isInspectorVisible) {
      Label("Inspector", systemImage: "sidebar.trailing")
    }
    .toggleStyle(.button)
    .help(Text("Inspector"))
  }
}

private struct ShelfToggle: View {

  @Bindable var window: BrowserWindowModel

  var body: some View {
    Toggle(isOn: $window.layout.isShelfVisible) {
      Label("Shelf", systemImage: "tray")
    }
    .toggleStyle(.button)
    .help(Text("Shelf"))
  }
}

private struct HiddenFilesToggle: View {

  @AppStorage(SettingsKeys.showsHiddenFiles.name) private var showsHiddenFiles = SettingsKeys.showsHiddenFiles.defaultValue

  var body: some View {
    Toggle(isOn: $showsHiddenFiles) {
      Label("Hidden Files", systemImage: "eye.slash")
    }
    .toggleStyle(.button)
    .help(Text("Hidden Files"))
  }
}

/// A toolbar button for a feature that is not available yet.

#Preview {
  NavigationStack {
    Text("Content")
      .frame(width: 900, height: 200)
      .toolbar(id: "preview") {
        BrowserToolbar(window: .preview(in: .english))
      }
  }
}

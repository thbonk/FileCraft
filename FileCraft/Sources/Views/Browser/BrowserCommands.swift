/*
 * BrowserCommands.swift
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

/// The File, Edit and View menu commands of browser windows. They act on the key window through `FocusedValues.browserWindow`.
internal struct BrowserCommands: Commands {

  // MARK: - Properties

  internal let favorites: FavoritesStore
  internal var shelf: ShelfStore = .shared

  @FocusedValue(\.browserWindow) private var window
  @FocusedValue(\.focusedFileTab) private var focusedFileTab
  @AppStorage(SettingsKeys.showsHiddenFiles.name) private var showsHiddenFiles = SettingsKeys.showsHiddenFiles.defaultValue
  @Environment(\.openWindow) private var openWindow

  // MARK: - Body

  internal var body: some Commands {
    // FileCraft's own Show Sidebar replaces the system's, so that it can follow the view commands in the order of
    // the menus spec; the system group would sit after the toolbar commands.
    CommandGroup(replacing: .sidebar) {}
    ToolbarCommands()
    CommandGroup(after: .newItem) {
      newItemButtons
      Divider()
      Button("Open") {
        window?.activeTab.openSelection()
      }
      .keyboardShortcut("o", modifiers: .command)
      .disabled(window?.activeTab.selection.isEmpty ?? true)
      openWithMenu
      Button("Open in New Tab") {
        guard let tab = window?.activeTab else {
          return
        }
        tab.openInNewTabs(tab.selectedItems)
      }
      .disabled(window?.activeTab.selection.isEmpty ?? true)
      Button("Open in Other Pane") {
        guard let window, let folder = window.activeTab.selectedItems.first(where: window.activeTab.opensAsFolder) else {
          return
        }
        window.openInOtherPane(folder)
      }
      .disabled(window?.otherPane == nil || window?.activeTab.selection.count != 1)
    }
    // After Close Tab and Close Window, in the order of the menus spec.
    CommandGroup(after: .saveItem) {
      Button("Get Info") {
        window?.requestInfoWindows()
      }
      .keyboardShortcut("i", modifiers: .command)
      .disabled(window?.activeTab.hasPathTargets != true)
      itemButtons
      Button("Show Original") {
        guard let tab = window?.activeTab, let link = tab.selectedLink else {
          return
        }
        Task {
          await tab.showOriginal(of: link)
        }
      }
      .keyboardShortcut("r", modifiers: .command)
      .disabled(window?.activeTab.selectedLink == nil)
      Button("Quick Look") {
        window?.activeTab.toggleQuickLook()
      }
      .keyboardShortcut("y", modifiers: .command)
      .disabled(window?.activeTab.selection.isEmpty ?? true)
      Button("Add to Sidebar") {
        guard let urls = window?.activeTab.pathTargets else {
          return
        }
        Task {
          await favorites.add(urls)
        }
      }
      .keyboardShortcut("t", modifiers: [.control, .command])
      .disabled(window?.activeTab.hasPathTargets != true)
      Button("Add to Shelf") {
        guard let window else {
          return
        }
        let urls = window.activeTab.pathTargets
        // The shelf appears, so that the added items can be seen.
        window.layout.isShelfVisible = true
        Task {
          await shelf.add(urls)
        }
      }
      .disabled(window?.activeTab.hasPathTargets != true)
      Button("Copy To…") {
        fileCommands?.requestTransfer(of: selectedURLs, kind: .copy)
      }
      .disabled(selectedURLs.isEmpty)
      Button("Move To…") {
        fileCommands?.requestTransfer(of: selectedURLs, kind: .move)
      }
      .disabled(selectedURLs.isEmpty)
      archiveButtons
      Divider()
      trashButtons
      Button("Tags…") {
        window?.isShowingTags = true
      }
      .disabled(window?.activeTab.hasPathTargets != true)
    }
    CommandGroup(before: .toolbar) {
      viewModeButton("as Icons", mode: .icons, key: "1")
      viewModeButton("as List", mode: .list, key: "2")
      viewModeButton("as Columns", mode: .columns, key: "3")
      Divider()
      Picker("Group By", selection: grouping) {
        ForEach(GroupingKey.allCases, id: \.self) { key in
          Text(key.title).tag(key)
        }
      }
      .disabled(window == nil)
      Picker("Sort By", selection: sortKey) {
        ForEach(SortKey.allCases, id: \.self) { key in
          Text(key.title).tag(key)
        }
      }
      .disabled(window == nil)
      Toggle("Folders First", isOn: foldersFirst)
        .disabled(window == nil)
      Divider()
      Button(title(isVisible: showsHiddenFiles, show: "Show Hidden Files", hide: "Hide Hidden Files")) {
        showsHiddenFiles.toggle()
      }
      .keyboardShortcut(".", modifiers: [.shift, .command])
      Toggle("Treat Packages as Folders", isOn: treatsPackagesAsFolders)
        .disabled(window == nil)
      Button("Reload") {
        window?.activeTab.reload()
      }
      .disabled(window == nil)
      Divider()
      Button(title(isVisible: window?.layout.isSidebarVisible, show: "Show Sidebar", hide: "Hide Sidebar")) {
        window?.layout.isSidebarVisible.toggle()
      }
      .keyboardShortcut("s", modifiers: [.control, .command])
      .disabled(window == nil)
      Button(title(isVisible: window?.layout.isInspectorVisible, show: "Show Inspector", hide: "Hide Inspector")) {
        window?.layout.isInspectorVisible.toggle()
      }
      .keyboardShortcut("i", modifiers: [.option, .command])
      .disabled(window == nil)
      Button(title(isVisible: window?.layout.isShelfVisible, show: "Show Shelf", hide: "Hide Shelf")) {
        window?.layout.isShelfVisible.toggle()
      }
      .disabled(window == nil)
      Divider()
      Toggle("Dual Pane", isOn: dualPane)
        .keyboardShortcut("b", modifiers: [.option, .command])
        .disabled(window == nil)
      Picker("Pane Layout", selection: paneLayout) {
        Text("Side by Side").tag(PaneLayout.sideBySide)
        Text("Stacked").tag(PaneLayout.stacked)
      }
      .disabled(window == nil)
      Button("Equalize Pane Sizes") {
        window?.equalizePaneSizes()
      }
      .disabled(window?.isDualPaneVisible != true)
      Button("Swap Panes") {
        window?.swapPanes()
      }
      .disabled(window?.isDualPaneVisible != true)
      Button(title(isVisible: window?.layout.showsTabBar, show: "Show Tab Bar", hide: "Hide Tab Bar")) {
        window?.layout.showsTabBar.toggle()
      }
      .disabled(window == nil)
      Divider()
      Button(title(isVisible: window?.layout.isPathBarVisible, show: "Show Path Bar", hide: "Hide Path Bar")) {
        window?.layout.isPathBarVisible.toggle()
      }
      .keyboardShortcut("p", modifiers: [.option, .command])
      .disabled(window == nil)
      Button(title(isVisible: window?.layout.isStatusBarVisible, show: "Show Status Bar", hide: "Hide Status Bar")) {
        window?.layout.isStatusBarVisible.toggle()
      }
      .keyboardShortcut("/", modifiers: .command)
      .disabled(window == nil)
    }
    // After the system's Hide Toolbar and Customize Toolbar…, in the order of the menus spec.
    CommandGroup(after: .toolbar) {
      Button("Show View Options") {
        openWindow(id: ViewOptionsView.windowID)
      }
      .keyboardShortcut("j", modifiers: .command)
    }
    // The system's Cut, Copy, Paste and Select All stay, because file views copy and paste through them; FileCraft's
    // Edit commands follow Select All.
    CommandGroup(after: .pasteboard) {
      Button("Move Items Here") {
        run { await $0.moveItemsHere() }
      }
      .keyboardShortcut("v", modifiers: [.option, .command])
      .disabled(fileCommands?.canCreateItems != true || fileViewHasFocus == false)
      Button("Copy Path") {
        window?.activeTab.copyPaths(as: .posix)
      }
      .keyboardShortcut("c", modifiers: [.option, .command])
      .disabled(window?.activeTab.hasPathTargets != true)
      Menu("Copy Path As") {
        ForEach(PathFormat.allCases, id: \.self) { format in
          Button(format.title) {
            window?.activeTab.copyPaths(as: format)
          }
        }
      }
      .disabled(window?.activeTab.hasPathTargets != true)
      Button("Edit Path") {
        window?.layout.isPathBarVisible = true
        window?.activeTab.isEditingPath = true
      }
      .disabled(window?.activeTab.folderURL == nil)
      Divider()
      Button("Deselect All") {
        window?.activeTab.deselectAll()
      }
      .keyboardShortcut("a", modifiers: [.option, .command])
      .disabled(window == nil)
      Button("Invert Selection") {
        window?.activeTab.invertSelection()
      }
      .disabled(window == nil)
      Button("Select by Pattern…") {
        window?.isShowingSelectByPattern = true
      }
      .disabled(window == nil)
      Divider()
      Button("Find") {
        window?.focusSearchField()
      }
      .keyboardShortcut("f", modifiers: .command)
      .disabled(window == nil)
    }
  }

  // MARK: - File Commands

  private var fileCommands: FileCommandModel? {
    window?.fileCommands
  }

  private var selectedURLs: [URL] {
    fileCommands?.selectedURLs ?? []
  }

  /// Whether a file view has keyboard focus and no name is being edited, so that ⌘⌫ and ⌥⌘⌫ act on files and
  /// not on text.
  private var fileViewHasFocus: Bool {
    focusedFileTab != nil && focusedFileTab?.renamingItemID == nil
  }

  @ViewBuilder private var newItemButtons: some View {
    Button("New Folder") {
      run { await $0.newFolder() }
    }
    .keyboardShortcut("n", modifiers: [.shift, .command])
    .disabled(fileCommands?.canCreateItems != true)
    Button("New Folder with Selection") {
      let urls = selectedURLs
      run { await $0.newFolderWithSelection(urls) }
    }
    .keyboardShortcut("n", modifiers: [.control, .command])
    .disabled(fileCommands?.canCreateItems != true || selectedURLs.isEmpty)
    Button("New Text File") {
      run { await $0.newTextFile() }
    }
    .keyboardShortcut("n", modifiers: [.option, .command])
    .disabled(fileCommands?.canCreateItems != true)
  }

  @ViewBuilder private var itemButtons: some View {
    Button("Rename") {
      guard let tab = window?.activeTab, let item = tab.selectedItems.first else {
        return
      }
      tab.beginRename(item)
    }
    .disabled(window?.activeTab.selection.count != 1 || window?.activeTab.renamingItemID != nil)
    Button("Duplicate") {
      let urls = selectedURLs
      run { await $0.duplicate(urls) }
    }
    .keyboardShortcut("d", modifiers: .command)
    .disabled(selectedURLs.isEmpty)
    Button("Make Alias") {
      let urls = selectedURLs
      run { await $0.makeAlias(urls) }
    }
    .keyboardShortcut("a", modifiers: [.control, .command])
    .disabled(selectedURLs.isEmpty)
    Button("Make Symbolic Link") {
      let urls = selectedURLs
      run { await $0.makeSymbolicLink(urls) }
    }
    .disabled(selectedURLs.isEmpty)
  }

  @ViewBuilder private var archiveButtons: some View {
    Button("Compress") {
      let urls = selectedURLs
      run { await $0.compress(urls) }
    }
    .disabled(selectedURLs.isEmpty)
    Menu("Compress With Format") {
      ForEach(CompressionFormat.allCases, id: \.self) { format in
        Button {
          let urls = selectedURLs
          run { await $0.compress(urls, format: format) }
        } label: {
          Text(verbatim: format.title)
        }
      }
    }
    .disabled(selectedURLs.isEmpty)
    Button("Expand") {
      let urls = selectedURLs
      run { await $0.expand(urls) }
    }
    .disabled(fileCommands?.canExpand(selectedURLs) != true)
  }

  @ViewBuilder private var trashButtons: some View {
    Button("Move to Trash") {
      let urls = selectedURLs
      run { await $0.moveToTrash(urls) }
    }
    .keyboardShortcut(.delete, modifiers: .command)
    .disabled(selectedURLs.isEmpty || fileViewHasFocus == false)
    Button("Delete Immediately…") {
      fileCommands?.requestDeleteImmediately(selectedURLs)
    }
    .keyboardShortcut(.delete, modifiers: [.option, .command])
    .disabled(selectedURLs.isEmpty || fileViewHasFocus == false)
    Button("Put Back") {
      let urls = selectedURLs
      run { await $0.putBack(urls) }
    }
    .disabled(fileCommands?.canPutBack(selectedURLs) != true)
    Button("Empty Trash…") {
      run { await $0.requestEmptyTrash() }
    }
    .keyboardShortcut(.delete, modifiers: [.shift, .command])
    .disabled(window == nil)
    Button("Eject") {
      run { await $0.eject() }
    }
    .keyboardShortcut("e", modifiers: .command)
    .disabled(fileCommands?.ejectableVolume == nil)
  }

  /// Runs a file command of the key window.
  private func run(_ command: @escaping @MainActor (FileCommandModel) async -> Void) {
    guard let fileCommands else {
      return
    }
    Task {
      await command(fileCommands)
    }
  }

  // MARK: - Private

  /// File > Open With, from the applications the tab looked up for its selection.
  private var openWithMenu: some View {
    OpenWithMenu(applications: window?.activeTab.openWithApplications ?? []) {
      window?.activeTab.applicationChoiceRequest = window?.activeTab.selectedItems.map(\.url)
    } open: { application in
      guard let urls = window?.activeTab.selectedItems.map(\.url) else {
        return
      }
      WorkspaceActions.open(urls, withApplicationAt: application)
    }
    .disabled(window?.activeTab.selection.isEmpty ?? true)
  }

  private var dualPane: Binding<Bool> {
    Binding {
      window?.isDualPaneVisible ?? false
    } set: { isVisible in
      window?.setDualPaneVisible(isVisible)
    }
  }

  private var treatsPackagesAsFolders: Binding<Bool> {
    Binding {
      window?.activeTab.viewSettings.treatsPackagesAsFolders ?? false
    } set: { treatsPackagesAsFolders in
      window?.activeTab.viewSettings.treatsPackagesAsFolders = treatsPackagesAsFolders
    }
  }

  private var grouping: Binding<GroupingKey> {
    Binding {
      window?.activeTab.viewSettings.grouping ?? .none
    } set: { grouping in
      window?.activeTab.viewSettings.grouping = grouping
    }
  }

  private var sortKey: Binding<SortKey> {
    Binding {
      window?.activeTab.viewSettings.sortOrder.key ?? .name
    } set: { key in
      window?.activeTab.viewSettings.sortOrder.key = key
    }
  }

  private var foldersFirst: Binding<Bool> {
    Binding {
      window?.activeTab.viewSettings.sortOrder.foldersFirst ?? true
    } set: { foldersFirst in
      window?.activeTab.viewSettings.sortOrder.foldersFirst = foldersFirst
    }
  }

  private var paneLayout: Binding<PaneLayout> {
    Binding {
      window?.layout.paneLayout ?? .sideBySide
    } set: { layout in
      window?.layout.paneLayout = layout
    }
  }

  private func viewModeButton(_ title: LocalizedStringKey, mode: ViewMode, key: KeyEquivalent) -> some View {
    Button(title) {
      window?.activeTab.viewSettings.viewMode = mode
    }
    .keyboardShortcut(key, modifiers: .command)
    .disabled(window == nil)
  }

  /// The title naming the next action of a show/hide toggle.
  private func title(isVisible: Bool?, show: LocalizedStringKey, hide: LocalizedStringKey) -> LocalizedStringKey {
    isVisible == true ? hide : show
  }
}

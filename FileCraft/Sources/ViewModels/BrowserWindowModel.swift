/*
 * BrowserWindowModel.swift
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
import Observation

/// A tab that was closed, kept for Reopen Closed Tab.
nonisolated internal struct ClosedTab: Identifiable, Sendable {
  internal let id = UUID()
  internal let snapshot: TabSnapshot
  internal let title: String
  /// Whether the tab was in the second pane.
  internal let isFromSecondaryPane: Bool
  /// The tab's position in its pane.
  internal let index: Int
}

/// The state of one browser window: its panes, the active pane and the layout.
///
/// The secondary pane survives while dual pane is hidden, so showing it again restores its tabs.
@Observable
internal final class BrowserWindowModel {

  // MARK: - Properties

  /// The number of closed tabs a window remembers.
  internal static let closedTabLimit = 10
  /// The number of Get Info windows that open without asking first.
  internal static let infoWindowLimit = 10
  /// The browser window that was active last, which Get Info windows show items in; see `ActiveBrowserWindow`.
  internal static var mostRecentlyActive: BrowserWindowModel? {
    get {
      ActiveBrowserWindow.shared.window
    }
    set {
      if let newValue {
        ActiveBrowserWindow.shared.activate(newValue)
      }
    }
  }

  internal private(set) var primaryPane: PaneModel
  internal private(set) var secondaryPane: PaneModel?
  internal private(set) var isDualPaneVisible = false
  internal private(set) var isSecondaryPaneActive = false
  internal var layout = WindowLayout()
  /// Whether the Go to Folder sheet is open.
  internal var isShowingGoToFolder = false
  /// Whether the Select by Pattern sheet is open.
  internal var isShowingSelectByPattern = false
  /// Whether the File > Tags… sheet is open.
  internal var isShowingTags = false
  /// The batch rename shown in a sheet, or nil.
  internal var batchRename: BatchRenameModel?
  /// Increases when the window's view should open a new browser window for the location waiting in
  /// `NewWindowQueue`.
  internal private(set) var newWindowRequest = 0
  /// Increases when the search field should take keyboard focus, as after Edit > Find.
  internal private(set) var searchFocusRequest = 0
  /// The tabs closed most recently, newest first.
  internal private(set) var closedTabs: [ClosedTab] = []
  /// Increases when the window should close, as after closing its last tab; the window's view closes it.
  internal private(set) var closeRequest = 0
  /// The items File > Get Info should open windows for; the window's view opens them, after asking for more than
  /// `infoWindowLimit` items.
  internal var infoWindowRequest: [FileReference] = []
  /// Handed to the panes the window creates, so that their tabs record visited folders.
  @ObservationIgnored internal let recents: RecentsStore?
  /// The file commands of the window, which act on the active tab.
  internal let fileCommands: FileCommandModel

  /// The pane that menu commands, toolbar items and the inspector refer to.
  internal var activePane: PaneModel {
    if isDualPaneVisible, isSecondaryPaneActive, let secondaryPane {
      return secondaryPane
    }
    return primaryPane
  }

  internal var activeTab: TabModel {
    activePane.currentTab
  }

  /// The pane that is not active, or nil while dual pane is off.
  internal var otherPane: PaneModel? {
    otherPane(of: activePane)
  }

  /// The window title: the display name of the active pane's location.
  internal var title: String {
    activeTab.title
  }

  internal var snapshot: BrowserWindowSnapshot {
    BrowserWindowSnapshot(
      primaryPane: primaryPane.snapshot,
      secondaryPane: secondaryPane?.snapshot,
      isDualPaneVisible: isDualPaneVisible,
      isSecondaryPaneActive: isSecondaryPaneActive,
      layout: layout)
  }

  // MARK: - Initialization

  internal init(primaryPane: PaneModel, recents: RecentsStore? = nil, fileCommands: FileCommandModel = FileCommandModel()) {
    self.primaryPane = primaryPane
    self.recents = recents
    self.fileCommands = fileCommands
    primaryPane.window = self
    fileCommands.window = self
  }

  /// A window at `location`; `recents` records the folders its tabs visit.
  internal convenience init(location: Location, recents: RecentsStore? = nil) {
    self.init(primaryPane: PaneModel(location: location, recents: recents), recents: recents)
  }

  // MARK: - Restoration

  /// Replaces the window's state with `snapshot`; panes without tabs open `fallback`.
  internal func restore(from snapshot: BrowserWindowSnapshot, fallback: Location) {
    primaryPane = PaneModel(snapshot: snapshot.primaryPane, fallback: fallback, recents: recents)
    primaryPane.window = self
    secondaryPane = snapshot.secondaryPane.map { PaneModel(snapshot: $0, fallback: fallback, recents: recents) }
    secondaryPane?.window = self
    isDualPaneVisible = snapshot.isDualPaneVisible && secondaryPane != nil
    isSecondaryPaneActive = snapshot.isSecondaryPaneActive && isDualPaneVisible
    layout = snapshot.layout
  }

  // MARK: - Panes

  /// Shows or hides the second pane. The first time, it opens at the active tab's location in the layout chosen
  /// in Settings.
  internal func setDualPaneVisible(
    _ isVisible: Bool,
    defaultLayout: PaneLayout = SettingsStore().value(for: SettingsKeys.dualPaneLayout)
  ) {
    if isVisible {
      if secondaryPane == nil {
        let pane = PaneModel(location: activeTab.location, recents: recents)
        pane.window = self
        secondaryPane = pane
        layout.paneLayout = defaultLayout
      }
      isDualPaneVisible = true
    } else {
      isDualPaneVisible = false
      isSecondaryPaneActive = false
    }
  }

  internal func toggleDualPane() {
    setDualPaneVisible(isDualPaneVisible == false)
  }

  /// Makes `pane` the active pane.
  internal func activate(_ pane: PaneModel) {
    isSecondaryPaneActive = isDualPaneVisible && pane === secondaryPane
  }

  internal func isActive(_ pane: PaneModel) -> Bool {
    pane === activePane
  }

  /// The pane next to `pane`, or nil while dual pane is off.
  internal func otherPane(of pane: PaneModel) -> PaneModel? {
    guard isDualPaneVisible, let secondaryPane else {
      return nil
    }
    return pane === primaryPane ? secondaryPane : primaryPane
  }

  /// Exchanges the contents of the two panes; the active contents stay active.
  internal func swapPanes() {
    guard isDualPaneVisible, let secondaryPane else {
      return
    }
    self.secondaryPane = primaryPane
    primaryPane = secondaryPane
    isSecondaryPaneActive.toggle()
  }

  internal func equalizePaneSizes() {
    layout.paneSplitFraction = 0.5
  }

  /// Moves keyboard focus and activation to the other pane, as Tab does in a file view.
  ///
  /// - Returns: false while dual pane is off.
  @discardableResult
  internal func focusOtherPane() -> Bool {
    guard let otherPane else {
      return false
    }
    activate(otherPane)
    otherPane.currentTab.requestFocus()
    return true
  }

  /// Shows the active tab's location in the other pane's current tab.
  internal func showSameFolderInOtherPane() {
    otherPane?.currentTab.navigate(to: activeTab.location)
  }

  /// Shows `folder` in the other pane's current tab.
  internal func openInOtherPane(_ folder: FileItem) {
    otherPane?.currentTab.navigate(toFolder: folder.url)
  }

  // MARK: - Tabs

  /// Adds a tab after the current tab of `pane`, the active pane by default, at the location chosen in Settings.
  internal func newTab(
    in pane: PaneModel? = nil,
    location setting: NewTabLocation = SettingsStore().value(for: SettingsKeys.newTabLocation),
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) {
    let target = pane ?? activePane
    let location: Location =
      switch setting {
      case .currentLocation:
        target.currentTab.location
      case .home:
        (try? FileReference(url: homeDirectory)).map(Location.folder) ?? target.currentTab.location
      }
    target.addTab(TabModel(location: location, recents: recents))
    activate(target)
  }

  /// Closes `tab`, the active tab by default, and remembers it for Reopen Closed Tab.
  ///
  /// The last tab of the second pane turns dual pane off; the last tab of the first pane hands the window to the
  /// second pane while dual pane is on, and otherwise closes the window.
  internal func closeTab(_ tab: TabModel? = nil) {
    let tab = tab ?? activeTab
    guard let pane = pane(containing: tab) else {
      return
    }
    if pane.tabs.count > 1 {
      remember(tab, in: pane)
      pane.removeTab(tab)
    } else if pane === secondaryPane {
      remember(tab, in: pane)
      endDualPane()
    } else if isDualPaneVisible, let secondaryPane {
      remember(tab, in: pane)
      primaryPane = secondaryPane
      endDualPane()
    } else {
      closeRequest += 1
    }
  }

  /// Closes all tabs of `tab`'s pane except `tab`.
  internal func closeOtherTabs(than tab: TabModel) {
    guard let pane = pane(containing: tab) else {
      return
    }
    for other in pane.tabs.reversed() where other !== tab {
      remember(other, in: pane)
      pane.removeTab(other)
    }
    pane.select(tab)
  }

  /// Asks the window's view to close the window, as File > Close Window does.
  internal func requestClose() {
    closeRequest += 1
  }

  internal func selectNextTab() {
    activePane.selectNextTab()
  }

  internal func selectPreviousTab() {
    activePane.selectPreviousTab()
  }

  /// Reopens the closed tab `id`, or the most recently closed tab, with its history, in the pane it came from.
  internal func reopenClosedTab(_ id: ClosedTab.ID? = nil) {
    let index = id.map { id in closedTabs.firstIndex { $0.id == id } } ?? (closedTabs.isEmpty ? nil : 0)
    guard let index else {
      return
    }
    let closed = closedTabs.remove(at: index)
    let tab = TabModel(snapshot: closed.snapshot, recents: recents)
    let pane: PaneModel
    if closed.isFromSecondaryPane {
      if let secondaryPane {
        secondaryPane.insertTab(tab, at: closed.index)
        pane = secondaryPane
      } else {
        pane = PaneModel(tab: tab, recents: recents)
        pane.window = self
        secondaryPane = pane
      }
      isDualPaneVisible = true
    } else {
      primaryPane.insertTab(tab, at: closed.index)
      pane = primaryPane
    }
    activate(pane)
  }

  /// Moves the tab `id` into `destination` before `target`, or to its end: within a pane this reorders the tab,
  /// across panes it moves the tab with its history. The first pane keeps its last tab; moving the last tab out of
  /// the second pane turns dual pane off.
  internal func moveTab(withID id: TabModel.ID, to destination: PaneModel, before target: TabModel?) {
    guard let tab = allTabs.first(where: { $0.id == id }), let source = pane(containing: tab), tab !== target else {
      return
    }
    if source === destination {
      destination.moveTab(tab, before: target)
      return
    }
    if source.tabs.count > 1 {
      source.removeTab(tab)
    } else if source === secondaryPane {
      endDualPane()
    } else {
      return
    }
    destination.insertTab(tab, before: target)
    activate(destination)
  }

  // MARK: - New Windows

  /// Opens a new browser window showing `location`.
  internal func requestNewWindow(showing location: Location) {
    NewWindowQueue.push(location)
    newWindowRequest += 1
  }

  // MARK: - Batch Rename

  /// Opens the batch rename sheet for the selected items of the active tab, in the order shown.
  internal func requestBatchRename() {
    let items = activeTab.selectedItems
    guard items.isEmpty == false else {
      return
    }
    batchRename = BatchRenameModel(items: items)
  }

  // MARK: - Search

  /// Moves keyboard focus to the search field, as Edit > Find does.
  internal func focusSearchField() {
    searchFocusRequest += 1
  }

  // MARK: - Get Info

  /// Asks for one Get Info window per selected item, or for the current folder without a selection.
  internal func requestInfoWindows() {
    infoWindowRequest = activeTab.pathTargets.compactMap { try? FileReference(url: $0) }
  }

  // MARK: - Sidebar

  /// Shows `location` in the active tab, or in a new tab of the active pane.
  internal func show(_ location: Location, inNewTab: Bool) {
    guard inNewTab else {
      activeTab.navigate(to: location)
      return
    }
    activePane.addTab(TabModel(location: location, recents: recents))
  }

  /// Sends the tabs showing a folder on the unmounted volume at `volume` to the home folder.
  internal func volumeDidUnmount(_ volume: URL, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
    let root = volume.comparablePath
    guard root != "/" else {
      return
    }
    for tab in allTabs {
      guard let folder = tab.folderURL?.comparablePath, folder == root || folder.hasPrefix(root + "/") else {
        continue
      }
      tab.navigate(toFolder: homeDirectory)
    }
  }

  // MARK: - Open Requests

  /// Whether the window still shows only the tab it was created with, without any navigation.
  internal var isUntouched: Bool {
    secondaryPane == nil
      && primaryPane.tabs.count == 1
      && primaryPane.currentTab.history.canGoBack == false
      && primaryPane.currentTab.history.canGoForward == false
  }

  /// Shows `item`, which the Dock or another application asked FileCraft to open: a folder in a new tab of the
  /// active pane, any other item revealed in its folder in a new tab. `usesCurrentTab` shows it in the active tab
  /// instead, for a window that was created for the request.
  internal func showRequested(_ item: FileItem, usesCurrentTab: Bool) {
    let opensAsFolder = item.isDirectory && item.isPackage == false
    if usesCurrentTab {
      if opensAsFolder {
        activeTab.navigate(toFolder: item.url)
      } else {
        activeTab.reveal(item.url)
      }
      return
    }
    let folder = opensAsFolder ? item.url : item.url.deletingLastPathComponent()
    guard let reference = try? FileReference(url: folder) else {
      return
    }
    let tab = TabModel(location: .folder(reference), recents: recents)
    activePane.addTab(tab)
    if opensAsFolder == false {
      tab.reveal(item.url)
    }
  }

  // MARK: - Private

  private var allTabs: [TabModel] {
    primaryPane.tabs + (secondaryPane?.tabs ?? [])
  }

  private func pane(containing tab: TabModel) -> PaneModel? {
    [primaryPane, secondaryPane].compactMap(\.self).first { $0.index(of: tab) != nil }
  }

  /// Removes the second pane, as after its last tab closed or left.
  private func endDualPane() {
    secondaryPane = nil
    isDualPaneVisible = false
    isSecondaryPaneActive = false
  }

  private func remember(_ tab: TabModel, in pane: PaneModel) {
    let closed = ClosedTab(
      snapshot: tab.snapshot,
      title: tab.title,
      isFromSecondaryPane: pane === secondaryPane,
      index: pane.index(of: tab) ?? 0)
    closedTabs.insert(closed, at: 0)
    if closedTabs.count > Self.closedTabLimit {
      closedTabs.removeLast(closedTabs.count - Self.closedTabLimit)
    }
  }
}

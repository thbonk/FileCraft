/*
 * BrowserWindowModelTests.swift
 * FileCraftTests
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
import Testing
@testable import FileCraft

internal struct BrowserWindowModelTests {

  // MARK: - Dual Pane

  @Test
  internal func `Showing dual pane for the first time opens the active location`() throws {
    let window = BrowserWindowModel(location: .tag("Documents"))

    window.setDualPaneVisible(true)

    let secondaryPane = try #require(window.secondaryPane)
    #expect(window.isDualPaneVisible)
    #expect(secondaryPane.currentTab.location == .tag("Documents"))
  }

  @Test
  internal func `Hidden second pane keeps its tabs`() throws {
    let window = BrowserWindowModel(location: .tag("A"))
    window.setDualPaneVisible(true)
    let secondaryPane = try #require(window.secondaryPane)
    secondaryPane.addTab(TabModel(location: .tag("B")))
    secondaryPane.addTab(TabModel(location: .tag("C")))

    window.setDualPaneVisible(false)
    window.setDualPaneVisible(true)

    #expect(window.secondaryPane === secondaryPane)
    #expect(secondaryPane.tabs.map(\.location) == [.tag("A"), .tag("B"), .tag("C")])
  }

  @Test
  internal func `Active pane follows activation and hiding`() throws {
    let window = BrowserWindowModel(location: .tag("A"))
    window.setDualPaneVisible(true)
    let secondaryPane = try #require(window.secondaryPane)

    window.activate(secondaryPane)
    #expect(window.activePane === secondaryPane)

    window.setDualPaneVisible(false)
    #expect(window.activePane === window.primaryPane)
  }

  @Test
  internal func `Window title follows the active tab`() throws {
    let window = BrowserWindowModel(location: .tag("Left"))
    window.setDualPaneVisible(true)
    let secondaryPane = try #require(window.secondaryPane)
    secondaryPane.currentTab.navigate(to: .tag("Right"))

    window.activate(secondaryPane)

    #expect(window.title == "Right")
  }

  // MARK: - Snapshots

  @Test
  internal func `Snapshot survives encoding and restoration`() throws {
    let window = BrowserWindowModel(location: .tag("A"))
    window.primaryPane.currentTab.navigate(to: .tag("B"))
    window.primaryPane.addTab(TabModel(location: .tag("C")))
    window.setDualPaneVisible(true)
    window.layout.isInspectorVisible = true
    window.layout.paneSplitFraction = 0.3
    let data = try JSONEncoder().encode(window.snapshot)

    let restored = BrowserWindowModel(location: .tag("Fallback"))
    restored.restore(from: try JSONDecoder().decode(BrowserWindowSnapshot.self, from: data), fallback: .tag("Fallback"))

    #expect(restored.snapshot == window.snapshot)
    #expect(restored.primaryPane.tabs.count == 2)
    #expect(restored.primaryPane.currentTab.location == .tag("C"))
    #expect(restored.primaryPane.tabs.first?.history.canGoBack == true)
  }

  @Test
  internal func `Restoring an empty pane falls back to one tab`() {
    let snapshot = BrowserWindowSnapshot(
      primaryPane: PaneSnapshot(tabs: [], currentTabIndex: 5),
      secondaryPane: nil,
      isDualPaneVisible: true,
      isSecondaryPaneActive: true,
      layout: WindowLayout())
    let window = BrowserWindowModel(location: .tag("A"))

    window.restore(from: snapshot, fallback: .tag("Home"))

    #expect(window.primaryPane.tabs.map(\.location) == [.tag("Home")])
    #expect(window.isDualPaneVisible == false)
    #expect(window.activePane === window.primaryPane)
  }

  // MARK: - Tabs

  @Test
  internal func `Navigating a tab clears selection and filter`() {
    let tab = TabModel(location: .tag("A"))
    tab.selection = ["/x"]
    tab.filterText = "inv"

    tab.navigate(to: .tag("B"))

    #expect(tab.selection.isEmpty)
    #expect(tab.filterText.isEmpty)
    #expect(tab.title == "B")
  }

  // MARK: - Tabs

  @Test
  internal func `New tabs open at the current location or at home, as Settings say`() throws {
    let home = try TemporaryDirectory()
    let window = BrowserWindowModel(location: .tag("Documents"))

    window.newTab(location: .currentLocation, homeDirectory: home.url)
    let currentLocationTab = window.activeTab.location
    window.newTab(location: .home, homeDirectory: home.url)

    #expect(currentLocationTab == .tag("Documents"))
    #expect(window.activeTab.folderURL?.comparablePath == home.url.comparablePath)
    #expect(window.activePane.tabs.count == 3)
  }

  @Test
  internal func `Closing the only tab of the only pane closes the window`() {
    let window = BrowserWindowModel(location: .tag("A"))

    window.closeTab()

    #expect(window.closeRequest == 1)
    #expect(window.activePane.tabs.count == 1)
  }

  @Test
  internal func `Closing the last tab of the second pane turns dual pane off`() throws {
    let window = BrowserWindowModel(location: .tag("A"))
    window.setDualPaneVisible(true, defaultLayout: .sideBySide)
    window.activate(try #require(window.secondaryPane))

    window.closeTab()

    #expect(window.isDualPaneVisible == false)
    #expect(window.secondaryPane == nil)
    #expect(window.activeTab.location == .tag("A"))
    #expect(window.closeRequest == 0)
  }

  @Test
  internal func `Closing the last tab of the first pane hands the window to the second pane`() throws {
    let window = BrowserWindowModel(location: .tag("A"))
    window.setDualPaneVisible(true, defaultLayout: .sideBySide)
    let secondaryPane = try #require(window.secondaryPane)
    secondaryPane.addTab(TabModel(location: .tag("B")))

    window.closeTab(window.primaryPane.currentTab)

    #expect(window.primaryPane === secondaryPane)
    #expect(window.isDualPaneVisible == false)
    #expect(window.activeTab.location == .tag("B"))
  }

  @Test
  internal func `Close Other Tabs keeps only the chosen tab`() {
    let window = BrowserWindowModel(location: .tag("A"))
    window.show(.tag("B"), inNewTab: true)
    window.show(.tag("C"), inNewTab: true)
    let keptTab = window.activePane.tabs[1]

    window.closeOtherTabs(than: keptTab)

    #expect(window.activePane.tabs.map(\.title) == ["B"])
    #expect(window.closedTabs.map(\.title) == ["A", "C"])
  }

  @Test
  internal func `A closed tab reopens with its history in the pane it came from`() throws {
    let directory = try TemporaryDirectory()
    let invoices = try directory.createFolder("Invoices")
    let window = BrowserWindowModel(location: .tag("A"))
    window.show(.folder(try FileReference(url: directory.url)), inNewTab: true)
    window.activeTab.navigate(toFolder: invoices)
    let closedTabHistory = window.activeTab.history

    window.closeTab()
    let tabsAfterClose = window.activePane.tabs.count
    window.reopenClosedTab()

    #expect(tabsAfterClose == 1)
    #expect(window.activePane.tabs.count == 2)
    #expect(window.activeTab.history == closedTabHistory)
    #expect(window.activeTab.title == "Invoices")
    #expect(window.closedTabs.isEmpty)
  }

  @Test
  internal func `A window remembers its ten most recently closed tabs`() {
    let window = BrowserWindowModel(location: .tag("Start"))
    for index in 1...12 {
      window.show(.tag("Tab \(index)"), inNewTab: true)
      window.closeTab()
    }

    #expect(window.closedTabs.count == BrowserWindowModel.closedTabLimit)
    #expect(window.closedTabs.first?.title == "Tab 12")
    #expect(window.closedTabs.last?.title == "Tab 3")
  }

  @Test
  internal func `A dragged tab moves to the other pane with its history`() throws {
    let window = BrowserWindowModel(location: .tag("A"))
    window.show(.tag("B"), inNewTab: true)
    let movedTab = window.activeTab
    window.setDualPaneVisible(true, defaultLayout: .sideBySide)
    let secondaryPane = try #require(window.secondaryPane)

    window.moveTab(withID: movedTab.id, to: secondaryPane, before: nil)

    #expect(window.primaryPane.tabs.map(\.title) == ["A"])
    #expect(secondaryPane.tabs.last === movedTab)
    #expect(movedTab.pane === secondaryPane)
    #expect(window.activePane === secondaryPane)
  }

  @Test
  internal func `The first pane keeps its last tab, the second pane's last tab can leave`() throws {
    let window = BrowserWindowModel(location: .tag("A"))
    window.setDualPaneVisible(true, defaultLayout: .sideBySide)
    let secondaryPane = try #require(window.secondaryPane)
    let firstPaneTab = window.primaryPane.currentTab

    window.moveTab(withID: firstPaneTab.id, to: secondaryPane, before: nil)
    let firstPaneAfterRefusedMove = window.primaryPane.tabs.count
    window.moveTab(withID: secondaryPane.currentTab.id, to: window.primaryPane, before: nil)

    #expect(firstPaneAfterRefusedMove == 1)
    #expect(window.primaryPane.tabs.count == 2)
    #expect(window.isDualPaneVisible == false)
  }

  // MARK: - Panes

  @Test
  internal func `Swap Panes exchanges the contents and keeps the active contents active`() throws {
    let window = BrowserWindowModel(location: .tag("Left"))
    window.setDualPaneVisible(true, defaultLayout: .stacked)
    let secondaryPane = try #require(window.secondaryPane)
    secondaryPane.currentTab.navigate(to: .tag("Right"))
    let leftPane = window.primaryPane

    window.swapPanes()

    #expect(window.layout.paneLayout == .stacked)
    #expect(window.primaryPane === secondaryPane)
    #expect(window.secondaryPane === leftPane)
    #expect(window.activePane === leftPane)
    #expect(window.activeTab.location == .tag("Left"))
  }

  @Test
  internal func `Cross-pane commands use the other pane and Tab moves focus there`() throws {
    let window = BrowserWindowModel(location: .tag("Music"))
    window.layout.paneSplitFraction = 0.3
    let focusBefore = window.activeTab.focusRequest
    let focusedWithoutDualPane = window.focusOtherPane()
    window.setDualPaneVisible(true, defaultLayout: .sideBySide)
    let secondaryPane = try #require(window.secondaryPane)
    secondaryPane.currentTab.navigate(to: .tag("Other"))

    window.showSameFolderInOtherPane()
    window.equalizePaneSizes()
    let focusedWithDualPane = window.focusOtherPane()

    #expect(focusedWithoutDualPane == false)
    #expect(secondaryPane.currentTab.location == .tag("Music"))
    #expect(window.layout.paneSplitFraction == 0.5)
    #expect(focusedWithDualPane)
    #expect(window.activePane === secondaryPane)
    #expect(secondaryPane.currentTab.focusRequest == focusBefore + 1)
  }

  @Test
  internal func `Opening several folders shows the first in the tab and the others in new tabs`() async throws {
    let directory = try TemporaryDirectory()
    try ["A", "B", "C"].forEach { try directory.createFolder($0) }
    let items = try await FileSystemService().contentsOfDirectory(at: directory.url, includingHiddenItems: false)
      .sorted { $0.name < $1.name }
    let window = BrowserWindowModel(location: .folder(try FileReference(url: directory.url)))
    let tab = window.activeTab

    tab.open(items)

    #expect(window.activePane.tabs.map(\.title) == ["A", "B", "C"])
    #expect(window.activeTab === tab)
  }

  // MARK: - Get Info

  @Test
  internal func `Get Info asks for one window per selected item, or for the folder`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFile("a.txt")
    try directory.createFile("b.txt")
    let items = try await FileSystemService().contentsOfDirectory(at: directory.url, includingHiddenItems: false)
    let window = BrowserWindowModel(primaryPane: PaneModel(tab: TabModel(
      location: .folder(try FileReference(url: directory.url)),
      listing: DirectoryListing(staticItems: items))))

    window.requestInfoWindows()
    let folderRequest = window.infoWindowRequest.map(\.lastKnownURL.comparablePath)
    window.activeTab.selection = Set(items.map(\.id))
    window.requestInfoWindows()

    #expect(folderRequest == [directory.url.comparablePath])
    #expect(window.infoWindowRequest.map(\.lastKnownURL.lastPathComponent) == ["a.txt", "b.txt"])
  }

  // MARK: - Sidebar

  @Test
  internal func `Sidebar entries open in the active tab or in a new tab`() {
    let window = BrowserWindowModel(location: .tag("A"))

    window.show(.tag("B"), inNewTab: false)
    let tabsAfterClick = window.activePane.tabs.count
    window.show(.computer, inNewTab: true)

    #expect(tabsAfterClick == 1)
    #expect(window.activePane.tabs.count == 2)
    #expect(window.activePane.tabs.first?.location == .tag("B"))
    #expect(window.activeTab.location == .computer)
  }

  @Test
  internal func `Tabs on an unmounted volume go to the home folder, others stay`() throws {
    let volume = try TemporaryDirectory()
    let inside = try volume.createFolder("Photos")
    let home = try TemporaryDirectory()
    let elsewhere = try TemporaryDirectory()
    let window = BrowserWindowModel(location: .folder(try FileReference(url: inside)))
    window.show(.folder(try FileReference(url: elsewhere.url)), inNewTab: true)

    window.volumeDidUnmount(volume.url, homeDirectory: home.url)

    let tabFolders = window.activePane.tabs.map { $0.folderURL?.comparablePath }
    #expect(tabFolders == [home.url.comparablePath, elsewhere.url.comparablePath])
  }

  // MARK: - Open Requests

  @Test
  internal func `An open request for a folder opens it in a new tab`() async throws {
    let directory = try TemporaryDirectory()
    let photos = try directory.createFolder("Photos")
    let window = BrowserWindowModel(location: .folder(try FileReference(url: directory.url)))
    let wasUntouched = window.isUntouched

    window.showRequested(try await FileSystemService().item(at: photos), usesCurrentTab: false)

    #expect(wasUntouched)
    #expect(window.activePane.tabs.count == 2)
    #expect(window.activeTab.folderURL?.lastPathComponent == "Photos")
    #expect(window.isUntouched == false)
  }

  @Test
  internal func `An open request for a file reveals it in a new tab`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("Docs")
    let report = try directory.createFile("Docs/report.pdf")
    let window = BrowserWindowModel(location: .folder(try FileReference(url: directory.url)))

    window.showRequested(try await FileSystemService().item(at: report), usesCurrentTab: false)

    #expect(window.activePane.tabs.count == 2)
    #expect(window.activeTab.folderURL?.lastPathComponent == "Docs")
  }

  @Test
  internal func `A window created for an open request shows the folder in its only tab`() async throws {
    let directory = try TemporaryDirectory()
    let photos = try directory.createFolder("Photos")
    let window = BrowserWindowModel(location: .folder(try FileReference(url: directory.url)))

    window.showRequested(try await FileSystemService().item(at: photos), usesCurrentTab: true)

    #expect(window.activePane.tabs.count == 1)
    #expect(window.activeTab.folderURL?.lastPathComponent == "Photos")
  }

  @Test
  internal func `Quick filter ignores case and diacritics`() {
    let items = ["Über uns.pdf", "Bericht.pdf", "Uber.txt"].map { FileItem(url: URL(filePath: "/tmp/\($0)")) }
    let tab = TabModel(location: .tag("A"), listing: DirectoryListing(staticItems: items))

    tab.filterText = "uber"

    #expect(Set(tab.visibleItems.map(\.name)) == ["Über uns.pdf", "Uber.txt"])
  }
}

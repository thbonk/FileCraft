/*
 * TabModelTests.swift
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

internal struct TabModelTests {

  // MARK: - Outline Rows

  @Test
  internal func `Expanded folders show their sorted children indented`() {
    let docs = folder("/tmp/Docs/")
    let rows = OutlineRows.rows(
      for: [file("/tmp/b.txt"), docs, file("/tmp/a.txt")],
      children: [docs.id: [file("/tmp/Docs/z.txt"), file("/tmp/Docs/y.txt")]],
      expanded: [docs.id],
      sorting: ItemSorting(order: ItemSortOrder(), locale: Locale(identifier: "en_US")),
      isExpandable: { $0.isDirectory })

    #expect(rows.map(\.item.name) == ["Docs", "y.txt", "z.txt", "a.txt", "b.txt"])
    #expect(rows.map(\.depth) == [0, 1, 1, 0, 0])
    #expect(rows.first?.isExpanded == true)
  }

  @Test
  internal func `Collapsed folders hide their children`() {
    let docs = folder("/tmp/Docs/")
    let rows = OutlineRows.rows(
      for: [docs],
      children: [docs.id: [file("/tmp/Docs/z.txt")]],
      expanded: [],
      sorting: ItemSorting(order: ItemSortOrder()),
      isExpandable: { $0.isDirectory })

    #expect(rows.map(\.item.name) == ["Docs"])
    #expect(rows.first?.isExpandable == true)
  }

  // MARK: - Selection

  @Test
  internal func `Listing changes deselect items that are gone`() {
    let listing = DirectoryListing(staticItems: [file("/tmp/a"), file("/tmp/b")])
    let tab = TabModel(location: .tag("Test"), listing: listing)
    tab.selection = ["/tmp/a", "/tmp/gone"]

    tab.listingDidChange()

    #expect(tab.selection == ["/tmp/a"])
    #expect(tab.refreshGeneration == 1)
  }

  @Test
  internal func `Invert selection uses the visible rows`() {
    let tab = TabModel(location: .tag("Test"), listing: DirectoryListing(staticItems: [file("/tmp/a"), file("/tmp/b"), file("/tmp/c")]))
    tab.select("/tmp/b")

    tab.invertSelection()

    #expect(tab.selection == ["/tmp/a", "/tmp/c"])
  }

  // MARK: - Expansion and Renaming

  @Test
  internal func `Expanding a folder loads its children`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("Docs")
    try directory.createFile("Docs/inner.txt", contents: "x")
    let service = FileSystemService()
    let items = try await service.contentsOfDirectory(at: directory.url, includingHiddenItems: false)
    let tab = TabModel(location: .tag("Test"), listing: DirectoryListing(staticItems: items))
    let docs = try #require(items.first { $0.name == "Docs" })

    tab.setExpanded(true, for: docs, recursively: false)
    await tab.loadExpandedChildren()

    #expect(tab.outlineRows.map(\.item.name) == ["Docs", "inner.txt"])
  }

  @Test
  internal func `Renaming validates and renames on disk`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFile("draft.txt")
    try directory.createFile("taken.txt")
    let items = try await FileSystemService().contentsOfDirectory(at: directory.url, includingHiddenItems: false)
    let tab = TabModel(location: .tag("Test"), listing: DirectoryListing(staticItems: items))
    let draft = try #require(items.first { $0.name == "draft.txt" })
    tab.beginRename(draft)

    let taken = await tab.commitRename(of: draft, to: "Taken.txt")
    let renamed = await tab.commitRename(of: draft, to: "final.txt")

    #expect(taken == .invalid(.alreadyExists("Taken.txt")))
    #expect(renamed == .renamed)
    #expect(tab.renamingItemID == nil)
    #expect(FileManager.default.fileExists(atPath: directory.url.appending(path: "final.txt").path(percentEncoded: false)))
  }

  // MARK: - Column View

  @Test
  internal func `Selecting a single folder opens it in the next column`() {
    let docs = folder("/tmp/Docs/")
    let note = file("/tmp/note.txt")
    let tab = TabModel(location: .tag("Test"), listing: DirectoryListing(staticItems: [docs, note]))

    tab.selectInColumn(0, selection: [docs.id], items: [docs, note])
    let chainWithFolder = tab.columnChain.map(\.id)
    tab.selectInColumn(0, selection: [note.id], items: [docs, note])

    #expect(chainWithFolder == [docs.id])
    #expect(tab.columnChain.isEmpty)
    #expect(tab.selection == [note.id])
    #expect(tab.selectedItems == [note])
  }

  @Test
  internal func `Entering a column selects its first item and leaving it selects its folder`() {
    let docs = folder("/tmp/Docs/")
    let inner = [file("/tmp/Docs/a.txt"), file("/tmp/Docs/b.txt")]
    let tab = TabModel(location: .tag("Test"), listing: DirectoryListing(staticItems: [docs]))
    tab.viewSettings.viewMode = .columns
    tab.selectInColumn(0, selection: [docs.id], items: [docs])

    tab.requestFirstSelection(inColumn: 1)
    tab.applyPendingFirstSelection(inColumn: 1, items: [])
    let selectionWhileLoading = tab.selection
    tab.applyPendingFirstSelection(inColumn: 1, items: inner)
    let selectionAfterLoading = tab.selection
    tab.leaveColumn(1)

    #expect(selectionWhileLoading == [docs.id])
    #expect(selectionAfterLoading == [inner[0].id])
    #expect(tab.pendingFirstSelectionColumn == nil)
    #expect(tab.selection == [docs.id])
    #expect(tab.columnChain.map(\.id) == [docs.id])
    #expect(tab.columnSelections.keys.sorted() == [0])
  }

  @Test
  internal func `Switching to column view keeps the selection`() {
    let items = [file("/tmp/a.txt"), file("/tmp/b.txt"), file("/tmp/c.txt")]
    let tab = TabModel(location: .tag("Test"), listing: DirectoryListing(staticItems: items))
    tab.selection = [items[0].id, items[2].id]

    tab.viewSettings.viewMode = .columns
    tab.showSelectionInColumns()

    #expect(tab.selection == [items[0].id, items[2].id])
    #expect(tab.columnSelections[0] == [items[0].id, items[2].id])
    #expect(tab.selectedItems.map(\.id) == [items[0].id, items[2].id])
  }

  // MARK: - Navigation

  @Test
  internal func `Enclosing Folder shows the parent with the folder just left selected`() async throws {
    let directory = try TemporaryDirectory()
    let invoices = try directory.createFolder("Docs/Invoices")
    try directory.createFile("Docs/notes.txt")
    let docsItems = try await FileSystemService().contentsOfDirectory(
      at: directory.url.appending(path: "Docs"),
      includingHiddenItems: false)
    let tab = TabModel(location: .folder(try FileReference(url: invoices)), listing: DirectoryListing(staticItems: docsItems))

    tab.goToEnclosingFolder()

    #expect(tab.folderURL?.lastPathComponent == "Docs")
    #expect(tab.selectedItems.map(\.name) == ["Invoices"])
    #expect(tab.history.canGoBack)
  }

  @Test
  internal func `Enclosing Folder of a volume shows Computer with the volume selected`() async throws {
    let rootURL = URL(filePath: "/", directoryHint: .isDirectory)
    let root = try await FileSystemService().item(at: rootURL)
    let tab = TabModel(location: .folder(try FileReference(url: rootURL)), listing: DirectoryListing(staticItems: [root]))

    tab.goToEnclosingFolder()

    #expect(tab.location == .computer)
    #expect(tab.selection == [root.id])
    #expect(tab.canGoToEnclosingFolder == false)
  }

  @Test
  internal func `History menus jump directly to an entry`() throws {
    let directory = try TemporaryDirectory()
    let folders = try ["A", "B", "C"].map { try directory.createFolder($0) }
    let tab = TabModel(location: .folder(try FileReference(url: directory.url)), listing: DirectoryListing(staticItems: []))
    folders.forEach(tab.navigate(toFolder:))

    tab.goBack(toMenuIndex: 1)

    #expect(tab.folderURL?.lastPathComponent == "A")
    #expect(tab.title == "A")
    #expect(tab.history.forwardMenu.map(\.location.displayName) == ["B", "C"])
  }

  @Test
  internal func `Visited folders become recent folders, most recent first`() async throws {
    let directory = try TemporaryDirectory()
    let folderA = try directory.createFolder("A")
    let folderB = try directory.createFolder("B")
    let recents = RecentsStore(storage: JSONFileStorage(fileURL: directory.url.appending(path: "Recents.json")))
    await recents.loadIfNeeded()
    let tab = TabModel(
      location: .folder(try FileReference(url: directory.url)),
      listing: DirectoryListing(staticItems: []),
      recents: recents)

    tab.navigate(toFolder: folderA)
    tab.navigate(toFolder: folderB)
    tab.navigate(toFolder: folderA)
    await recents.waitForPendingWrites()

    #expect(recents.folders.map(\.lastKnownURL.lastPathComponent) == ["A", "B"])
  }

  @Test
  internal func `Opening several folders shows the first one in the tab`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("A")
    try directory.createFolder("B")
    let items = try await FileSystemService().contentsOfDirectory(at: directory.url, includingHiddenItems: false)
    let tab = TabModel(location: .folder(try FileReference(url: directory.url)), listing: DirectoryListing(staticItems: items))
    tab.selection = Set(items.map(\.id))

    tab.openSelection()

    #expect(tab.folderURL?.lastPathComponent == "A")
  }

  // MARK: - Paths and Other Applications

  @Test
  internal func `Path commands use the selection, or the tab's folder without one`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("Sub")
    try directory.createFile("a.txt")
    let items = try await FileSystemService().contentsOfDirectory(at: directory.url, includingHiddenItems: false)
    let tab = TabModel(location: .folder(try FileReference(url: directory.url)), listing: DirectoryListing(staticItems: items))
    let folderName = directory.url.lastPathComponent

    let unselectedTargets = tab.pathTargets.map(\.lastPathComponent)
    let unselectedTerminalFolders = tab.terminalFolders.map(\.lastPathComponent)
    tab.selection = Set(items.map(\.id))

    #expect(unselectedTargets == [folderName])
    #expect(unselectedTerminalFolders == [folderName])
    #expect(tab.pathTargets.map(\.lastPathComponent) == ["Sub", "a.txt"])
    #expect(tab.terminalFolders.map(\.lastPathComponent) == ["Sub", folderName])
  }

  @Test
  internal func `Show Original reveals the target of a link in its folder`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("bin")
    let target = try directory.createFile("bin/tool")
    let linkURL = directory.url.appending(path: "tool link")
    try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: target)
    let items = try await FileSystemService().contentsOfDirectory(at: directory.url, includingHiddenItems: false)
    let link = try #require(items.first { $0.isSymbolicLink })
    let tab = TabModel(location: .folder(try FileReference(url: directory.url)), listing: DirectoryListing(staticItems: items))
    tab.select(link.id)

    let selectedLink = tab.selectedLink
    await tab.showOriginal(of: link)

    #expect(selectedLink == link)
    #expect(tab.folderURL?.lastPathComponent == "bin")
    #expect(tab.brokenAlias == nil)
  }

  @Test
  internal func `Show Original of a broken link asks about deleting it`() async throws {
    let directory = try TemporaryDirectory()
    let linkURL = directory.url.appending(path: "dangling")
    try FileManager.default.createSymbolicLink(atPath: linkURL.path(percentEncoded: false), withDestinationPath: "missing")
    let link = try await FileSystemService().item(at: linkURL)
    let tab = TabModel(location: .folder(try FileReference(url: directory.url)), listing: DirectoryListing(staticItems: [link]))

    await tab.showOriginal(of: link)

    #expect(tab.brokenAlias == link)
    #expect(tab.folderURL?.lastPathComponent == directory.url.lastPathComponent)
  }

  // MARK: - Quick Look

  @Test
  internal func `Quick Look follows the selection and selects the item it moves to`() {
    let items = [file("/tmp/a.txt"), file("/tmp/b.txt"), file("/tmp/c.txt")]
    let tab = TabModel(location: .tag("Test"), listing: DirectoryListing(staticItems: items))
    tab.select(items[0].id)

    tab.toggleQuickLook()
    let openedURL = tab.quickLookURL
    tab.select(items[1].id)
    tab.selectionDidChange()
    let followedURL = tab.quickLookURL
    tab.quickLookDidMove(to: items[2].url)
    let movedSelection = tab.selection
    tab.toggleQuickLook()

    #expect(openedURL == items[0].url)
    #expect(followedURL == items[1].url)
    #expect(movedSelection == [items[2].id])
    #expect(tab.quickLookURL == nil)
  }

  @Test
  internal func `Quick Look browses every item for one selected item and only the selection for several`() {
    let items = [file("/tmp/a.txt"), file("/tmp/b.txt"), file("/tmp/c.txt")]
    let tab = TabModel(location: .tag("Test"), listing: DirectoryListing(staticItems: items))

    tab.select(items[1].id)
    let singleSelectionURLs = tab.quickLookURLs
    tab.selection = [items[0].id, items[2].id]

    #expect(singleSelectionURLs == items.map(\.url))
    #expect(tab.quickLookURLs == [items[0].url, items[2].url])
  }

  // MARK: - Helpers

  private func file(_ path: String) -> FileItem {
    FileItem(url: URL(filePath: path), size: 1)
  }

  private func folder(_ path: String) -> FileItem {
    FileItem(url: URL(filePath: path, directoryHint: .isDirectory), isDirectory: true)
  }
}

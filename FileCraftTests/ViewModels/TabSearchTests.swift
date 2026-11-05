/*
 * TabSearchTests.swift
 * FileCraftTests
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

import Foundation
import Testing
@testable import FileCraft

internal struct TabSearchTests {

  // MARK: - Quick Filter

  @Test
  internal func `The quick filter shows matching items and the status counts them`() {
    var items = (0..<117).map { file("/tmp/Folder/note \($0).txt") }
    items += [file("/tmp/Folder/Invoice 1.pdf"), file("/tmp/Folder/invoice 2.pdf"), file("/tmp/Folder/INVENTORY.xlsx")]
    let tab = TabModel(location: .tag("Test"), listing: DirectoryListing(staticItems: items))

    tab.setSearchText("inv")

    #expect(tab.visibleItems.count == 3)
    #expect(tab.listing.items.count == 120)
  }

  @Test
  internal func `The quick filter ignores diacritics`() {
    let tab = TabModel(
      location: .tag("Test"), listing: DirectoryListing(staticItems: [file("/tmp/Über uns.pdf"), file("/tmp/Kontakt.pdf")]))

    tab.setSearchText("uber")

    #expect(tab.visibleItems.map(\.name) == ["Über uns.pdf"])
  }

  // MARK: - Select by Pattern

  @Test
  internal func `Select by Pattern replaces the selection or adds to it`() throws {
    let tab = TabModel(
      location: .tag("Test"),
      listing: DirectoryListing(staticItems: [file("/tmp/a.jpg"), file("/tmp/B.JPG"), file("/tmp/c.png"), file("/tmp/d.txt")]))
    tab.selection = ["/tmp/d.txt"]

    let replaced = tab.select(matching: try NamePattern("*.jpg", syntax: .wildcard), addingToSelection: false)
    #expect(replaced == 2)
    #expect(tab.selection == ["/tmp/a.jpg", "/tmp/B.JPG"])

    tab.select(matching: try NamePattern("\\.png$", syntax: .regularExpression), addingToSelection: true)
    #expect(tab.selection == ["/tmp/a.jpg", "/tmp/B.JPG", "/tmp/c.png"])
  }

  // MARK: - Search Locations

  @Test
  internal func `A search shows its results as a location that Back leaves`() {
    let tab = TabModel(location: .tag("Red"), listing: DirectoryListing(staticItems: []))

    tab.setSearchScope(.thisMac)
    tab.setSearchText("README")
    tab.runSearch()

    #expect(tab.location.searchQuery?.parameters.text == "README")
    #expect(tab.location.searchQuery?.parameters.scope == .thisMac)
    #expect(tab.history.canGoBack)

    tab.goBack()

    #expect(tab.location == .tag("Red"))
    #expect(tab.searchParameters.scope == .thisFolder)
  }

  @Test
  internal func `Typing on replaces the search instead of adding history`() {
    let tab = TabModel(location: .tag("Red"), listing: DirectoryListing(staticItems: []))
    tab.setSearchScope(.thisMac)
    tab.setSearchText("READ")
    tab.runSearch()

    tab.setSearchText("README")
    tab.runSearch()

    #expect(tab.location.searchQuery?.parameters.text == "README")
    #expect(tab.history.backStack == [.tag("Red")])
  }

  @Test
  internal func `Clearing the field ends the search`() {
    let tab = TabModel(location: .tag("Red"), listing: DirectoryListing(staticItems: []))
    tab.setSearchScope(.thisMac)
    tab.setSearchText("README")
    tab.runSearch()

    tab.setSearchText("")

    #expect(tab.location == .tag("Red"))
  }

  @Test
  internal func `Subfolders searches start in the tab's folder`() {
    let origin = FileReference(unresolvedURL: URL(filePath: "/tmp/Projects", directoryHint: .isDirectory))
    let tab = TabModel(location: .folder(origin), listing: DirectoryListing(staticItems: []))

    tab.setSearchScope(.subfolders)
    tab.setSearchText("README")
    tab.runSearch()

    #expect(tab.location.searchQuery?.origin == origin)
    #expect(tab.canSearchSubfolders)
  }

  @Test
  internal func `Subfolders is unavailable without a folder`() {
    let tab = TabModel(location: .tag("Red"), listing: DirectoryListing(staticItems: []))

    tab.setSearchScope(.subfolders)

    #expect(tab.canSearchSubfolders == false)
    #expect(tab.searchParameters.scope == .thisFolder)
  }

  @Test
  internal func `Leaving a search records it as a recent search`() async throws {
    let directory = try TemporaryDirectory()
    let recents = RecentsStore(storage: JSONFileStorage(fileURL: directory.url.appending(path: "Recents.json")))
    await recents.loadIfNeeded()
    let tab = TabModel(location: .tag("Red"), listing: DirectoryListing(staticItems: []), recents: recents)
    tab.setSearchScope(.thisMac)
    tab.setSearchText("README")
    tab.runSearch()

    tab.goBack()

    #expect(recents.searches.map(\.text) == ["README"])
    #expect(recents.searches.first?.scope == .thisMac)
  }

  @Test
  internal func `A recent search runs again with its scope and criteria`() {
    let tab = TabModel(location: .tag("Red"), listing: DirectoryListing(staticItems: []))
    let recent = SearchParameters(scope: .thisMac, text: "Invoice", criteria: [SearchCriterion(attribute: .kind, kind: .pdf)])

    tab.repeatSearch(recent)

    #expect(tab.location.searchQuery?.parameters.rule == recent.rule)
  }

  // MARK: - Helpers

  private func file(_ path: String) -> FileItem {
    FileItem(url: URL(filePath: path), size: 1)
  }
}

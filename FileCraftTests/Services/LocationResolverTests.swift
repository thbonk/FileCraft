/*
 * LocationResolverTests.swift
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

internal struct LocationResolverTests {

  // MARK: - Properties

  private let directory: TemporaryDirectory

  // MARK: - Initialization

  internal init() throws {
    directory = try TemporaryDirectory()
  }

  // MARK: - Tests

  @Test
  internal func `Existing folder resolves to itself`() throws {
    let folder = try directory.createFolder("Projects")

    let resolved = LocationResolver.nearestExistingFolder(to: try FileReference(url: folder))

    #expect(resolved.lastPathComponent == "Projects")
  }

  @Test
  internal func `Deleted folder resolves to its nearest existing ancestor`() throws {
    let deep = try directory.createFolder("A/B/C")
    let reference = try FileReference(url: deep)
    try FileManager.default.removeItem(at: directory.url.appending(path: "A/B"))

    let resolved = LocationResolver.nearestExistingFolder(to: reference)

    #expect(resolved.standardizedFileURL.path(percentEncoded: false).hasSuffix("/A/"))
  }

  @Test
  internal func `Restored snapshot replaces a deleted folder`() async throws {
    let parent = try directory.createFolder("Parent")
    let child = try directory.createFolder("Parent/Child")
    var history = NavigationHistory(current: .tag("Earlier"))
    history.navigate(to: .folder(try FileReference(url: child)))
    let snapshot = BrowserWindowSnapshot(
      primaryPane: PaneSnapshot(tabs: [TabSnapshot(history: history, viewSettings: ViewSettings())], currentTabIndex: 0),
      secondaryPane: nil,
      isDualPaneVisible: false,
      isSecondaryPaneActive: false,
      layout: WindowLayout())
    try FileManager.default.removeItem(at: child)

    let resolved = await LocationResolver.resolved(snapshot)

    let tab = try #require(resolved.primaryPane.tabs.first)
    #expect(tab.history.current.folderURL?.lastPathComponent == parent.lastPathComponent)
    #expect(tab.history.backMenuEntries == [.tag("Earlier")])
  }

  @Test
  internal func `New windows fall back to home when the chosen folder is missing`() throws {
    let chosen = try directory.createFolder("Chosen")
    let home = FileManager.default.homeDirectoryForCurrentUser

    let existing = LocationResolver.newWindowFolder(for: .chosenFolder, chosenPath: chosen.path(percentEncoded: false), lastPath: "")
    let missing = LocationResolver.newWindowFolder(for: .chosenFolder, chosenPath: "/no/such/folder", lastPath: "")

    #expect(existing.lastPathComponent == "Chosen")
    #expect(missing.standardizedFileURL == home.standardizedFileURL)
  }
}

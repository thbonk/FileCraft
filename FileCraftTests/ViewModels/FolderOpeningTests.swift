/*
 * FolderOpeningTests.swift
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

internal struct FolderOpeningTests {

  @Test
  internal func `Folders open in the same tab by default setting`() throws {
    let directory = try TemporaryDirectory()
    let (window, tab, folder) = try fixture(.sameTab, in: directory)
    // Navigating records the last folder in the user's settings; the test puts the previous value back.
    let lastFolder = UserDefaults.standard.object(forKey: SettingsKeys.lastFolderPath.name)
    defer {
      UserDefaults.standard.set(lastFolder, forKey: SettingsKeys.lastFolderPath.name)
    }

    tab.open(folder)

    #expect(tab.folderURL?.lastPathComponent == "Docs")
    #expect(window.primaryPane.tabs.count == 1)
  }

  @Test
  internal func `Folders can open in a new tab`() throws {
    let directory = try TemporaryDirectory()
    let (window, tab, folder) = try fixture(.newTab, in: directory)

    tab.open(folder)

    #expect(window.primaryPane.tabs.count == 2)
    #expect(window.activeTab.folderURL?.lastPathComponent == "Docs")
    #expect(tab.folderURL?.lastPathComponent == "Start")
  }

  @Test
  internal func `Folders can open in a new window`() throws {
    let directory = try TemporaryDirectory()
    let (window, tab, folder) = try fixture(.newWindow, in: directory)

    tab.open(folder)

    #expect(window.newWindowRequest == 1)
    #expect(NewWindowQueue.pop()?.folderURL?.lastPathComponent == "Docs")
    #expect(tab.folderURL?.lastPathComponent == "Start")
  }

  @Test
  internal func `Terminal applications include Terminal and skip apps that are not installed`() {
    let terminals = TerminalApplications.installed(including: "invalid.example.not-installed")

    #expect(terminals.first?.bundleIdentifier == "com.apple.Terminal")
    #expect(terminals.contains { $0.bundleIdentifier == "invalid.example.not-installed" } == false)
  }

  // MARK: - Helpers

  /// A tab showing the folder "Start" of `directory` and the folder item "Docs" to open.
  private func fixture(
    _ behavior: FolderOpeningBehavior,
    in directory: TemporaryDirectory
  ) throws -> (BrowserWindowModel, TabModel, FileItem) {
    let start = try FileReference(url: try directory.createFolder("Start"))
    let docs = try directory.createFolder("Docs")
    let tab = TabModel(location: .folder(start), listing: DirectoryListing(staticItems: []))
    tab.folderOpeningBehavior = { behavior }
    let window = BrowserWindowModel(primaryPane: PaneModel(tab: tab), fileCommands: FileCommandModel())
    let folder = FileItem(url: docs, isDirectory: true)
    return (window, tab, folder)
  }
}

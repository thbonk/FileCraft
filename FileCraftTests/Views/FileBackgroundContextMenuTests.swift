/*
 * FileBackgroundContextMenuTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-11-11.
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

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import FileCraft

internal struct FileBackgroundContextMenuTests {

  // MARK: - Tests

  /// File commands act on the active pane, so the menu of the other pane's empty area activates that pane first.
  @Test
  internal func `New Folder from the other pane's background menu creates the folder in that pane`() async throws {
    let first = try TemporaryDirectory()
    let second = try TemporaryDirectory()
    let window = BrowserWindowModel(location: .folder(try FileReference(url: first.url)))
    window.setDualPaneVisible(true)
    let secondaryPane = try #require(window.secondaryPane)
    secondaryPane.currentTab.replaceLocation(with: .folder(try FileReference(url: second.url)))
    window.activate(window.primaryPane)
    let menu = NSHostingMenu(
      rootView: FileBackgroundContextMenu(tab: secondaryPane.currentTab, folder: nil)
        .environment(\.locale, Locale(identifier: "en")))
    menu.update()
    let newFolder = try #require(menu.items.firstIndex { $0.title == "New Folder" })

    menu.performActionForItem(at: newFolder)
    for _ in 0..<100 where try Self.contents(of: second).isEmpty {
      try await Task.sleep(for: .milliseconds(20))
    }

    #expect(window.activePane === secondaryPane)
    #expect(try Self.contents(of: second).count == 1)
    #expect(try Self.contents(of: first).isEmpty)
  }

  // MARK: - Helpers

  private static func contents(of directory: TemporaryDirectory) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: directory.url.path(percentEncoded: false))
  }
}

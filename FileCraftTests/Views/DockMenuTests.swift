/*
 * DockMenuTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-11-06.
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
import Testing
@testable import FileCraft

internal struct DockMenuTests {

  @Test
  internal func `The Dock menu offers New Window and the five most recent folders`() throws {
    let delegate = AppDelegate()
    let folders = (1...7).map { FileReference(unresolvedURL: URL(filePath: "/tmp/Folder \($0)", directoryHint: .isDirectory)) }
    delegate.recentFolders = { folders }

    let menu = try #require(delegate.applicationDockMenu(NSApp))
    let titles = menu.items.filter { $0.isSeparatorItem == false }.map(\.title)

    #expect(titles.first == String(localized: "New Window"))
    #expect(titles.dropFirst() == ["Folder 1", "Folder 2", "Folder 3", "Folder 4", "Folder 5"])
  }

  @Test
  internal func `Without recent folders the Dock menu offers New Window only`() throws {
    let delegate = AppDelegate()
    delegate.recentFolders = { [] }

    let menu = try #require(delegate.applicationDockMenu(NSApp))

    #expect(menu.items.map(\.title) == [String(localized: "New Window")])
  }
}

/*
 * ShortcutCatalogTests.swift
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

import Foundation
import Testing
@testable import FileCraft

internal struct ShortcutCatalogTests {

  @Test
  internal func `Searching for Trash finds the three trash commands`() {
    let titles = ShortcutCatalog.sections(matching: String(localized: "Trash")).flatMap(\.entries).map { String(localized: $0.title) }

    #expect(titles == ["Move to Trash", "Delete Immediately…", "Empty Trash…"].map { String(localized: String.LocalizationValue($0)) })
  }

  @Test
  internal func `Sections follow the menu order and an empty search lists everything`() {
    let sections = ShortcutCatalog.sections(matching: "")

    #expect(sections.map(\.menu) == MenuName.allCases)
    #expect(sections.flatMap(\.entries).count == ShortcutCatalog.entries.count)
  }

  @Test
  internal func `Shortcuts are written with the menu symbols`() {
    #expect(Shortcut("n", [.shift, .command]).symbols == "⇧⌘N")
    #expect(Shortcut(Shortcut.delete, [.option, .command]).symbols == "⌥⌘⌫")
    #expect(Shortcut(Shortcut.tab, [.control, .shift]).symbols == "⌃⇧⇥")
    #expect(Shortcut(Shortcut.f5, []).symbols == "F5")
  }
}

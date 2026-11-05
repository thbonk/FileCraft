/*
 * MainMenuTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-10-31.
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

/// Checks the menu bar of the host app, which SwiftUI builds from the app's scenes and commands.
internal struct MainMenuTests {

  // MARK: - Tests

  /// Titles are compared with the app's own strings, because the host app runs in the system language.
  @Test
  internal func `Quick Look and Show View Options have the shortcuts from the spec`() throws {
    let items = Self.items(in: try #require(NSApp.mainMenu))
    let shortcuts = items.filter { $0.keyEquivalent.isEmpty == false }.map { "\($0.title) \($0.keyEquivalent)" }

    let quickLook = items.first { $0.keyEquivalent == "y" && $0.keyEquivalentModifierMask == .command }
    let viewOptions = items.first { $0.keyEquivalent == "j" && $0.keyEquivalentModifierMask == .command }

    #expect(quickLook?.title == String(localized: "Quick Look"), "Shortcuts: \(shortcuts)")
    #expect(viewOptions?.title == String(localized: "Show View Options"), "Shortcuts: \(shortcuts)")
  }

  @Test
  internal func `The Go menu has history, Recent Folders and the standard locations`() throws {
    let items = Self.items(in: try #require(NSApp.mainMenu))
    func title(of key: String, _ modifiers: NSEvent.ModifierFlags) -> String? {
      items.first { Self.shortcut(of: $0) == Shortcut(key: key, modifiers: modifiers) }?.title
    }
    let library = items.first { $0.title == String(localized: "Library") }

    #expect(title(of: "h", [.shift, .command]) == String(localized: "Home"))
    #expect(title(of: "c", [.shift, .command]) == String(localized: "Computer"))
    #expect(title(of: "l", [.option, .command]) == String(localized: "Downloads"))
    #expect(title(of: "u", [.shift, .command]) == String(localized: "Utilities"))
    #expect(title(of: "o", .command) == String(localized: "Open"))
    #expect(items.contains { $0.title == String(localized: "Back") && $0.keyEquivalent.isEmpty == false })
    #expect(items.contains { $0.title == String(localized: "Enclosing Folder") && $0.keyEquivalent.isEmpty == false })
    #expect(items.first { $0.title == String(localized: "Recent Folders") }?.hasSubmenu == true)
    #expect(library?.isAlternate == true)
  }

  @Test
  internal func `Path, original and Tools commands are in the menus with their shortcuts`() throws {
    let mainMenu = try #require(NSApp.mainMenu)
    let items = Self.items(in: mainMenu)
    func title(of key: String, _ modifiers: NSEvent.ModifierFlags) -> String? {
      items.first { Self.shortcut(of: $0) == Shortcut(key: key, modifiers: modifiers) }?.title
    }
    let tools = mainMenu.items.first { $0.title == String(localized: "Tools") }?.submenu
    let toolTitles = tools?.items.map(\.title) ?? []

    #expect(title(of: "g", [.shift, .command]) == String(localized: "Go to Folder…"))
    #expect(title(of: "c", [.option, .command]) == String(localized: "Copy Path"))
    #expect(title(of: "r", .command) == String(localized: "Show Original"))
    #expect(items.first { $0.title == String(localized: "Copy Path As") }?.submenu?.items.count == PathFormat.allCases.count)
    #expect(items.contains { $0.title == String(localized: "Edit Path") })
    #expect(items.first { $0.title == String(localized: "Open With") }?.hasSubmenu == true)
    #expect(toolTitles.contains(String(localized: "Open in Terminal")))
    #expect(toolTitles.contains(String(localized: "Reveal in Finder")))
    #expect(title(of: "t", [.control, .command]) == String(localized: "Add to Sidebar"))
    #expect(title(of: "i", .command) == String(localized: "Get Info"))
  }

  @Test
  internal func `Tab commands replace the standard Close items`() throws {
    let items = Self.items(in: try #require(NSApp.mainMenu))
    func title(of key: String, _ modifiers: NSEvent.ModifierFlags) -> String? {
      items.first { Self.shortcut(of: $0) == Shortcut(key: key, modifiers: modifiers) }?.title
    }
    let closeItems = items.filter { Self.shortcut(of: $0) == Shortcut(key: "w", modifiers: .command) }

    #expect(title(of: "t", .command) == String(localized: "New Tab"))
    #expect(title(of: "t", [.shift, .command]) == String(localized: "Reopen Closed Tab"))
    #expect(title(of: "w", [.shift, .command]) == String(localized: "Close Window"))
    #expect(closeItems.map(\.title) == [String(localized: "Close Tab")])
    #expect(items.contains { $0.title == String(localized: "Show Next Tab") && $0.keyEquivalent.isEmpty == false })
    #expect(items.first { $0.title == String(localized: "Recently Closed Tabs") }?.hasSubmenu == true)
    #expect(items.contains { $0.title == String(localized: "Swap Panes") })
    #expect(items.contains { $0.title == String(localized: "Show Same Folder in Other Pane") })
  }

  @Test
  internal func `File commands and Empty Trash have the shortcuts from the spec`() throws {
    let items = Self.items(in: try #require(NSApp.mainMenu))
    func title(of key: String, _ modifiers: NSEvent.ModifierFlags) -> String? {
      items.first { Self.shortcut(of: $0) == Shortcut(key: key, modifiers: modifiers) }?.title
    }
    let delete = "\u{8}"

    #expect(title(of: "n", [.shift, .command]) == String(localized: "New Folder"))
    #expect(title(of: "n", [.control, .command]) == String(localized: "New Folder with Selection"))
    #expect(title(of: "n", [.option, .command]) == String(localized: "New Text File"))
    #expect(title(of: "d", .command) == String(localized: "Duplicate"))
    #expect(title(of: "a", [.control, .command]) == String(localized: "Make Alias"))
    #expect(title(of: delete, .command) == String(localized: "Move to Trash"))
    #expect(title(of: delete, [.option, .command]) == String(localized: "Delete Immediately…"))
    #expect(title(of: delete, [.shift, .command]) == String(localized: "Empty Trash…"))
    #expect(title(of: "e", .command) == String(localized: "Eject"))
    #expect(items.contains { $0.title == String(localized: "Rename") })
    #expect(items.contains { $0.title == String(localized: "Make Symbolic Link") })
    #expect(items.contains { $0.title == String(localized: "Put Back") })
    #expect(title(of: "v", [.option, .command]) == String(localized: "Move Items Here"))
    #expect(items.contains { $0.title == String(localized: "Copy To…") })
    #expect(items.contains { $0.title == String(localized: "Move To…") })
    #expect(items.contains { $0.title == String(localized: "Copy to Other Pane") })
    #expect(items.contains { $0.title == String(localized: "Move to Other Pane") })
    #expect(items.contains { $0.title == String(localized: "Compress") })
    #expect(items.first { $0.title == String(localized: "Compress With Format") }?.submenu?.items.map(\.title) == ["ZIP", "tar.gz", "tar.bz2", "tar.xz"])
    #expect(items.contains { $0.title == String(localized: "Expand") })
  }

  @Test
  internal func `The Window menu lists Operations once, after the tab commands`() throws {
    let windowMenu = try #require(NSApp.windowsMenu)
    let titles = windowMenu.items.map(\.title)
    let operations = String(localized: "Operations")
    let operationsIndex = try #require(titles.firstIndex(of: operations))
    let recentlyClosedIndex = try #require(titles.firstIndex(of: String(localized: "Recently Closed Tabs")))

    let nextIndex = try #require(titles.firstIndex(of: String(localized: "Show Next Tab")))
    let previousIndex = try #require(titles.firstIndex(of: String(localized: "Show Previous Tab")))

    #expect(nextIndex < previousIndex)
    #expect(recentlyClosedIndex < operationsIndex)
    #expect(Self.items(in: try #require(NSApp.mainMenu)).filter { $0.title == operations }.count == 1)
  }

  // MARK: - Helpers

  private struct Shortcut: Equatable {
    let key: String
    let modifiers: NSEvent.ModifierFlags
  }

  /// The shortcut of `item` with ⇧ made explicit, because an uppercase key equivalent implies it.
  private static func shortcut(of item: NSMenuItem) -> Shortcut {
    var modifiers = item.keyEquivalentModifierMask.intersection([.shift, .control, .option, .command])
    if item.keyEquivalent != item.keyEquivalent.lowercased() {
      modifiers.insert(.shift)
    }
    return Shortcut(key: item.keyEquivalent.lowercased(), modifiers: modifiers)
  }

  private static func items(in menu: NSMenu) -> [NSMenuItem] {
    menu.items.flatMap { item in
      [item] + (item.submenu.map(items(in:)) ?? [])
    }
  }
}

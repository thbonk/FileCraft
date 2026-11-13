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
  internal func `Check for Updates follows About in the application menu`() throws {
    let applicationMenu = try #require(NSApp.mainMenu?.items.first?.submenu)
    let items = applicationMenu.items
    let titles = items.map(\.title)

    #expect(items.count > 1, "\(titles)")
    #expect(items.first?.action.map(NSStringFromSelector)?.contains("About") == true, "\(titles)")
    #expect(items.count > 1 && items[1].title == String(localized: "Check for Updates…"), "\(titles)")
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
    // Without a browser window in front, as in the test host, the ⌘W item closes the key window.
    #expect(closeItems.count == 1)
    #expect([String(localized: "Close Tab"), String(localized: "Close")].contains(closeItems.first?.title ?? ""))
    #expect(items.contains { $0.title == String(localized: "Show Next Tab") && $0.keyEquivalent.isEmpty == false })
    #expect(items.first { $0.title == String(localized: "Recently Closed Tabs") }?.hasSubmenu == true)
    #expect(items.contains { $0.title == String(localized: "Swap Panes") })
    #expect(items.contains { $0.title == String(localized: "Show Same Folder in Other Pane") })
  }

  @Test
  internal func `Empty Trash is in the File menu, after Put Back`() throws {
    let menu = try #require(NSApp.mainMenu)
    let appMenu = try #require(menu.items.first?.submenu)
    // The File menu is the one with Move to Trash.
    let fileMenu = try #require(
      menu.items.compactMap(\.submenu).first { $0.items.contains { $0.title == String(localized: "Move to Trash") } })
    let titles = fileMenu.items.map(\.title)
    let emptyTrash = try #require(titles.firstIndex(of: String(localized: "Empty Trash…")))
    let putBack = try #require(titles.firstIndex(of: String(localized: "Put Back")))

    #expect(emptyTrash == putBack + 1)
    #expect(appMenu.items.contains { $0.title == String(localized: "Empty Trash…") } == false)
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

  // MARK: - Shortcut Catalog

  @Test
  internal func `Every menu shortcut of the catalog belongs to its command`() throws {
    let items = Self.items(in: try #require(NSApp.mainMenu))
    var problems: [String] = []
    for entry in ShortcutCatalog.entries {
      guard let first = entry.shortcuts.first, Self.isCheckable(first) else {
        continue
      }
      // Go > iCloud Drive is in the menu only while iCloud Drive is turned on, which it is not on CI machines.
      if entry.title.key == "iCloud Drive", StandardLocation.isICloudDriveAvailable() == false {
        continue
      }
      let expected = Self.menuShortcut(first)
      let matches = items.filter { Self.shortcut(of: $0) == expected }
      if entry.isSystem {
        if matches.isEmpty {
          problems.append("no menu item for \(String(localized: entry.title)) \(first.symbols)")
        }
        continue
      }
      let titles = [entry.title, entry.alternateTitle].compactMap { $0 }.map { String(localized: $0) }
      if matches.contains(where: { titles.contains($0.title) }) {
        continue
      }
      // Keys such as [ ] and / move with the keyboard layout; macOS then stores an adapted key equivalent, for
      // example ö for [ on a German keyboard. The command's item must still have a shortcut.
      let adapted = items.first { titles.contains($0.title) && $0.keyEquivalent.isEmpty == false }
      if adapted == nil || Self.layoutDependentKeys.contains(first.key) == false {
        problems.append("\(first.symbols): expected \(titles), found \(matches.map(\.title))")
      }
    }
    #expect(problems.isEmpty, "\(problems)")
  }

  @Test
  internal func `No default shortcut collides with a macOS shortcut or another command`() {
    let shortcuts = ShortcutCatalog.entries.flatMap(\.shortcuts)

    #expect(Set(shortcuts).isDisjoint(with: ShortcutCatalog.systemShortcuts))
    #expect(Set(shortcuts).count == shortcuts.count)
  }

  @Test
  internal func `Shortcuts adapt to the keyboard layout`() {
    // macOS shows ⌘[ and ⌘] as keys that can be typed on the active layout, for example ⌘Ö and ⌘Ä in German.
    #expect(NSApp.mainMenu?.items.allSatisfy { $0.allowsAutomaticKeyEquivalentLocalization } == true)
  }

  // MARK: - Structure

  @Test
  internal func `The View menu lists the view commands before the toolbar commands`() throws {
    let view = try #require(Self.menu(containing: "as Icons"))
    let titles = view.items.map(\.title)
    func index(_ key: String.LocalizationValue) -> Int? {
      titles.firstIndex(of: String(localized: key))
    }

    let groupBy = try #require(index("Group By"))
    let sortBy = try #require(index("Sort By"))
    let foldersFirst = try #require(index("Folders First"))
    let reload = try #require(index("Reload"))
    let sidebar = try #require(index("Show Sidebar") ?? index("Hide Sidebar"))
    let statusBar = try #require(index("Show Status Bar") ?? index("Hide Status Bar"))
    let viewOptions = try #require(index("Show View Options"))
    let customize = try #require(view.items.firstIndex { $0.action == #selector(NSWindow.runToolbarCustomizationPalette(_:)) })

    #expect(groupBy < sortBy && sortBy < foldersFirst && foldersFirst < reload && reload < sidebar)
    #expect(statusBar < customize && customize < viewOptions)
  }

  @Test
  internal func `Edit commands follow Select All, File has Tags and Help has Keyboard Shortcuts`() throws {
    let edit = try #require(Self.menu(containing: "Move Items Here"))
    let titles = edit.items.map(\.title)
    let moveItemsHere = try #require(titles.firstIndex(of: String(localized: "Move Items Here")))
    let copyPath = try #require(titles.firstIndex(of: String(localized: "Copy Path")))
    let deselectAll = try #require(titles.firstIndex(of: String(localized: "Deselect All")))
    let find = try #require(titles.firstIndex(of: String(localized: "Find")))

    #expect(moveItemsHere < copyPath && copyPath < deselectAll && deselectAll < find)
    #expect(Self.menu(containing: "Tags…") != nil)
    #expect(Self.menu(containing: "Keyboard Shortcuts") != nil)
    #expect(Self.menu(containing: "Welcome to FileCraft…") != nil)
  }

  @Test
  internal func `Item commands are disabled without a selection`() throws {
    let items = Self.items(in: try #require(NSApp.mainMenu))
    for key: String.LocalizationValue in ["Duplicate", "Make Alias", "Show Original", "Move to Trash"] {
      let item = try #require(items.first { $0.title == String(localized: key) })
      #expect(item.isEnabled == false, "\(item.title)")
    }
  }

  /// Keys whose position differs between keyboard layouts, so that macOS adapts their shortcuts.
  private static let layoutDependentKeys: Set<String> = ["[", "]", "/", ".", ",", "'", ";", "-", "="]

  /// F5 and F6 are menu shortcuts only while a file view has focus, and the second shortcuts of a command work in
  /// file views; full screen uses the system's own shortcut.
  private static func isCheckable(_ shortcut: FileCraft.Shortcut) -> Bool {
    ![FileCraft.Shortcut.f5, FileCraft.Shortcut.f6].contains(shortcut.key) && shortcut != FileCraft.Shortcut("f", [.control, .command])
  }

  private static func menuShortcut(_ shortcut: FileCraft.Shortcut) -> Shortcut {
    var modifiers: NSEvent.ModifierFlags = []
    if shortcut.modifiers.contains(.command) {
      modifiers.insert(.command)
    }
    if shortcut.modifiers.contains(.shift) {
      modifiers.insert(.shift)
    }
    if shortcut.modifiers.contains(.option) {
      modifiers.insert(.option)
    }
    if shortcut.modifiers.contains(.control) {
      modifiers.insert(.control)
    }
    return Shortcut(key: shortcut.key, modifiers: modifiers)
  }

  /// The menu of the menu bar that contains an item titled `key`.
  private static func menu(containing key: String.LocalizationValue) -> NSMenu? {
    let title = String(localized: key)
    return NSApp.mainMenu?.items.compactMap(\.submenu).first { $0.items.contains { $0.title == title } }
  }

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

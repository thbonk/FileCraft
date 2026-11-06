/*
 * ShortcutCatalog.swift
 * FileCraft
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

/// A key combination, as the default shortcut table of the menus spec lists it.
nonisolated internal struct Shortcut: Hashable, Sendable {

  // MARK: - Types

  internal struct Modifiers: OptionSet, Hashable, Sendable {
    internal let rawValue: Int

    internal static let control = Modifiers(rawValue: 1 << 0)
    internal static let option = Modifiers(rawValue: 1 << 1)
    internal static let shift = Modifiers(rawValue: 1 << 2)
    internal static let command = Modifiers(rawValue: 1 << 3)

    internal init(rawValue: Int) {
      self.rawValue = rawValue
    }
  }

  // MARK: - Properties

  /// The key as a menu item's key equivalent stores it: a lowercase character, or a special key such as
  /// `Shortcut.delete`.
  internal let key: String
  internal let modifiers: Modifiers

  internal static let delete = "\u{8}"
  internal static let upArrow = "\u{F700}"
  internal static let downArrow = "\u{F701}"
  internal static let tab = "\t"
  internal static let space = " "
  internal static let f5 = "\u{F708}"
  internal static let f6 = "\u{F709}"

  /// The combination in the order and with the symbols macOS menus use, for example "⇧⌘N".
  internal var symbols: String {
    var result = ""
    if modifiers.contains(.control) {
      result += "⌃"
    }
    if modifiers.contains(.option) {
      result += "⌥"
    }
    if modifiers.contains(.shift) {
      result += "⇧"
    }
    if modifiers.contains(.command) {
      result += "⌘"
    }
    return result + keySymbol
  }

  private var keySymbol: String {
    switch key {
    case Self.delete:
      "⌫"
    case Self.upArrow:
      "↑"
    case Self.downArrow:
      "↓"
    case Self.tab:
      "⇥"
    case Self.space:
      String(localized: "Space", comment: "The space bar in a keyboard shortcut.")
    case Self.f5:
      "F5"
    case Self.f6:
      "F6"
    default:
      key.uppercased()
    }
  }

  // MARK: - Initialization

  internal init(_ key: String, _ modifiers: Modifiers = [.command]) {
    self.key = key
    self.modifiers = modifiers
  }
}

/// The menus of the menu bar, in their order.
nonisolated internal enum MenuName: Int, CaseIterable, Comparable, Sendable {
  case fileCraft
  case file
  case edit
  case view
  case go
  case tools
  case window

  internal var title: LocalizedStringResource {
    switch self {
    case .fileCraft:
      "FileCraft"
    case .file:
      "File"
    case .edit:
      "Edit"
    case .view:
      "View"
    case .go:
      "Go"
    case .tools:
      "Tools"
    case .window:
      "Window"
    }
  }

  internal static func < (lhs: MenuName, rhs: MenuName) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

/// One command of the default shortcut table.
nonisolated internal struct ShortcutEntry: Identifiable, Sendable {

  internal let menu: MenuName
  /// The command's menu title; toggles list the title they show while the item is off.
  internal let title: LocalizedStringResource
  /// The other title of a show/hide toggle, for example "Hide Hidden Files".
  internal let alternateTitle: LocalizedStringResource?
  /// The first shortcut is the menu item's; further ones work in file views or as alternatives.
  internal let shortcuts: [Shortcut]
  /// Whether macOS or SwiftUI provide the menu item, so that its title and shortcut come from the system.
  internal let isSystem: Bool
  /// More words that find the entry, for example "Trash" for Delete Immediately….
  internal let keywords: LocalizedStringResource?

  internal var id: String {
    "\(menu.rawValue).\(title.key)"
  }

  /// Whether `text` occurs in the localized title, the menu name or the keywords, ignoring case and diacritics.
  internal func matches(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard trimmed.isEmpty == false else {
      return true
    }
    let fields = [title, menu.title] + [alternateTitle, keywords].compactMap { $0 }
    return fields.contains { String(localized: $0).localizedStandardContains(trimmed) }
  }
}

/// The default keyboard shortcuts of the menus spec, grouped by menu.
nonisolated internal enum ShortcutCatalog {

  /// macOS shortcuts that work in every application and that FileCraft must not use.
  internal static let systemShortcuts: Set<Shortcut> = [
    Shortcut(Shortcut.space),
    Shortcut(Shortcut.space, [.option, .command]),
    Shortcut(Shortcut.space, [.control]),
    Shortcut(Shortcut.space, [.control, .option]),
    Shortcut(Shortcut.space, [.control, .command]),
    Shortcut(Shortcut.tab),
    Shortcut(Shortcut.tab, [.shift, .command]),
    Shortcut("3", [.shift, .command]),
    Shortcut("4", [.shift, .command]),
    Shortcut("5", [.shift, .command]),
    Shortcut("3", [.control, .shift, .command]),
    Shortcut("4", [.control, .shift, .command]),
    Shortcut("q", [.control, .command]),
    Shortcut("q", [.shift, .command]),
    Shortcut("q", [.option, .shift, .command]),
    Shortcut("\u{1B}", [.option, .command]),
    Shortcut("d", [.option, .command]),
    Shortcut("8", [.option, .command]),
    Shortcut(Shortcut.upArrow, [.control]),
    Shortcut(Shortcut.downArrow, [.control]),
  ]

  internal static let entries: [ShortcutEntry] = [
    // FileCraft
    system(.fileCraft, "Settings…", Shortcut(",")),
    // File
    system(.file, "New Window", Shortcut("n")),
    entry(.file, "New Tab", Shortcut("t")),
    entry(.file, "New Folder", Shortcut("n", [.shift, .command])),
    entry(.file, "New Folder with Selection", Shortcut("n", [.control, .command])),
    entry(.file, "New Text File", Shortcut("n", [.option, .command])),
    entry(.file, "Open", Shortcut("o"), Shortcut(Shortcut.downArrow)),
    entry(.file, "Close Tab", alternate: "Close", Shortcut("w")),
    entry(.file, "Close Window", Shortcut("w", [.shift, .command])),
    entry(.file, "Get Info", Shortcut("i")),
    entry(.file, "Duplicate", Shortcut("d")),
    entry(.file, "Make Alias", Shortcut("a", [.control, .command])),
    entry(.file, "Show Original", Shortcut("r")),
    entry(.file, "Quick Look", Shortcut("y"), Shortcut(Shortcut.space, [])),
    entry(.file, "Add to Sidebar", Shortcut("t", [.control, .command])),
    entry(.file, "Move to Trash", Shortcut(Shortcut.delete)),
    entry(
      .file, "Delete Immediately…", Shortcut(Shortcut.delete, [.option, .command]),
      keywords: "Trash"),
    entry(.file, "Empty Trash…", Shortcut(Shortcut.delete, [.shift, .command])),
    entry(.file, "Eject", Shortcut("e")),
    // Edit
    system(.edit, "Undo", Shortcut("z")),
    system(.edit, "Redo", Shortcut("z", [.shift, .command])),
    system(.edit, "Cut", Shortcut("x")),
    system(.edit, "Copy", Shortcut("c")),
    system(.edit, "Paste", Shortcut("v")),
    system(.edit, "Select All", Shortcut("a")),
    entry(.edit, "Move Items Here", Shortcut("v", [.option, .command])),
    entry(.edit, "Copy Path", Shortcut("c", [.option, .command])),
    entry(.edit, "Deselect All", Shortcut("a", [.option, .command])),
    entry(.edit, "Find", Shortcut("f")),
    // View
    entry(.view, "as Icons", Shortcut("1")),
    entry(.view, "as List", Shortcut("2")),
    entry(.view, "as Columns", Shortcut("3")),
    entry(.view, "Show Hidden Files", alternate: "Hide Hidden Files", Shortcut(".", [.shift, .command])),
    entry(.view, "Show Sidebar", alternate: "Hide Sidebar", Shortcut("s", [.control, .command])),
    entry(.view, "Show Inspector", alternate: "Hide Inspector", Shortcut("i", [.option, .command])),
    entry(.view, "Dual Pane", Shortcut("b", [.option, .command])),
    entry(.view, "Show Path Bar", alternate: "Hide Path Bar", Shortcut("p", [.option, .command])),
    entry(.view, "Show Status Bar", alternate: "Hide Status Bar", Shortcut("/")),
    system(.view, "Hide Toolbar", Shortcut("t", [.option, .command])),
    entry(.view, "Show View Options", Shortcut("j")),
    system(.view, "Enter Full Screen", Shortcut("f", [.control, .command])),
    // Go
    entry(.go, "Back", Shortcut("[")),
    entry(.go, "Forward", Shortcut("]")),
    entry(.go, "Enclosing Folder", Shortcut(Shortcut.upArrow)),
    entry(.go, "Computer", Shortcut("c", [.shift, .command])),
    entry(.go, "Home", Shortcut("h", [.shift, .command])),
    entry(.go, "Desktop", Shortcut("d", [.shift, .command])),
    entry(.go, "Documents", Shortcut("o", [.shift, .command])),
    entry(.go, "Downloads", Shortcut("l", [.option, .command])),
    entry(.go, "Applications", Shortcut("a", [.shift, .command])),
    entry(.go, "Utilities", Shortcut("u", [.shift, .command])),
    entry(.go, "iCloud Drive", Shortcut("i", [.shift, .command])),
    entry(.go, "Go to Folder…", Shortcut("g", [.shift, .command])),
    // Tools
    entry(.tools, "Batch Rename…", Shortcut("r", [.shift, .command])),
    entry(.tools, "Copy to Other Pane", Shortcut(Shortcut.f5, [])),
    entry(.tools, "Move to Other Pane", Shortcut(Shortcut.f6, [])),
    // Window
    system(.window, "Minimize", Shortcut("m")),
    entry(.window, "Show Next Tab", Shortcut("]", [.shift, .command]), Shortcut(Shortcut.tab, [.control])),
    entry(.window, "Show Previous Tab", Shortcut("[", [.shift, .command]), Shortcut(Shortcut.tab, [.control, .shift])),
    entry(.window, "Reopen Closed Tab", Shortcut("t", [.shift, .command])),
  ]

  /// The entries matching `text`, grouped by menu in menu order.
  internal static func sections(matching text: String) -> [(menu: MenuName, entries: [ShortcutEntry])] {
    let matching = entries.filter { $0.matches(text) }
    return MenuName.allCases.compactMap { menu in
      let menuEntries = matching.filter { $0.menu == menu }
      return menuEntries.isEmpty ? nil : (menu, menuEntries)
    }
  }

  // MARK: - Private

  private static func entry(
    _ menu: MenuName,
    _ title: LocalizedStringResource,
    alternate: LocalizedStringResource? = nil,
    _ shortcuts: Shortcut...,
    keywords: LocalizedStringResource? = nil
  ) -> ShortcutEntry {
    ShortcutEntry(menu: menu, title: title, alternateTitle: alternate, shortcuts: shortcuts, isSystem: false, keywords: keywords)
  }

  private static func system(_ menu: MenuName, _ title: LocalizedStringResource, _ shortcut: Shortcut) -> ShortcutEntry {
    ShortcutEntry(menu: menu, title: title, alternateTitle: nil, shortcuts: [shortcut], isSystem: true, keywords: nil)
  }
}

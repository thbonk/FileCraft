/*
 * NavigationHistory.swift
 * FileCraft
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

/// The back and forward history of one tab.
nonisolated internal struct NavigationHistory: Codable, Hashable, Sendable {

  // MARK: - Types

  /// One entry of a Back or Forward history menu. `index` is the value `goBack(toMenuIndex:)` and
  /// `goForward(toMenuIndex:)` expect, and it identifies the entry for as long as the menu is shown.
  nonisolated internal struct MenuEntry: Identifiable, Hashable, Sendable {
    internal let index: Int
    internal let location: Location

    internal var id: Int {
      index
    }
  }

  // MARK: - Properties

  /// The maximum number of entries kept in each direction.
  internal static let limit = 100
  /// The maximum number of entries a history menu lists.
  internal static let menuLimit = 20

  internal private(set) var current: Location
  /// Earlier locations, oldest first.
  internal private(set) var backStack: [Location] = []
  /// Later locations, next one first.
  internal private(set) var forwardStack: [Location] = []

  internal var canGoBack: Bool {
    backStack.isEmpty == false
  }

  internal var canGoForward: Bool {
    forwardStack.isEmpty == false
  }

  /// Entries for the Back button's history menu, most recent first.
  internal var backMenuEntries: [Location] {
    backStack.reversed()
  }

  /// Entries for the Forward button's history menu, next one first.
  internal var forwardMenuEntries: [Location] {
    forwardStack
  }

  /// The Back button's history menu: the most recent `menuLimit` entries, most recent first.
  internal var backMenu: [MenuEntry] {
    Self.menu(of: backMenuEntries)
  }

  /// The Forward button's history menu: the next `menuLimit` entries, next one first.
  internal var forwardMenu: [MenuEntry] {
    Self.menu(of: forwardMenuEntries)
  }

  private static func menu(of entries: [Location]) -> [MenuEntry] {
    entries.prefix(menuLimit).enumerated().map { MenuEntry(index: $0.offset, location: $0.element) }
  }

  // MARK: - Initialization

  internal init(current: Location) {
    self.current = current
  }

  // MARK: - Navigation

  /// Shows `location`, keeps the current location in the back history and discards the forward history.
  internal mutating func navigate(to location: Location) {
    guard location != current else {
      return
    }
    backStack.append(current)
    if backStack.count > Self.limit {
      backStack.removeFirst(backStack.count - Self.limit)
    }
    forwardStack.removeAll()
    current = location
  }

  /// Replaces the current location without recording history, for example after the folder moved.
  internal mutating func replaceCurrent(with location: Location) {
    current = location
  }

  /// Moves one step back and returns the new current location.
  @discardableResult
  internal mutating func goBack() -> Location? {
    guard let previous = backStack.popLast() else {
      return nil
    }
    forwardStack.insert(current, at: 0)
    current = previous
    return previous
  }

  /// Moves one step forward and returns the new current location.
  @discardableResult
  internal mutating func goForward() -> Location? {
    guard forwardStack.isEmpty == false else {
      return nil
    }
    let next = forwardStack.removeFirst()
    backStack.append(current)
    current = next
    return next
  }

  /// Jumps to an entry of `backMenuEntries`, where index 0 is the most recent one.
  @discardableResult
  internal mutating func goBack(toMenuIndex index: Int) -> Location? {
    guard backMenuEntries.indices.contains(index) else {
      return nil
    }
    var location: Location?
    for _ in 0...index {
      location = goBack()
    }
    return location
  }

  /// Jumps to an entry of `forwardMenuEntries`, where index 0 is the next one.
  @discardableResult
  internal mutating func goForward(toMenuIndex index: Int) -> Location? {
    guard forwardMenuEntries.indices.contains(index) else {
      return nil
    }
    var location: Location?
    for _ in 0...index {
      location = goForward()
    }
    return location
  }
}

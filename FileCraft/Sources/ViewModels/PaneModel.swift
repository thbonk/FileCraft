/*
 * PaneModel.swift
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
import Observation

/// One file pane with its tabs. A pane always has at least one tab.
@Observable
internal final class PaneModel: Identifiable {

  // MARK: - Properties

  internal let id = UUID()
  internal private(set) var tabs: [TabModel]
  internal private(set) var currentTab: TabModel
  /// Handed to the tabs the pane creates, so that they record visited folders.
  @ObservationIgnored internal let recents: RecentsStore?
  /// The window that shows the pane; the window sets it.
  @ObservationIgnored internal weak var window: BrowserWindowModel?

  internal var snapshot: PaneSnapshot {
    PaneSnapshot(
      tabs: tabs.map(\.snapshot),
      currentTabIndex: tabs.firstIndex { $0 === currentTab } ?? 0)
  }

  // MARK: - Initialization

  internal init(tab: TabModel, recents: RecentsStore? = nil) {
    tabs = [tab]
    currentTab = tab
    self.recents = recents
    tab.pane = self
  }

  internal convenience init(location: Location, recents: RecentsStore? = nil) {
    self.init(tab: TabModel(location: location, recents: recents), recents: recents)
  }

  /// Restores a pane; an empty snapshot yields one tab at `fallback`.
  internal init(snapshot: PaneSnapshot, fallback: Location, recents: RecentsStore? = nil) {
    let restoredTabs = snapshot.tabs.map { TabModel(snapshot: $0, recents: recents) }
    let paneTabs = restoredTabs.isEmpty ? [TabModel(location: fallback, recents: recents)] : restoredTabs
    tabs = paneTabs
    currentTab = paneTabs.indices.contains(snapshot.currentTabIndex) ? paneTabs[snapshot.currentTabIndex] : paneTabs[0]
    self.recents = recents
    for tab in paneTabs {
      tab.pane = self
    }
  }

  // MARK: - Tabs

  internal func index(of tab: TabModel) -> Int? {
    tabs.firstIndex { $0 === tab }
  }

  /// Makes `tab` the current tab if it belongs to this pane.
  internal func select(_ tab: TabModel) {
    guard index(of: tab) != nil else {
      return
    }
    currentTab = tab
  }

  /// Inserts `tab` after the current tab and makes it current.
  internal func addTab(_ tab: TabModel) {
    insertTab(tab, at: (index(of: currentTab) ?? tabs.count - 1) + 1)
  }

  /// Inserts `tab` at `index`, kept within the tabs; with `selects`, it becomes current.
  internal func insertTab(_ tab: TabModel, at index: Int, selects: Bool = true) {
    tabs.insert(tab, at: min(max(index, 0), tabs.count))
    tab.pane = self
    if selects {
      currentTab = tab
    }
  }

  /// Inserts `tab` before `target`, or at the end without a target, and makes it current.
  internal func insertTab(_ tab: TabModel, before target: TabModel?) {
    insertTab(tab, at: target.flatMap(index(of:)) ?? tabs.count)
  }

  /// Removes `tab` if the pane keeps another tab. When `tab` was current, its right neighbor, or else its left
  /// neighbor, becomes current.
  ///
  /// - Returns: The index `tab` had, or nil when it was not removed.
  @discardableResult
  internal func removeTab(_ tab: TabModel) -> Int? {
    guard tabs.count > 1, let index = index(of: tab) else {
      return nil
    }
    tabs.remove(at: index)
    if currentTab === tab {
      currentTab = tabs[min(index, tabs.count - 1)]
    }
    return index
  }

  /// Moves `tab` before `target`, or to the end without a target.
  internal func moveTab(_ tab: TabModel, before target: TabModel?) {
    guard tab !== target, let source = index(of: tab) else {
      return
    }
    tabs.remove(at: source)
    tabs.insert(tab, at: target.flatMap(index(of:)) ?? tabs.count)
  }

  /// Makes the next tab current, the first one after the last.
  internal func selectNextTab() {
    guard let index = index(of: currentTab) else {
      return
    }
    currentTab = tabs[(index + 1) % tabs.count]
  }

  /// Makes the previous tab current, the last one before the first.
  internal func selectPreviousTab() {
    guard let index = index(of: currentTab) else {
      return
    }
    currentTab = tabs[(index - 1 + tabs.count) % tabs.count]
  }
}

/*
 * PaneModelTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-11-03.
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

internal struct PaneModelTests {

  // MARK: - Tests

  @Test
  internal func `New tabs open after the current tab and know their pane`() {
    let pane = pane(with: ["A", "B"])
    pane.select(pane.tabs[0])

    pane.addTab(TabModel(location: .tag("C")))

    #expect(names(of: pane) == ["A", "C", "B"])
    #expect(pane.currentTab.location == .tag("C"))
    #expect(pane.tabs.allSatisfy { $0.pane === pane })
  }

  @Test
  internal func `Closing the current tab selects its right neighbor, or the left one at the end`() {
    let pane = pane(with: ["A", "B", "C"])
    pane.select(pane.tabs[1])

    pane.removeTab(pane.tabs[1])
    let afterMiddle = pane.currentTab.location
    pane.removeTab(pane.tabs[1])

    #expect(afterMiddle == .tag("C"))
    #expect(pane.currentTab.location == .tag("A"))
    #expect(pane.removeTab(pane.tabs[0]) == nil)
    #expect(names(of: pane) == ["A"])
  }

  @Test
  internal func `Tabs reorder before a target or to the end`() {
    let pane = pane(with: ["A", "B", "C", "D"])

    pane.moveTab(pane.tabs[3], before: pane.tabs[1])
    let afterFirstMove = names(of: pane)
    pane.moveTab(pane.tabs[0], before: nil)

    #expect(afterFirstMove == ["A", "D", "B", "C"])
    #expect(names(of: pane) == ["D", "B", "C", "A"])
  }

  @Test
  internal func `Switching tabs wraps around at both ends`() {
    let pane = pane(with: ["A", "B", "C"])
    pane.select(pane.tabs[2])

    pane.selectNextTab()
    let afterNext = pane.currentTab.location
    pane.selectPreviousTab()

    #expect(afterNext == .tag("A"))
    #expect(pane.currentTab.location == .tag("C"))
  }

  // MARK: - Helpers

  private func pane(with names: [String]) -> PaneModel {
    let pane = PaneModel(tab: TabModel(location: .tag(names[0])))
    for name in names.dropFirst() {
      pane.insertTab(TabModel(location: .tag(name)), at: pane.tabs.count)
    }
    return pane
  }

  private func names(of pane: PaneModel) -> [String] {
    pane.tabs.map(\.title)
  }
}

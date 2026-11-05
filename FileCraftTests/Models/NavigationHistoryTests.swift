/*
 * NavigationHistoryTests.swift
 * FileCraftTests
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

import Testing
@testable import FileCraft

internal struct NavigationHistoryTests {

  // MARK: - Tests

  @Test
  internal func `Going back returns to the previous location and enables Forward`() {
    var history = NavigationHistory(current: .tag("Documents"))
    history.navigate(to: .tag("Invoices"))

    history.goBack()

    #expect(history.current == .tag("Documents"))
    #expect(history.canGoForward)
    #expect(history.forwardMenuEntries == [.tag("Invoices")])
  }

  @Test
  internal func `Navigating after going back discards the forward history`() {
    var history = NavigationHistory(current: .tag("A"))
    history.navigate(to: .tag("B"))
    history.navigate(to: .tag("C"))
    history.goBack()

    history.navigate(to: .tag("D"))

    #expect(history.canGoForward == false)
    #expect(history.backMenuEntries == [.tag("B"), .tag("A")])
  }

  @Test
  internal func `History menu jumps directly to an earlier location`() {
    var history = NavigationHistory(current: .tag("A"))
    for name in ["B", "C", "D", "E"] {
      history.navigate(to: .tag(name))
    }

    let location = history.goBack(toMenuIndex: 2)

    #expect(location == .tag("B"))
    #expect(history.current == .tag("B"))
    #expect(history.forwardMenuEntries == [.tag("C"), .tag("D"), .tag("E")])
  }

  @Test
  internal func `Forward menu jumps directly to a later location`() {
    var history = NavigationHistory(current: .tag("A"))
    for name in ["B", "C", "D"] {
      history.navigate(to: .tag(name))
    }
    history.goBack(toMenuIndex: 2)

    let location = history.goForward(toMenuIndex: 1)

    #expect(location == .tag("C"))
    #expect(history.backMenuEntries == [.tag("B"), .tag("A")])
  }

  @Test
  internal func `Navigating to the current location changes nothing`() {
    var history = NavigationHistory(current: .tag("A"))

    history.navigate(to: .tag("A"))

    #expect(history.canGoBack == false)
  }

  @Test
  internal func `Back history keeps at most the limit`() {
    var history = NavigationHistory(current: .tag("0"))
    for index in 1...(NavigationHistory.limit + 10) {
      history.navigate(to: .tag(String(index)))
    }

    #expect(history.backStack.count == NavigationHistory.limit)
  }

  @Test
  internal func `History menus list the nearest entries with their jump index`() {
    var history = NavigationHistory(current: .tag("0"))
    for index in 1...25 {
      history.navigate(to: .tag("\(index)"))
    }
    history.goBack(toMenuIndex: 1)

    #expect(history.backMenu.count == NavigationHistory.menuLimit)
    #expect(history.backMenu.first?.location == .tag("22"))
    #expect(history.backMenu.map(\.index) == Array(0..<NavigationHistory.menuLimit))
    #expect(history.forwardMenu.map(\.location) == [.tag("24"), .tag("25")])
  }
}

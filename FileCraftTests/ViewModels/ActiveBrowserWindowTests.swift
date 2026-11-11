/*
 * ActiveBrowserWindowTests.swift
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

import Testing
@testable import FileCraft

internal struct ActiveBrowserWindowTests {

  // MARK: - Tests

  @Test
  internal func `The window activated last is the active one`() {
    let registry = ActiveBrowserWindow()
    let first = BrowserWindowModel(location: .tag("A"))
    let second = BrowserWindowModel(location: .tag("B"))

    registry.activate(first)
    registry.activate(second)

    #expect(registry.window === second)
  }

  @Test
  internal func `Closing the active window clears it, closing another one keeps it`() {
    let registry = ActiveBrowserWindow()
    let first = BrowserWindowModel(location: .tag("A"))
    let second = BrowserWindowModel(location: .tag("B"))
    registry.activate(first)

    registry.close(second)
    let afterOtherClosed = registry.window
    registry.close(first)

    #expect(afterOtherClosed === first)
    #expect(registry.window == nil)
  }
}

/*
 * TestHostTests.swift
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

import AppKit
import Testing
@testable import FileCraft

/// Checks that FileCraft, launched as the host of the tests, leaves the user's state alone.
internal struct TestHostTests {

  // MARK: - Tests

  @Test
  internal func `The test host opens no browser window`() {
    // A browser window's toolbar, split view and frame are saved by AppKit into the user's real defaults.
    let browserWindows = NSApp.windows.compactMap(\.identifier?.rawValue).filter { $0.hasPrefix("browser") }

    #expect(AppEnvironment.isTestHost)
    #expect(browserWindows.isEmpty)
  }
}

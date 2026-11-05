/*
 * StandardLocationTests.swift
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

import Foundation
import Testing
@testable import FileCraft

internal struct StandardLocationTests {

  // MARK: - Tests

  @Test
  internal func `Standard locations point to the user's and the system's folders`() {
    let home = URL(filePath: "/Users/anna", directoryHint: .isDirectory)

    let paths = StandardLocation.allCases.map { $0.url(home: home)?.path(percentEncoded: false) }

    #expect(
      paths == [
        nil,
        "/Users/anna/",
        "/Users/anna/Desktop/",
        "/Users/anna/Documents/",
        "/Users/anna/Downloads/",
        "/Applications/",
        "/Applications/Utilities/",
        "/Users/anna/Library/Mobile Documents/com~apple~CloudDocs/",
        "/Users/anna/Library/",
      ])
  }

  @Test
  internal func `iCloud Drive is available only when its folder exists`() throws {
    let home = try TemporaryDirectory()

    let isAvailableBefore = StandardLocation.isICloudDriveAvailable(home: home.url)
    try home.createFolder("Library/Mobile Documents/com~apple~CloudDocs")

    #expect(isAvailableBefore == false)
    #expect(StandardLocation.isICloudDriveAvailable(home: home.url))
  }
}

/*
 * TagLibraryTests.swift
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

/// Spotlight indexes temporary folders unreliably, so the Spotlight queries themselves are not tested here.
internal struct TagLibraryTests {

  // MARK: - Tests

  @Test
  internal func `Color tags come first in Finder's order, other tags follow by name`() {
    // Ordered like NSWorkspace.fileLabels: None, Gray, Green, Purple, Blue, Yellow, Red, Orange.
    let labels = ["None", "Gray", "Green", "Purple", "Blue", "Yellow", "Red", "Orange"]

    let tags = TagLibrary.ordered(standard: labels, found: ["work", "Red", "Archive", "zeta"])

    #expect(tags == ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Gray", "Archive", "work", "zeta"])
  }

  @Test
  internal func `Tag names are escaped for Spotlight queries`() {
    #expect(TagLibrary.escaped("Red") == "Red")
    #expect(TagLibrary.escaped("a \"b\" \\ c*") == "a \\\"b\\\" \\\\ c\\*")
  }

  @Test
  internal func `Dropping on a tag adds it once and keeps the item's other tags`() async throws {
    let directory = try TemporaryDirectory()
    var file = try directory.createFile("report.txt")
    var values = URLResourceValues()
    values.tagNames = ["Work"]
    try file.setResourceValues(values)

    let firstFailures = await TagLibrary.addTag("Blue", to: [file])
    let secondFailures = await TagLibrary.addTag("Blue", to: [file])

    file.removeAllCachedResourceValues()
    #expect(firstFailures.isEmpty)
    #expect(secondFailures.isEmpty)
    #expect(try file.resourceValues(forKeys: [.tagNamesKey]).tagNames == ["Work", "Blue"])
  }

  @Test
  internal func `Items that cannot be tagged are reported`() async {
    let missing = URL(filePath: "/nonexistent/FileCraftTests/missing.txt")

    let failures = await TagLibrary.addTag("Blue", to: [missing])

    #expect(failures == [missing])
  }
}

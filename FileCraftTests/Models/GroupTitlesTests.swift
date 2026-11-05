/*
 * GroupTitlesTests.swift
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

internal struct GroupTitlesTests {

  // MARK: - Properties

  private let english = Locale(identifier: "en_US")
  private let german = Locale(identifier: "de_DE")

  // MARK: - Tests

  @Test
  internal func `An ungrouped view has no section header`() {
    #expect(GroupTitles.title(for: .all) == nil)
  }

  @Test
  internal func `Fixed headers come from the string catalog in English and German`() {
    let groups: [ItemGroup] = [.date(.today), .size(.belowOneMegabyte), .pathExtension(""), .tag(nil), .kind("")]

    let englishTitles = groups.map { GroupTitles.title(for: $0, locale: english, language: english.language) }
    let germanTitles = groups.map { GroupTitles.title(for: $0, locale: german, language: german.language) }

    #expect(englishTitles == ["Today", "Less Than 1 MB", "No Extension", "No Tags", "Other Kinds"])
    #expect(germanTitles == ["Heute", "Weniger als 1 MB", "Kein Suffix", "Keine Tags", "Andere Arten"])
  }

  @Test
  internal func `Months use the locale's month names and years their number`() {
    #expect(GroupTitles.title(for: .date(.month(3)), locale: german, language: german.language) == "März")
    #expect(GroupTitles.title(for: .date(.month(3)), locale: english, language: english.language) == "March")
    #expect(GroupTitles.title(for: .date(.year(2024)), locale: german, language: german.language) == "2024")
  }

  @Test
  internal func `Named groups show their name`() {
    #expect(GroupTitles.title(for: .kind("PDF document")) == "PDF document")
    #expect(GroupTitles.title(for: .pathExtension("pdf")) == "PDF")
    #expect(GroupTitles.title(for: .tag("Red")) == "Red")
  }
}

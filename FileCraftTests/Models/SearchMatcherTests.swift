/*
 * SearchMatcherTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-11-05.
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
import UniformTypeIdentifiers
@testable import FileCraft

internal struct SearchMatcherTests {

  private let now = Date(timeIntervalSince1970: 1_793_000_000)
  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }()

  // MARK: - Text

  @Test
  internal func `The search text matches names ignoring case and diacritics`() {
    let matcher = matcher(SearchParameters(scope: .subfolders, text: "uber"))

    #expect(matcher.matches(item("Über uns.pdf")))
    #expect(matcher.matches(item("SUBERB.txt")))
    #expect(matcher.matches(item("Unter uns.pdf")) == false)
  }

  @Test
  internal func `Hidden items match only when included`() {
    let excluded = matcher(SearchParameters(scope: .subfolders, text: ".env"))
    let included = matcher(SearchParameters(scope: .subfolders, text: ".env", includesHiddenItems: true))

    #expect(excluded.matches(item(".env", isHidden: true)) == false)
    #expect(excluded.mayMatch(name: ".env", localizedName: ".env") == false)
    #expect(included.matches(item(".env", isHidden: true)))
  }

  // MARK: - Criteria

  @Test
  internal func `Large recent images match all three criteria`() {
    let parameters = SearchParameters(
      scope: .subfolders,
      criteria: [
        SearchCriterion(attribute: .kind, kind: .image),
        SearchCriterion(attribute: .size, sizeComparison: .greaterThan, sizeValue: 5, sizeUnit: .megabytes),
        SearchCriterion(attribute: .dateModified, dateCondition: .withinLast, dateAmount: 7, dateUnit: .days),
      ])
    let matcher = matcher(parameters)
    let recent = now.addingTimeInterval(-2 * 86_400)
    let old = now.addingTimeInterval(-30 * 86_400)

    #expect(matcher.matches(item("big.jpg", type: .jpeg, size: 6_000_000, modified: recent)))
    #expect(matcher.matches(item("small.jpg", type: .jpeg, size: 4_000_000, modified: recent)) == false)
    #expect(matcher.matches(item("old.jpg", type: .jpeg, size: 6_000_000, modified: old)) == false)
    #expect(matcher.matches(item("big.mov", type: .quickTimeMovie, size: 6_000_000, modified: recent)) == false)
  }

  @Test
  internal func `Name operators compare the whole name or its ends`() {
    func names(_ nameOperator: SearchCriterion.NameOperator, _ text: String) -> [String] {
      let matcher = matcher(
        SearchParameters(scope: .subfolders, criteria: [SearchCriterion(attribute: .name, nameOperator: nameOperator, text: text)]))
      return ["README.md", "readme", "Old README.txt"].filter { matcher.matches(item($0)) }
    }

    #expect(names(.contains, "readme") == ["README.md", "readme", "Old README.txt"])
    #expect(names(.beginsWith, "readme") == ["README.md", "readme"])
    #expect(names(.endsWith, ".txt") == ["Old README.txt"])
    #expect(names(.isEqual, "Readme") == ["readme"])
    #expect(names(.matchesRegularExpression, "^readme\\.") == ["README.md"])
  }

  @Test
  internal func `Extension, tag and kind criteria match`() {
    let byExtension = matcher(SearchParameters(scope: .subfolders, criteria: [SearchCriterion(attribute: .pathExtension, text: ".PDF")]))
    let byTag = matcher(SearchParameters(scope: .subfolders, criteria: [SearchCriterion(attribute: .tags, text: "rot")]))
    let folders = matcher(SearchParameters(scope: .subfolders, criteria: [SearchCriterion(attribute: .kind, kind: .folder)]))

    #expect(byExtension.matches(item("a.pdf")))
    #expect(byExtension.matches(item("a.txt")) == false)
    #expect(byTag.matches(item("a.txt", tags: ["Rot"])))
    #expect(byTag.matches(item("a.txt", tags: ["Blau"])) == false)
    #expect(folders.matches(FileItem(url: URL(filePath: "/tmp/Docs"), isDirectory: true, contentType: .folder)))
    #expect(folders.matches(FileItem(url: URL(filePath: "/tmp/A.app"), isDirectory: true, isPackage: true, contentType: .applicationBundle)) == false)
  }

  @Test
  internal func `Dates before and after a day exclude that day`() {
    let day = now
    let before = matcher(SearchParameters(scope: .subfolders, criteria: [SearchCriterion(attribute: .dateCreated, dateCondition: .before, date: day)]))
    let after = matcher(SearchParameters(scope: .subfolders, criteria: [SearchCriterion(attribute: .dateCreated, dateCondition: .after, date: day)]))
    let today = matcher(SearchParameters(scope: .subfolders, criteria: [SearchCriterion(attribute: .dateCreated, dateCondition: .today)]))

    let sameDay = FileItem(url: URL(filePath: "/tmp/a"), creationDate: day)
    let dayBefore = FileItem(url: URL(filePath: "/tmp/b"), creationDate: day.addingTimeInterval(-86_400))
    let dayAfter = FileItem(url: URL(filePath: "/tmp/c"), creationDate: day.addingTimeInterval(86_400))

    #expect(before.matches(dayBefore))
    #expect(before.matches(sameDay) == false)
    #expect(after.matches(dayAfter))
    #expect(after.matches(sameDay) == false)
    #expect(today.matches(sameDay))
    #expect(today.matches(dayBefore) == false)
  }

  @Test
  internal func `Size units follow the size unit setting`() {
    let criterion = SearchCriterion(attribute: .size, sizeComparison: .greaterThan, sizeValue: 1, sizeUnit: .kilobytes)
    let decimal = SearchMatcher(parameters: SearchParameters(scope: .subfolders, criteria: [criterion]), sizeUnits: .decimal)
    let binary = SearchMatcher(parameters: SearchParameters(scope: .subfolders, criteria: [criterion]), sizeUnits: .binary)

    #expect(decimal.matches(item("a", size: 1_010)))
    #expect(binary.matches(item("a", size: 1_010)) == false)
  }

  @Test
  internal func `Contents and incomplete criteria do not restrict local searches`() {
    let parameters = SearchParameters(
      scope: .subfolders,
      criteria: [SearchCriterion(attribute: .contents, text: "invoice"), SearchCriterion(attribute: .name, text: "")])

    #expect(parameters.effectiveCriteria.isEmpty)
    #expect(parameters.isEmpty)
    #expect(matcher(parameters).matches(item("anything.txt")))
  }

  // MARK: - Helpers

  private func matcher(_ parameters: SearchParameters) -> SearchMatcher {
    SearchMatcher(parameters: parameters, now: now, calendar: calendar)
  }

  private func item(
    _ name: String,
    isHidden: Bool = false,
    type: UTType? = nil,
    size: Int64? = 1,
    modified: Date? = nil,
    tags: [String] = []
  ) -> FileItem {
    FileItem(
      url: URL(filePath: "/tmp/\(name)"), isHidden: isHidden, contentType: type, size: size, modificationDate: modified,
      tagNames: tags)
  }
}

/*
 * RenameEngineTests.swift
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
@testable import FileCraft

internal struct RenameEngineTests {

  // MARK: - Scenarios of the Specification

  @Test
  internal func `A prefix and a sequence number as suffix`() {
    var prefix = RenameRule(kind: .insertText)
    prefix.insertText = "Trip_"
    prefix.insertPosition = .prefix
    var sequence = RenameRule(kind: .sequenceNumber)
    sequence.sequenceStart = 1
    sequence.sequenceDigits = 3
    sequence.endPosition = .suffix
    sequence.separator = "_"

    #expect(rename("IMG_4711.jpg", [prefix, sequence]) == "Trip_IMG_4711_001.jpg")
  }

  @Test
  internal func `A regular expression with capture groups`() {
    var rule = RenameRule(kind: .regularExpression)
    rule.findText = #"(\d{4})-(\d{2})-(\d{2})"#
    rule.replacementText = "$3.$2.$1"

    #expect(rename("Report 2026-10-30.pdf", [rule]) == "Report 30.10.2026.pdf")
  }

  @Test
  internal func `Uppercase applied to the extension only`() {
    var rule = RenameRule(kind: .changeCase)
    rule.caseStyle = .uppercase
    rule.target = .extensionOnly

    #expect(rename("photo.jpg", [rule]) == "photo.JPG")
  }

  // MARK: - Rules

  @Test
  internal func `Replace Text replaces the first, the last or all occurrences`() {
    var rule = RenameRule(kind: .replaceText)
    rule.findText = "a"
    rule.replacementText = "o"

    rule.occurrence = .all
    #expect(rename("banana.txt", [rule]) == "bonono.txt")
    rule.occurrence = .first
    #expect(rename("banana.txt", [rule]) == "bonana.txt")
    rule.occurrence = .last
    #expect(rename("banana.txt", [rule]) == "banano.txt")
    rule.occurrence = .all
    rule.isCaseSensitive = true
    #expect(rename("BAnana.txt", [rule]) == "BAnono.txt")
  }

  @Test
  internal func `An invalid regular expression changes nothing and is reported`() {
    var rule = RenameRule(kind: .regularExpression)
    rule.findText = "(unclosed"
    let engine = RenameEngine(rules: [rule])

    #expect(engine.newName(for: RenameInput(name: "a(unclosed.txt"), at: 0) == "a(unclosed.txt")
    #expect(engine.invalidRuleIDs == [rule.id])
  }

  @Test
  internal func `Insert Text at a position`() {
    var rule = RenameRule(kind: .insertText)
    rule.insertText = "-"
    rule.insertPosition = .atPosition
    rule.position = 4

    #expect(rename("2026report.pdf", [rule]) == "2026-report.pdf")
    rule.position = 99
    #expect(rename("ab.pdf", [rule]) == "ab-.pdf")
  }

  @Test
  internal func `Remove Characters from the start, the end and a position`() {
    var rule = RenameRule(kind: .removeCharacters)
    rule.removalCount = 4

    rule.removalPosition = .fromStart
    #expect(rename("IMG_0001.jpg", [rule]) == "0001.jpg")
    rule.removalPosition = .fromEnd
    #expect(rename("IMG_0001.jpg", [rule]) == "IMG_.jpg")
    rule.removalPosition = .atPosition
    rule.position = 3
    rule.removalCount = 1
    #expect(rename("IMG_0001.jpg", [rule]) == "IMG0001.jpg")
  }

  @Test
  internal func `Change Case styles`() {
    var rule = RenameRule(kind: .changeCase)

    rule.caseStyle = .lowercase
    #expect(rename("My Holiday.JPG", [rule]) == "my holiday.JPG")
    rule.caseStyle = .titleCase
    #expect(rename("my holiday.jpg", [rule]) == "My Holiday.jpg")
    rule.caseStyle = .sentenceCase
    #expect(rename("MY HOLIDAY.jpg", [rule]) == "My holiday.jpg")
  }

  @Test
  internal func `Sequence numbers count with start and step`() {
    var rule = RenameRule(kind: .sequenceNumber)
    rule.sequenceStart = 10
    rule.sequenceStep = 5
    rule.sequenceDigits = 2
    rule.endPosition = .prefix
    rule.separator = " "
    let engine = RenameEngine(rules: [rule])

    #expect(engine.newName(for: RenameInput(name: "a.txt"), at: 0) == "10 a.txt")
    #expect(engine.newName(for: RenameInput(name: "b.txt"), at: 2) == "20 b.txt")
  }

  @Test
  internal func `Date inserts the chosen date in the chosen format`() {
    var rule = RenameRule(kind: .date)
    rule.dateSource = .created
    rule.dateFormat = "yyyy-MM-dd"
    rule.endPosition = .prefix
    let created = Date(timeIntervalSince1970: 1_761_782_400)  // 2025-10-30 00:00 UTC
    let engine = RenameEngine(rules: [rule], timeZone: .gmt)

    #expect(engine.newName(for: RenameInput(name: "scan.pdf", creationDate: created), at: 0) == "2025-10-30_scan.pdf")
    #expect(engine.newName(for: RenameInput(name: "scan.pdf"), at: 0) == "scan.pdf")
  }

  @Test
  internal func `Change Extension replaces, removes or lowercases`() {
    var rule = RenameRule(kind: .changeExtension)

    rule.extensionChange = .replace
    rule.newExtension = ".jpeg"
    #expect(rename("a.JPG", [rule]) == "a.jpeg")
    #expect(rename("README", [rule]) == "README.jpeg")
    rule.extensionChange = .remove
    #expect(rename("a.tar.gz", [rule]) == "a.tar")
    rule.extensionChange = .lowercase
    #expect(rename("a.JPG", [rule]) == "a.jpg")
  }

  @Test
  internal func `Folders have no extension and disabled rules are skipped`() {
    var upper = RenameRule(kind: .changeCase)
    upper.caseStyle = .uppercase
    var disabled = RenameRule(kind: .insertText)
    disabled.insertText = "x"
    disabled.isEnabled = false
    let engine = RenameEngine(rules: [upper, disabled])

    #expect(engine.newName(for: RenameInput(name: "my.folder", hasExtension: false), at: 0) == "MY.FOLDER")
    #expect(engine.newName(for: RenameInput(name: ".env"), at: 0) == ".ENV")
  }

  // MARK: - Helpers

  private func rename(_ name: String, _ rules: [RenameRule]) -> String {
    RenameEngine(rules: rules, locale: Locale(identifier: "en_US")).newName(for: RenameInput(name: name), at: 0)
  }
}

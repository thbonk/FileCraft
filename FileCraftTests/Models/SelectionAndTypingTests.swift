/*
 * SelectionAndTypingTests.swift
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

import Foundation
import Testing
@testable import FileCraft

internal struct SelectionAndTypingTests {

  // MARK: - Properties

  private let order = ["a", "b", "c", "d", "e"]

  // MARK: - Selection

  @Test
  internal func `Click selects only the clicked item`() {
    var model = SelectionModel()
    model.selectAll(in: order)

    model.select("c")

    #expect(model.selection == ["c"])
    #expect(model.anchor == "c")
  }

  @Test
  internal func `Command-click toggles items`() {
    var model = SelectionModel()
    model.select("a")

    model.toggle("c")
    model.toggle("a")

    #expect(model.selection == ["c"])
  }

  @Test
  internal func `Shift-click selects the range from the anchor`() {
    var model = SelectionModel()
    model.select("d")

    model.extend(to: "b", in: order)

    #expect(model.selection == ["b", "c", "d"])
    #expect(model.anchor == "d")
  }

  @Test
  internal func `Shift-click without anchor acts like a click`() {
    var model = SelectionModel()

    model.extend(to: "b", in: order)

    #expect(model.selection == ["b"])
  }

  @Test
  internal func `Invert and deselect all`() {
    var model = SelectionModel()
    model.select("a")
    model.toggle("b")

    model.invert(in: order)
    #expect(model.selection == ["c", "d", "e"])

    model.deselectAll()
    #expect(model.selection.isEmpty)
    #expect(model.anchor == nil)
  }

  @Test
  internal func `Pruning drops items that disappeared`() {
    var model = SelectionModel()
    model.select("a")
    model.toggle("b")

    model.prune(keeping: ["b", "c"])

    #expect(model.selection == ["b"])
    #expect(model.anchor == "b")
  }

  // MARK: - Type to Select

  @Test
  internal func `Typed characters form a prefix that resets after one second`() {
    var buffer = TypeSelectBuffer()
    let start = ContinuousClock.now

    #expect(buffer.append("r", at: start) == "r")
    #expect(buffer.append("e", at: start.advanced(by: .milliseconds(300))) == "re")
    #expect(buffer.append("p", at: start.advanced(by: .milliseconds(600))) == "rep")
    #expect(buffer.append("x", at: start.advanced(by: .milliseconds(1_800))) == "x")
  }

  @Test
  internal func `Prefix matches ignore case and diacritics`() {
    let entries: [(id: FileItem.ID, name: String)] = [("1", "Anleitung.pdf"), ("2", "Über uns.txt"), ("3", "Report.pdf")]
    let locale = Locale(identifier: "de_DE")

    #expect(TypeSelectBuffer.firstMatch(for: "rep", in: entries, locale: locale) == "3")
    #expect(TypeSelectBuffer.firstMatch(for: "ub", in: entries, locale: locale) == "2")
    #expect(TypeSelectBuffer.firstMatch(for: "zz", in: entries, locale: locale) == nil)
  }

  // MARK: - Name Validation

  @Test
  internal func `Invalid names are rejected with a reason`() {
    let existing = ["a.txt", "Report.pdf"]
    let longName = String(repeating: "€", count: 86)

    #expect(NameValidator.validate("  ", originalName: "a.txt", existingNames: existing) == .empty)
    #expect(NameValidator.validate("x:y", originalName: "a.txt", existingNames: existing) == .invalidCharacter)
    #expect(NameValidator.validate("x/y", originalName: "a.txt", existingNames: existing) == .invalidCharacter)
    #expect(NameValidator.validate(longName, originalName: "a.txt", existingNames: existing) == .tooLong)
    #expect(NameValidator.validate("report.PDF", originalName: "a.txt", existingNames: existing) == .alreadyExists("report.PDF"))
  }

  @Test
  internal func `Changing only the case of a name is allowed`() {
    #expect(NameValidator.validate("A.txt", originalName: "a.txt", existingNames: ["a.txt"]) == nil)
    #expect(NameValidator.validate("b.txt", originalName: "a.txt", existingNames: ["a.txt"]) == nil)
  }
}

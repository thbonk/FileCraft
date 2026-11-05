/*
 * BatchRenameValidatorTests.swift
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

internal struct BatchRenameValidatorTests {

  private let folder = "/tmp/Batch/"

  @Test
  internal func `Names that become equal on a case-insensitive volume are duplicates`() {
    let statuses = validate([("a.txt", "x.txt"), ("A.txt", "X.txt")], existing: ["a.txt", "A.txt"])

    #expect(statuses == [.invalid(.duplicate), .invalid(.duplicate)])
  }

  @Test
  internal func `Case-sensitive volumes keep names that differ in case apart`() {
    let statuses = validate([("a.txt", "x.txt"), ("b.txt", "X.txt")], existing: ["a.txt", "b.txt"], caseSensitive: true)

    #expect(statuses == [.renamed, .renamed])
  }

  @Test
  internal func `A new name taken by an item outside the batch is an error`() {
    let statuses = validate([("a.txt", "other.txt")], existing: ["a.txt", "other.txt"])

    #expect(statuses == [.invalid(.alreadyExists)])
  }

  @Test
  internal func `Exchanging names within the batch is allowed`() {
    let statuses = validate([("a.txt", "b.txt"), ("b.txt", "a.txt")], existing: ["a.txt", "b.txt"])

    #expect(statuses == [.renamed, .renamed])
  }

  @Test
  internal func `A new name equal to an unchanged item's name is a duplicate`() {
    let statuses = validate([("a.txt", "b.txt"), ("b.txt", "b.txt")], existing: ["a.txt", "b.txt"])

    #expect(statuses == [.invalid(.duplicate), .invalid(.duplicate)])
  }

  @Test
  internal func `Empty, invalid and too long names are errors and unchanged names are marked`() {
    let long = String(repeating: "é", count: 128)
    let statuses = validate(
      [("a", " "), ("b", "x:y"), ("c", ".."), ("d", long), ("e", "e")], existing: ["a", "b", "c", "d", "e"])

    #expect(statuses == [.invalid(.empty), .invalid(.invalidCharacter), .invalid(.invalidCharacter), .invalid(.tooLong), .unchanged])
  }

  @Test
  internal func `Changing only the case of a name is allowed`() {
    #expect(validate([("photo.jpg", "Photo.jpg")], existing: ["photo.jpg"]) == [.renamed])
  }

  @Test
  internal func `Equal names in different folders are no duplicates`() {
    let entries = [
      BatchRenameEntry(url: URL(filePath: "/tmp/A/x.txt"), newName: "y.txt"),
      BatchRenameEntry(url: URL(filePath: "/tmp/B/x.txt"), newName: "y.txt"),
    ]
    let statuses = BatchRenameValidator.validate(entries, existingNames: ["/tmp/A/": ["x.txt"], "/tmp/B/": ["x.txt"]])

    #expect(statuses == [.renamed, .renamed])
  }

  // MARK: - Helpers

  private func validate(_ pairs: [(String, String)], existing: [String], caseSensitive: Bool = false) -> [BatchRenameStatus] {
    let entries = pairs.map { BatchRenameEntry(url: URL(filePath: folder + $0.0), newName: $0.1) }
    return BatchRenameValidator.validate(
      entries, existingNames: [folder: existing], caseSensitiveFolders: caseSensitive ? [folder] : [])
  }
}

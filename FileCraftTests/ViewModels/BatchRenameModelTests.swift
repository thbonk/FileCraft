/*
 * BatchRenameModelTests.swift
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

internal struct BatchRenameModelTests {

  @Test
  internal func `Sequence numbers follow the chosen order`() {
    let older = FileItem(url: URL(filePath: "/tmp/B/b.jpg"), creationDate: Date(timeIntervalSince1970: 100))
    let newer = FileItem(url: URL(filePath: "/tmp/B/a.jpg"), creationDate: Date(timeIntervalSince1970: 200))
    let model = BatchRenameModel(items: [newer, older], folderNames: folderNames(["a.jpg", "b.jpg"]))
    var sequence = RenameRule(kind: .sequenceNumber)
    sequence.sequenceDigits = 1
    model.rules = [sequence]

    #expect(model.rows.map(\.newName) == ["a_1.jpg", "b_2.jpg"])
    model.order = .dateCreated
    #expect(model.rows.map(\.newName) == ["b_1.jpg", "a_2.jpg"])
  }

  @Test
  internal func `Rename offers moves only without errors and with changes`() {
    let items = [FileItem(url: URL(filePath: "/tmp/B/a.txt")), FileItem(url: URL(filePath: "/tmp/B/A2.txt"))]
    let model = BatchRenameModel(items: items, folderNames: folderNames(["a.txt", "A2.txt"]))

    #expect(model.moves(in: model.rows) == nil)

    var lower = RenameRule(kind: .changeCase)
    lower.caseStyle = .lowercase
    model.rules = [lower]
    #expect(model.moves(in: model.rows) == [ItemMove(from: items[1].url, to: URL(filePath: "/tmp/B/a2.txt"))])

    var replace = RenameRule(kind: .replaceText)
    replace.findText = "2"
    model.rules = [lower, replace]
    #expect(model.rows.filter(\.status.isError).count == 2)
    #expect(model.moves(in: model.rows) == nil)
  }

  @Test
  internal func `Applying a preset replaces the rules`() {
    let model = BatchRenameModel(items: [], folderNames: folderNames([]))
    let preset = RenamePreset(name: "Photo export", rules: [RenameRule(kind: .sequenceNumber), RenameRule(kind: .date)])

    model.apply(preset)

    #expect(model.rules.map(\.kind) == [.sequenceNumber, .date])
    #expect(Set(model.rules.map(\.id)).isDisjoint(with: preset.rules.map(\.id)))
  }

  @Test
  internal func `Rules can be reordered`() {
    let model = BatchRenameModel(items: [], folderNames: folderNames([]))
    model.rules = [RenameRule(kind: .insertText), RenameRule(kind: .changeCase), RenameRule(kind: .date)]

    model.moveRules(from: [0], to: 3)

    #expect(model.rules.map(\.kind) == [.changeCase, .date, .insertText])
  }

  @Test
  internal func `The preview of 1,000 items takes less than 100 ms`() {
    let names = (0..<1_000).map { "IMG_\($0).JPG" }
    let items = names.map { FileItem(url: URL(filePath: "/tmp/B/\($0)"), creationDate: .now) }
    let model = BatchRenameModel(items: items, folderNames: folderNames(names))
    var prefix = RenameRule(kind: .insertText)
    prefix.insertText = "Trip_"
    prefix.insertPosition = .prefix
    var expression = RenameRule(kind: .regularExpression)
    expression.findText = #"IMG_(\d+)"#
    expression.replacementText = "Photo $1"
    var lowercase = RenameRule(kind: .changeExtension)
    lowercase.extensionChange = .lowercase
    model.rules = [prefix, expression, RenameRule(kind: .sequenceNumber), RenameRule(kind: .date), lowercase]

    let clock = ContinuousClock()
    var rows: [BatchRenameModel.Row] = []
    let duration = clock.measure {
      rows = model.rows
    }

    #expect(rows.count == 1_000)
    #expect(rows.allSatisfy { $0.status == .renamed })
    #expect(duration < .milliseconds(100))
  }

  // MARK: - Helpers

  private func folderNames(_ names: [String]) -> BatchRenameModel.FolderNames {
    BatchRenameModel.FolderNames(names: ["/tmp/B/": names], caseSensitiveFolders: [])
  }
}

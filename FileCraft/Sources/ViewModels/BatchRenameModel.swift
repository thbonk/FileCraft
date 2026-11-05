/*
 * BatchRenameModel.swift
 * FileCraft
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
import Observation

/// The state of the batch rename sheet: the items, the rules, the item order and the preview.
@Observable
internal final class BatchRenameModel: Identifiable {

  // MARK: - Types

  /// The order in which sequence numbers count the items.
  internal enum Order: String, CaseIterable, Hashable, Sendable {
    /// The order of the active view.
    case asShown
    case name
    case dateModified
    case dateCreated
  }

  /// One row of the preview.
  internal struct Row: Identifiable, Hashable {
    internal let item: FileItem
    internal let newName: String
    internal let status: BatchRenameStatus

    internal var id: FileItem.ID {
      item.id
    }
  }

  /// The names in the folders of the batch, which the preview checks for collisions.
  nonisolated internal struct FolderNames: Sendable {
    internal var names: [String: [String]] = [:]
    internal var caseSensitiveFolders: Set<String> = []
  }

  // MARK: - Properties

  internal let id = UUID()
  /// The items to rename, in the order of the active view.
  internal let items: [FileItem]
  internal var rules: [RenameRule] = []
  internal var order: Order = .asShown
  /// Whether the names of the folders are loaded; Rename waits for them.
  internal private(set) var isLoaded = false

  private var folderNames = FolderNames()

  // MARK: - Initialization

  internal init(items: [FileItem]) {
    self.items = items
  }

  /// Creates a model whose folder names are known, for previews and tests.
  internal init(items: [FileItem], folderNames: FolderNames) {
    self.items = items
    self.folderNames = folderNames
    isLoaded = true
  }

  // MARK: - Preview

  /// The items in the chosen order.
  internal var orderedItems: [FileItem] {
    switch order {
    case .asShown:
      items
    case .name:
      items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    case .dateModified:
      items.sorted { ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast) }
    case .dateCreated:
      items.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }
  }

  /// The preview rows in the chosen order: current name, new name and status.
  internal var rows: [Row] {
    let ordered = orderedItems
    let engine = RenameEngine(rules: rules)
    let newNames = ordered.enumerated().map { index, item in
      engine.newName(for: RenameInput(item: item), at: index)
    }
    let entries = zip(ordered, newNames).map { BatchRenameEntry(url: $0.url, newName: $1) }
    let statuses = BatchRenameValidator.validate(
      entries, existingNames: folderNames.names, caseSensitiveFolders: folderNames.caseSensitiveFolders)
    return zip(ordered, zip(newNames, statuses)).map { item, result in
      Row(item: item, newName: result.0, status: result.1)
    }
  }

  /// The enabled Regular Expression rules whose pattern is not valid.
  internal var invalidRuleIDs: Set<UUID> {
    RenameEngine(rules: rules).invalidRuleIDs
  }

  // MARK: - Rules

  internal func addRule(_ kind: RenameRule.Kind) {
    rules.append(RenameRule(kind: kind))
  }

  internal func removeRule(_ id: RenameRule.ID) {
    rules.removeAll { $0.id == id }
  }

  internal func moveRules(from source: IndexSet, to destination: Int) {
    let moving = source.map { rules[$0] }
    var remaining = rules.enumerated().filter { source.contains($0.offset) == false }.map(\.element)
    let insertion = min(destination - source.count { $0 < destination }, remaining.count)
    remaining.insert(contentsOf: moving, at: max(insertion, 0))
    rules = remaining
  }

  /// Replaces the rules with a copy of `preset`'s rules.
  internal func apply(_ preset: RenamePreset) {
    rules = preset.rules.map { rule in
      var copy = rule
      copy.id = UUID()
      return copy
    }
  }

  // MARK: - Renaming

  /// The renames Rename performs, or nil while a row has an error or nothing changes.
  internal func moves(in rows: [Row]) -> [ItemMove]? {
    guard rows.contains(where: \.status.isError) == false else {
      return nil
    }
    let moves = rows.filter { $0.status == .renamed }.map { row in
      ItemMove(from: row.item.url, to: row.item.url.deletingLastPathComponent().appending(path: row.newName))
    }
    return moves.isEmpty ? nil : moves
  }

  /// Reads the names of all items in the batch's folders and whether the folders are on case-sensitive volumes.
  internal func loadFolderNames() async {
    guard isLoaded == false else {
      return
    }
    let folders = Set(items.map { $0.url.deletingLastPathComponent() })
    folderNames = await Self.readFolderNames(Array(folders))
    isLoaded = true
  }

  @concurrent
  private static func readFolderNames(_ folders: [URL]) async -> FolderNames {
    var result = FolderNames()
    for folder in folders {
      let key = folder.path(percentEncoded: false)
      result.names[key] = (try? FileManager.default.contentsOfDirectory(atPath: key)) ?? []
      let values = try? folder.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey])
      if values?.volumeSupportsCaseSensitiveNames == true {
        result.caseSensitiveFolders.insert(key)
      }
    }
    return result
  }
}

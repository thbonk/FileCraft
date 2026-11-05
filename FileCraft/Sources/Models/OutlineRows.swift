/*
 * OutlineRows.swift
 * FileCraft
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

/// One row of the hierarchical list view.
nonisolated internal struct FileRow: Identifiable, Hashable, Sendable {

  // MARK: - Properties

  internal let item: FileItem
  /// The nesting level; items of the tab's folder have depth 0.
  internal let depth: Int
  internal let isExpandable: Bool
  internal let isExpanded: Bool

  internal var id: FileItem.ID {
    item.id
  }

  // MARK: - Sort Values

  // The table maps clicked column headers to sort keys through these key paths; FileCraft sorts itself.

  internal var sortName: String {
    item.localizedName
  }

  /// The path of the folder containing the item, for the Location column of search results.
  internal var sortLocation: String {
    item.url.deletingLastPathComponent().path(percentEncoded: false)
  }

  internal var sortKind: String {
    item.kind
  }

  internal var sortSize: Int64 {
    item.size ?? -1
  }

  internal var sortDateModified: Date {
    item.modificationDate ?? .distantPast
  }

  internal var sortDateCreated: Date {
    item.creationDate ?? .distantPast
  }

  internal var sortDateLastOpened: Date {
    item.lastOpenedDate ?? .distantPast
  }

  internal var sortDateAdded: Date {
    item.addedDate ?? .distantPast
  }

  internal var sortExtension: String {
    item.pathExtension
  }

  internal var sortTags: String {
    item.tagNames.first ?? ""
  }

  /// Versions are loaded per cell, so the Version column does not sort.
  internal var sortVersion: String {
    ""
  }

  internal var sortPermissions: Int {
    Int(item.permissions ?? 0)
  }

  internal var sortOwner: UInt32 {
    item.ownerID ?? 0
  }

  internal var sortGroup: UInt32 {
    item.groupID ?? 0
  }
}

/// The rows of one group in a grouped list view.
nonisolated internal struct OutlineSection: Identifiable, Hashable, Sendable {
  internal let group: ItemGroup
  internal let rows: [FileRow]

  internal var id: ItemGroup {
    group
  }
}

/// Flattens a folder and the expanded subfolders of the list view into display rows.
nonisolated internal enum OutlineRows {

  /// Returns the rows of `items` in display order, each expanded folder followed by its loaded children.
  ///
  /// - Parameters:
  ///   - children: The loaded children of folders, by folder identifier.
  ///   - expanded: The identifiers of expanded folders.
  ///   - isExpandable: Whether an item shows a disclosure control.
  internal static func rows(
    for items: [FileItem],
    children: [FileItem.ID: [FileItem]],
    expanded: Set<FileItem.ID>,
    sorting: ItemSorting,
    isExpandable: (FileItem) -> Bool
  ) -> [FileRow] {
    var rows: [FileRow] = []
    rows.reserveCapacity(items.count)
    var pending: [(items: [FileItem], depth: Int)] = [(sorting.sorted(items), 0)]
    // An explicit stack instead of recursion keeps deep expansions safe; children are inserted after their parent.
    while let level = pending.popLast() {
      var index = 0
      while index < level.items.count {
        let item = level.items[index]
        index += 1
        let expandable = isExpandable(item)
        let isExpanded = expandable && expanded.contains(item.id)
        rows.append(FileRow(item: item, depth: level.depth, isExpandable: expandable, isExpanded: isExpanded))
        if isExpanded, let itemChildren = children[item.id], itemChildren.isEmpty == false {
          pending.append((Array(level.items[index...]), level.depth))
          pending.append((sorting.sorted(itemChildren), level.depth + 1))
          break
        }
      }
    }
    return rows
  }
}

/*
 * SelectionModel.swift
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

/// The selection rules shared by all file views: click, ⌘-click, ⇧-click, Select All, Deselect All and Invert.
///
/// The anchor is the item a ⇧-click range starts from; it moves with every click and ⌘-click.
nonisolated internal struct SelectionModel: Hashable, Sendable {

  // MARK: - Properties

  internal private(set) var selection: Set<FileItem.ID> = []
  internal private(set) var anchor: FileItem.ID?

  // MARK: - Clicking

  /// Selects only `id`, as a plain click does.
  internal mutating func select(_ id: FileItem.ID) {
    selection = [id]
    anchor = id
  }

  /// Adds or removes `id`, as a ⌘-click does.
  internal mutating func toggle(_ id: FileItem.ID) {
    if selection.contains(id) {
      selection.remove(id)
    } else {
      selection.insert(id)
    }
    anchor = id
  }

  /// Selects the range from the anchor to `id` in display `order`, as a ⇧-click does.
  ///
  /// Without an anchor in `order`, it behaves like a plain click.
  internal mutating func extend(to id: FileItem.ID, in order: [FileItem.ID]) {
    guard
      let anchor,
      let anchorIndex = order.firstIndex(of: anchor),
      let targetIndex = order.firstIndex(of: id)
    else {
      select(id)
      return
    }
    selection = Set(order[min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)])
  }

  // MARK: - Commands

  internal mutating func selectAll(in order: [FileItem.ID]) {
    selection = Set(order)
    anchor = order.first
  }

  internal mutating func deselectAll() {
    selection = []
    anchor = nil
  }

  /// Selects exactly the items of `order` that are not selected.
  internal mutating func invert(in order: [FileItem.ID]) {
    selection = Set(order).subtracting(selection)
    anchor = order.first { selection.contains($0) }
  }

  // MARK: - Updating

  /// Replaces the selection, for example with a selection a table reports.
  internal mutating func replace(with ids: Set<FileItem.ID>) {
    if let anchor, ids.contains(anchor) == false {
      self.anchor = ids.first
    } else if anchor == nil {
      anchor = ids.first
    }
    selection = ids
  }

  /// Drops identifiers that are no longer listed.
  internal mutating func prune(keeping ids: Set<FileItem.ID>) {
    selection.formIntersection(ids)
    if let anchor, ids.contains(anchor) == false {
      self.anchor = nil
    }
  }
}

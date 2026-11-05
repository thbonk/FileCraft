/*
 * StatusSummary.swift
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

/// The counts and sizes the status bar shows for a pane.
nonisolated internal struct StatusSummary: Hashable, Sendable {

  // MARK: - Properties

  internal let itemCount: Int
  internal let selectedCount: Int
  /// The total size of the selected files, or nil when no selected item has a known size.
  internal let selectedSize: Int64?

  // MARK: - Initialization

  /// - Parameters:
  ///   - items: The visible items, after filtering.
  ///   - selection: The identifiers of the selected items.
  internal init(items: [FileItem], selection: Set<FileItem.ID>) {
    itemCount = items.count
    let selectedItems = items.filter { selection.contains($0.id) }
    selectedCount = selectedItems.count
    let sizes = selectedItems.compactMap(\.size)
    selectedSize = sizes.isEmpty ? nil : sizes.reduce(0, +)
  }
}

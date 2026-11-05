/*
 * StatusBarView.swift
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

import SwiftUI

/// The item count, selection summary, active filter and available space of a pane.
internal struct StatusBarView: View {

  // MARK: - Properties

  internal let tab: TabModel

  @AppStorage(SettingsKeys.sizeUnits.name) private var sizeUnits = SettingsKeys.sizeUnits.defaultValue
  @Environment(\.locale) private var locale
  /// The total size of the selected folders once calculated.
  @State private var folderBytes: Int64?
  @State private var isCalculatingFolderSizes = false

  // MARK: - Body

  internal var body: some View {
    let items = tab.visibleItems
    let summary = StatusSummary(items: items, selection: tab.selection)
    let formatter = ByteSizeFormatter(units: sizeUnits, locale: locale)
    let selectedFolders = tab.selectedItems.filter(\.isDirectory)
    HStack(spacing: 12) {
      if tab.filterText.isEmpty == false {
        Text("Filter “\(tab.filterText)”: \(items.count) of \(tab.listing.items.count)")
      }
      selectionText(summary, formatter: formatter)
      if isCalculatingFolderSizes {
        ProgressView()
          .controlSize(.mini)
          .accessibilityLabel(Text("Calculating Sizes"))
      }
      Spacer(minLength: 8)
      if let capacity = tab.listing.availableCapacity {
        Text("\(formatter.string(for: capacity)) available")
      }
    }
    .font(.callout)
    .foregroundStyle(.secondary)
    .lineLimit(1)
    .padding(.horizontal, 8)
    .frame(height: 22)
    .task(id: selectedFolders.map(\.id)) {
      await calculateSizes(of: selectedFolders)
    }
  }

  // MARK: - Private

  @ViewBuilder
  private func selectionText(_ summary: StatusSummary, formatter: ByteSizeFormatter) -> some View {
    if summary.selectedCount == 0 {
      Text("\(summary.itemCount) items")
    } else if let size = totalSelectedSize(summary) {
      Text("\(summary.selectedCount) of \(summary.itemCount) selected, \(formatter.string(for: size))")
    } else {
      Text("\(summary.selectedCount) of \(summary.itemCount) selected")
    }
  }

  /// The size of the selected files plus the calculated size of the selected folders.
  private func totalSelectedSize(_ summary: StatusSummary) -> Int64? {
    switch (summary.selectedSize, folderBytes) {
    case (nil, nil):
      nil
    case (let files, let folders):
      (files ?? 0) + (folders ?? 0)
    }
  }

  /// Adds up the sizes of the selected folders; a new selection cancels the calculation.
  private func calculateSizes(of folders: [FileItem]) async {
    folderBytes = nil
    guard folders.isEmpty == false else {
      isCalculatingFolderSizes = false
      return
    }
    isCalculatingFolderSizes = true
    var total: Int64 = 0
    for folder in folders {
      guard let size = try? await FolderSizeService.shared.size(of: folder.url) else {
        continue
      }
      total += size.logicalBytes
    }
    guard Task.isCancelled == false else {
      return
    }
    folderBytes = total
    isCalculatingFolderSizes = false
  }
}

#Preview("English") {
  let tab = TabModel.preview(in: .english)
  tab.selection = Set(tab.visibleItems.prefix(2).map(\.id))

  return StatusBarView(tab: tab)
    .frame(width: 480)
}

#Preview("German") {
  StatusBarView(tab: .preview(in: .german))
    .frame(width: 480)
    .environment(\.locale, Locale(identifier: "de"))
}

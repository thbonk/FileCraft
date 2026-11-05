/*
 * ConflictSheet.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-03.
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

/// The conflict dialog (file operations spec, "Conflict resolution"): compares the existing item with the one that
/// is copied or moved by kind, size and modification date, and offers Replace, Keep Both, Skip and Stop, plus Merge
/// for two folders and applying the choice to all conflicts.
internal struct ConflictSheet: View {

  // MARK: - Properties

  internal let kind: FileOperationKind
  internal let source: ItemSummary
  internal let existing: ItemSummary
  /// Whether folder sizes are calculated; previews turn it off.
  internal var calculatesFolderSizes = true
  internal let onAnswer: (ConflictChoice, Bool) -> Void

  @State private var appliesToAll = false

  private var canMerge: Bool {
    source.isFolder && existing.isFolder
  }

  // MARK: - Body

  internal var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text("An item named “\(existing.name)” already exists in this location.")
          .font(.headline)
        Group {
          switch kind {
          case .copy, .delete, .compress, .expand:
            Text("Do you want to replace it with the one you’re copying?")
          case .move:
            Text("Do you want to replace it with the one you’re moving?")
          }
        }
        .foregroundStyle(.secondary)
      }
      .fixedSize(horizontal: false, vertical: true)
      HStack(alignment: .top, spacing: 24) {
        ItemComparisonColumn(title: "Existing Item", summary: existing, calculatesFolderSize: calculatesFolderSizes)
        ItemComparisonColumn(title: "New Item", summary: source, calculatesFolderSize: calculatesFolderSizes)
      }
      Toggle("Apply to all conflicts", isOn: $appliesToAll)
      HStack {
        Button("Stop") {
          onAnswer(.stop, false)
        }
        .keyboardShortcut(.cancelAction)
        Button("Skip") {
          onAnswer(.skip, appliesToAll)
        }
        Spacer()
        if canMerge {
          Button("Merge") {
            onAnswer(.merge, appliesToAll)
          }
        }
        Button("Replace") {
          onAnswer(.replace, appliesToAll)
        }
        Button("Keep Both") {
          onAnswer(.keepBoth, appliesToAll)
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 500)
    .interactiveDismissDisabled()
  }
}

/// One side of the conflict dialog: the icon, kind, size and modification date of an item.
private struct ItemComparisonColumn: View {

  // MARK: - Properties

  let title: LocalizedStringKey
  let summary: ItemSummary
  let calculatesFolderSize: Bool

  @Environment(\.locale) private var locale
  @AppStorage(SettingsKeys.sizeUnits.name) private var sizeUnits = SettingsKeys.sizeUnits.defaultValue
  @State private var folderSize: Int64?

  // MARK: - Body

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.subheadline.weight(.semibold))
      HStack(alignment: .top, spacing: 8) {
        FileIcon(url: summary.url, size: 32)
        VStack(alignment: .leading, spacing: 2) {
          if let kind = summary.kind {
            Text(verbatim: kind)
          }
          size
          if let date = summary.modificationDate {
            Text("Modified \(date.formatted(.dateTime.locale(locale)))")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .task(id: summary.url) {
      guard summary.size == nil, calculatesFolderSize else {
        return
      }
      folderSize = try? await FolderSizeService.shared.size(of: summary.url).logicalBytes
    }
  }

  @ViewBuilder private var size: some View {
    let formatter = ByteSizeFormatter(units: sizeUnits, locale: locale)
    if let bytes = summary.size ?? folderSize {
      Text(verbatim: formatter.string(for: bytes))
    } else if calculatesFolderSize {
      Text("Calculating…")
    }
  }
}

// MARK: - Previews

#Preview("Files, English") {
  ConflictSheet(
    kind: .copy, source: OperationPreviewData.newReport, existing: OperationPreviewData.existingReport,
    calculatesFolderSizes: false
  ) { _, _ in }
}

#Preview("Folders, German") {
  ConflictSheet(
    kind: .move, source: OperationPreviewData.newFolder, existing: OperationPreviewData.existingFolder,
    calculatesFolderSizes: false
  ) { _, _ in }
  .environment(\.locale, Locale(identifier: "de"))
}

/*
 * ColumnFileView.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-10-31.
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

/// The column view: the tab's folder and every opened subfolder side by side, followed by a preview
/// column for a single selected file. Each column stays current with FSEvents.
internal struct ColumnFileView: View {

  // MARK: - Properties

  internal let tab: TabModel

  @State private var columnWidths: [Int: CGFloat] = [:]
  @FocusState private var focusedColumn: Int?

  private static let defaultColumnWidth: CGFloat = 220
  private static let columnWidthRange: ClosedRange<CGFloat> = 140...480

  // MARK: - Body

  internal var body: some View {
    let chain = tab.columnChain
    let previewItem = previewItem
    ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        HStack(spacing: 0) {
          column(0, folder: tab.folderURL, rootListing: tab.listing)
          ForEach(Array(chain.enumerated()), id: \.element.id) { offset, folder in
            column(offset + 1, folder: folder.url, rootListing: nil)
          }
          if let previewItem {
            PreviewColumn(item: previewItem)
              .frame(width: 280)
              .id(ColumnID.preview)
          }
        }
        .frame(maxHeight: .infinity)
      }
      .onChange(of: tab.focusRequest) {
        // The deepest column with a selection is where the user was working.
        focusedColumn = tab.columnSelections.keys.max() ?? 0
      }
      .onChange(of: focusedColumn) { _, column in
        if column != nil {
          tab.didReceiveFocus()
        }
      }
      .onChange(of: ColumnScrollKey(folders: chain.map(\.id), previewID: previewItem?.id)) {
        proxy.scrollTo(previewItem == nil ? ColumnID.column(chain.count) : ColumnID.preview, anchor: .trailing)
      }
    }
  }

  // MARK: - Private

  /// The single selected file shown in the preview column, if the column is turned on.
  private var previewItem: FileItem? {
    let selected = tab.selectedItems
    guard
      tab.viewSettings.showsPreviewColumn,
      selected.count == 1,
      let item = selected.first,
      tab.opensAsFolder(item) == false
    else {
      return nil
    }
    return item
  }

  @ViewBuilder
  private func column(_ index: Int, folder: URL?, rootListing: DirectoryListing?) -> some View {
    BrowserColumn(index: index, folder: folder, rootListing: rootListing, tab: tab, focusedColumn: $focusedColumn)
      .frame(width: columnWidths[index] ?? Self.defaultColumnWidth)
      .id(ColumnID.column(index))
    SplitDivider(axis: .horizontal) { delta in
      let width = (columnWidths[index] ?? Self.defaultColumnWidth) + delta
      columnWidths[index] = min(max(width, Self.columnWidthRange.lowerBound), Self.columnWidthRange.upperBound)
    }
  }
}

nonisolated private enum ColumnID: Hashable {
  case column(Int)
  case preview
}

/// What the column view scrolls to show: a change of the open folders or of the previewed file.
nonisolated private struct ColumnScrollKey: Equatable {
  let folders: [FileItem.ID]
  let previewID: FileItem.ID?
}

/// One column: the items of a folder with single or multiple selection, → into a folder, ← back.
private struct BrowserColumn: View {

  let index: Int
  let folder: URL?
  /// The tab's own listing for the first column; deeper columns load their folder themselves.
  let rootListing: DirectoryListing?
  let tab: TabModel
  var focusedColumn: FocusState<Int?>.Binding

  @AppStorage(SettingsKeys.showsHiddenFiles.name) private var showsHiddenFiles = SettingsKeys.showsHiddenFiles.defaultValue
  @AppStorage(SettingsKeys.alwaysShowsFileExtensions.name)
  private var alwaysShowsExtensions = SettingsKeys.alwaysShowsFileExtensions.defaultValue
  @AppStorage(SettingsKeys.returnKeyAction.name) private var returnKeyAction = SettingsKeys.returnKeyAction.defaultValue
  @AppStorage(SettingsKeys.sizeUnits.name) private var sizeUnits = SettingsKeys.sizeUnits.defaultValue
  @Environment(\.locale) private var locale
  @State private var ownListing = DirectoryListing()

  var body: some View {
    let items = items
    List(items, selection: selection(for: items)) { item in
      ColumnRow(
        item: item,
        name: ItemPresentation.displayName(of: item, alwaysShowsExtensions: alwaysShowsExtensions),
        opensAsFolder: tab.opensAsFolder(item),
        isRenaming: tab.renamingItemID == item.id,
        tab: tab,
        sizeUnits: sizeUnits,
        locale: locale)
      .draggable(containerItemID: item.id)
      .fileDropTarget(tab.opensAsFolder(item) ? item.url : nil, tab: tab, springsOpen: true)
    }
    .fileDragContainer(tab: tab, items: items)
    .font(tab.viewSettings.textSize.font)
    .focused(focusedColumn, equals: index)
    .contextMenu(forSelectionType: FileItem.ID.self) { identifiers in
      if identifiers.isEmpty {
        FileBackgroundContextMenu(tab: tab, folder: folder)
      } else {
        FileItemContextMenu(items: items.filter { identifiers.contains($0.id) }, tab: tab)
      }
    } primaryAction: { identifiers in
      tab.open(items.filter { identifiers.contains($0.id) })
    }
    .emptyAreaContextMenu {
      FileBackgroundContextMenu(tab: tab, folder: folder)
    }
    .onKeyPress(phases: .down) { press in
      handle(press, items: items)
    }
    // → asks for the first item either before the column has loaded or after, so both changes apply it.
    .onChange(of: items.map(\.id), initial: true) {
      tab.applyPendingFirstSelection(inColumn: index, items: items)
    }
    .onChange(of: tab.pendingFirstSelectionColumn) {
      tab.applyPendingFirstSelection(inColumn: index, items: items)
    }
    .task(id: ListingKey(folder: folder, includesHiddenItems: showsHiddenFiles)) {
      guard rootListing == nil, let folder else {
        return
      }
      await ownListing.observe(folder, includingHiddenItems: showsHiddenFiles)
    }
  }

  private var items: [FileItem] {
    guard rootListing == nil else {
      return tab.visibleItems
    }
    return ItemSorting(order: tab.viewSettings.sortOrder).sorted(ownListing.items)
  }

  private func selection(for items: [FileItem]) -> Binding<Set<FileItem.ID>> {
    Binding {
      tab.columnSelections[index] ?? []
    } set: { selection in
      tab.selectInColumn(index, selection: selection, items: items)
    }
  }

  private func handle(_ press: KeyPress, items: [FileItem]) -> KeyPress.Result {
    guard tab.renamingItemID == nil else {
      return .ignored
    }
    switch press.key {
    case .rightArrow:
      let selected = tab.columnSelections[index] ?? []
      guard selected.count == 1, let item = items.first(where: { selected.contains($0.id) }), tab.opensAsFolder(item) else {
        return .ignored
      }
      tab.requestFirstSelection(inColumn: index + 1)
      focusedColumn.wrappedValue = index + 1
      return .handled
    case .leftArrow where index > 0:
      tab.leaveColumn(index)
      focusedColumn.wrappedValue = index - 1
      return .handled
    default:
      return FileKeyHandler(tab: tab, returnKeyAction: returnKeyAction, alwaysShowsExtensions: alwaysShowsExtensions, locale: locale)
        .handle(press, items: items)
    }
  }
}

/// Identifies what a column loads; a change restarts loading.
nonisolated private struct ListingKey: Hashable {
  let folder: URL?
  let includesHiddenItems: Bool
}

/// One row of a column, with a chevron for folders.
private struct ColumnRow: View {

  let item: FileItem
  let name: String
  let opensAsFolder: Bool
  let isRenaming: Bool
  let tab: TabModel
  let sizeUnits: SizeUnits
  let locale: Locale

  var body: some View {
    HStack(spacing: 6) {
      FileIcon(url: item.url)
        .overlay(alignment: .bottomLeading) {
          if item.isAliasFile || item.isSymbolicLink {
            LinkBadge()
          }
        }
      if isRenaming {
        RenameField(item: item, tab: tab)
      } else {
        Text(name)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      Spacer(minLength: 0)
      if opensAsFolder {
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .opacity(item.isHidden || FileClipboard.shared.isCut(item.url) ? 0.5 : 1)
    .fileItemAccessibility(item: item, tab: tab, name: name, sizeUnits: sizeUnits, locale: locale, isRenaming: isRenaming)
  }
}

/// The last column for a single selected file: its preview, name, kind, size and modification date.
private struct PreviewColumn: View {

  let item: FileItem

  @AppStorage(SettingsKeys.sizeUnits.name) private var sizeUnits = SettingsKeys.sizeUnits.defaultValue
  @Environment(\.locale) private var locale

  var body: some View {
    let formatter = ByteSizeFormatter(units: sizeUnits, locale: locale)
    VStack(spacing: 12) {
      QuickLookPreview(url: item.url)
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(.rect(cornerRadius: 6))
      Text(item.localizedName)
        .font(.headline)
        .multilineTextAlignment(.center)
        .lineLimit(3)
      Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
        GridRow {
          Text("Kind")
            .foregroundStyle(.secondary)
          Text(item.kind)
        }
        if let size = item.size {
          GridRow {
            Text("Size")
              .foregroundStyle(.secondary)
            Text(formatter.string(for: size))
          }
        }
        if let modificationDate = item.modificationDate {
          GridRow {
            Text("Modified")
              .foregroundStyle(.secondary)
            Text(modificationDate.formatted(date: .abbreviated, time: .shortened))
          }
        }
      }
      .font(.callout)
      Spacer(minLength: 0)
    }
    .padding(12)
  }
}

#Preview("English") {
  ColumnFileView(tab: .preview(in: .english))
    .frame(width: 800, height: 360)
}

#Preview("German") {
  ColumnFileView(tab: .preview(in: .german))
    .frame(width: 800, height: 360)
    .environment(\.locale, Locale(identifier: "de"))
}

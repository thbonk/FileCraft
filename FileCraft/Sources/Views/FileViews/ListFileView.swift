/*
 * ListFileView.swift
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

import AppKit
import SwiftUI

/// The list view: a table with a hierarchical Name column, optional columns, header sorting, sections
/// when grouped, keyboard navigation, type-to-select and inline renaming.
internal struct ListFileView: View {

  // MARK: - Properties

  @Bindable internal var tab: TabModel

  @AppStorage(SettingsKeys.alwaysShowsFileExtensions.name)
  private var alwaysShowsExtensions = SettingsKeys.alwaysShowsFileExtensions.defaultValue
  @AppStorage(SettingsKeys.returnKeyAction.name) private var returnKeyAction = SettingsKeys.returnKeyAction.defaultValue
  @AppStorage(SettingsKeys.sizeUnits.name) private var sizeUnits = SettingsKeys.sizeUnits.defaultValue
  @Environment(\.locale) private var locale
  @FocusState private var isFocused: Bool

  // MARK: - Body

  internal var body: some View {
    let rows = tab.outlineRows
    table
      .font(tab.viewSettings.textSize.font)
      .contextMenu(forSelectionType: FileItem.ID.self) { identifiers in
        if identifiers.isEmpty {
          FileBackgroundContextMenu(tab: tab, folder: nil)
        } else {
          FileItemContextMenu(items: rows.filter { identifiers.contains($0.id) }.map(\.item), tab: tab)
        }
      } primaryAction: { identifiers in
        tab.open(rows.filter { identifiers.contains($0.id) }.map(\.item))
      }
      .emptyAreaContextMenu {
        FileBackgroundContextMenu(tab: tab, folder: nil)
      }
      .onKeyPress(phases: .down) { press in
        handle(press, rows: rows)
      }
      .focused($isFocused)
      .onChange(of: tab.focusRequest) {
        isFocused = true
      }
      .onChange(of: isFocused) { _, isFocused in
        if isFocused {
          tab.didReceiveFocus()
        }
      }
      .task(id: ChildrenKey(expandedFolders: tab.expandedFolders, generation: tab.refreshGeneration)) {
        await tab.loadExpandedChildren()
      }
      .task(id: LastOpenedKey(folder: tab.folderURL, isNeeded: needsLastOpenedDates, generation: tab.refreshGeneration)) {
        guard needsLastOpenedDates else {
          return
        }
        await tab.loadLastOpenedDates()
      }
  }

  @ViewBuilder
  private var table: some View {
    if tab.viewSettings.grouping == .none {
      Table(tab.outlineRows, selection: $tab.selection, sortOrder: sortOrder, columnCustomization: $tab.columnCustomization) {
        nameColumn
        locationColumn
        dateColumns
        attributeColumns
        infoColumns
      }
    } else {
      Table(of: FileRow.self, selection: $tab.selection, sortOrder: sortOrder, columnCustomization: $tab.columnCustomization) {
        nameColumn
        locationColumn
        dateColumns
        attributeColumns
        infoColumns
      } rows: {
        ForEach(tab.outlineSections) { section in
          Section {
            ForEach(section.rows) { row in
              TableRow(row)
                .draggable(DraggedFile(id: row.item.id, url: row.item.url))
            }
          } header: {
            Text(GroupTitles.title(for: section.group, locale: locale) ?? "")
          }
        }
      }
    }
  }

  // MARK: - Columns

  private var cells: CellFormatting {
    CellFormatting(
      usesRelativeDates: tab.viewSettings.usesRelativeDates,
      sizeFormatter: ByteSizeFormatter(units: sizeUnits, locale: locale),
      locale: locale)
  }

  @TableColumnBuilder<FileRow, KeyPathComparator<FileRow>>
  private var nameColumn: some TableColumnContent<FileRow, KeyPathComparator<FileRow>> {
    TableColumn("Name", value: \FileRow.sortName) { row in
      NameCell(
        row: row, tab: tab, name: ItemPresentation.displayName(of: row.item, alwaysShowsExtensions: alwaysShowsExtensions),
        sizeUnits: sizeUnits, locale: locale)
        .fileDropTarget(tab.opensAsFolder(row.item) ? row.item.url : nil, tab: tab, springsOpen: true)
    }
    .width(min: 160, ideal: 280)
    .customizationID("name")
    .disabledCustomizationBehavior(.visibility)
  }

  /// The folder containing each result, shown only for search results.
  @TableColumnBuilder<FileRow, KeyPathComparator<FileRow>>
  private var locationColumn: some TableColumnContent<FileRow, KeyPathComparator<FileRow>> {
    if tab.location.searchQuery != nil {
      TableColumn("Location", value: \FileRow.sortLocation) { row in
        let path = Self.locationPath(of: row.item)
        Text(verbatim: path)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(Text(verbatim: path))
      }
      .width(min: 120, ideal: 240)
      .customizationID("location")
    }
  }

  /// The path of the folder containing `item`, with the home folder abbreviated as "~".
  private static func locationPath(of item: FileItem) -> String {
    let folder = item.url.deletingLastPathComponent().path(percentEncoded: false)
    return (folder as NSString).abbreviatingWithTildeInPath
  }

  @TableColumnBuilder<FileRow, KeyPathComparator<FileRow>>
  private var dateColumns: some TableColumnContent<FileRow, KeyPathComparator<FileRow>> {
    let cells = cells
    TableColumn("Date Modified", value: \FileRow.sortDateModified) { row in
      cells.date(row.item.modificationDate)
    }
    .width(min: 100, ideal: 150)
    .customizationID(ListColumn.dateModified.customizationID)
    TableColumn("Date Created", value: \FileRow.sortDateCreated) { row in
      cells.date(row.item.creationDate)
    }
    .width(min: 100, ideal: 150)
    .customizationID(ListColumn.dateCreated.customizationID)
    .defaultVisibility(.hidden)
    TableColumn("Date Last Opened", value: \FileRow.sortDateLastOpened) { row in
      cells.date(row.item.lastOpenedDate)
    }
    .width(min: 100, ideal: 150)
    .customizationID(ListColumn.dateLastOpened.customizationID)
    .defaultVisibility(.hidden)
    TableColumn("Date Added", value: \FileRow.sortDateAdded) { row in
      cells.date(row.item.addedDate)
    }
    .width(min: 100, ideal: 150)
    .customizationID(ListColumn.dateAdded.customizationID)
    .defaultVisibility(.hidden)
  }

  @TableColumnBuilder<FileRow, KeyPathComparator<FileRow>>
  private var attributeColumns: some TableColumnContent<FileRow, KeyPathComparator<FileRow>> {
    let cells = cells
    let calculatesFolderSizes = tab.viewSettings.calculatesFolderSizes
    TableColumn("Size", value: \FileRow.sortSize) { row in
      SizeCell(item: row.item, calculatesFolderSizes: calculatesFolderSizes, formatter: cells.sizeFormatter)
    }
    .width(min: 60, ideal: 80)
    .customizationID(ListColumn.size.customizationID)
    TableColumn("Kind", value: \FileRow.sortKind) { row in
      Text(row.item.kind)
    }
    .width(min: 80, ideal: 140)
    .customizationID(ListColumn.kind.customizationID)
    TableColumn("Extension", value: \FileRow.sortExtension) { row in
      Text(row.item.pathExtension)
    }
    .width(min: 50, ideal: 70)
    .customizationID(ListColumn.pathExtension.customizationID)
    .defaultVisibility(.hidden)
    TableColumn("Tags", value: \FileRow.sortTags) { row in
      TagDots(tagNames: row.item.tagNames)
    }
    .width(min: 40, ideal: 60)
    .customizationID(ListColumn.tags.customizationID)
    .defaultVisibility(.hidden)
  }

  @TableColumnBuilder<FileRow, KeyPathComparator<FileRow>>
  private var infoColumns: some TableColumnContent<FileRow, KeyPathComparator<FileRow>> {
    TableColumn("Version", value: \FileRow.sortVersion) { row in
      VersionCell(item: row.item)
    }
    .width(min: 50, ideal: 70)
    .customizationID(ListColumn.version.customizationID)
    .defaultVisibility(.hidden)
    TableColumn("Permissions", value: \FileRow.sortPermissions) { row in
      Text(row.item.permissions.map(ItemPresentation.symbolicPermissions) ?? "--")
        .monospaced()
    }
    .width(min: 80, ideal: 90)
    .customizationID(ListColumn.permissions.customizationID)
    .defaultVisibility(.hidden)
    TableColumn("Owner", value: \FileRow.sortOwner) { row in
      Text(row.item.ownerID.map(AccountNames.userName(for:)) ?? "--")
    }
    .width(min: 50, ideal: 80)
    .customizationID(ListColumn.owner.customizationID)
    .defaultVisibility(.hidden)
    TableColumn("Group", value: \FileRow.sortGroup) { row in
      Text(row.item.groupID.map(AccountNames.groupName(for:)) ?? "--")
    }
    .width(min: 50, ideal: 80)
    .customizationID(ListColumn.group.customizationID)
    .defaultVisibility(.hidden)
  }

  // MARK: - Sorting

  /// Maps the sort indicator of the clicked column header to the tab's sort order; FileCraft sorts itself.
  private var sortOrder: Binding<[KeyPathComparator<FileRow>]> {
    Binding {
      [Self.comparator(for: tab.viewSettings.sortOrder.key, ascending: tab.viewSettings.sortOrder.isAscending)]
    } set: { comparators in
      guard let comparator = comparators.first, let key = Self.sortKey(for: comparator.keyPath) else {
        return
      }
      tab.viewSettings.sortOrder.key = key
      tab.viewSettings.sortOrder.isAscending = comparator.order == .forward
    }
  }

  private static func comparator(for key: SortKey, ascending: Bool) -> KeyPathComparator<FileRow> {
    let order: SortOrder = ascending ? .forward : .reverse
    return switch key {
    case .name:
      KeyPathComparator(\FileRow.sortName, order: order)
    case .kind:
      KeyPathComparator(\FileRow.sortKind, order: order)
    case .size:
      KeyPathComparator(\FileRow.sortSize, order: order)
    case .dateModified:
      KeyPathComparator(\FileRow.sortDateModified, order: order)
    case .dateCreated:
      KeyPathComparator(\FileRow.sortDateCreated, order: order)
    case .dateLastOpened:
      KeyPathComparator(\FileRow.sortDateLastOpened, order: order)
    case .dateAdded:
      KeyPathComparator(\FileRow.sortDateAdded, order: order)
    case .pathExtension:
      KeyPathComparator(\FileRow.sortExtension, order: order)
    case .tags:
      KeyPathComparator(\FileRow.sortTags, order: order)
    }
  }

  private static func sortKey(for keyPath: PartialKeyPath<FileRow>) -> SortKey? {
    SortKey.allCases.first { comparator(for: $0, ascending: true).keyPath == keyPath }
  }

  private var needsLastOpenedDates: Bool {
    tab.viewSettings.sortOrder.key == .dateLastOpened || ListColumn.dateLastOpened.isVisible(in: tab.columnCustomization)
  }

  // MARK: - Keyboard

  /// → and ← expand and collapse folders; everything else is shared with the other file views.
  private func handle(_ press: KeyPress, rows: [FileRow]) -> KeyPress.Result {
    guard tab.renamingItemID == nil else {
      return .ignored
    }
    switch press.key {
    case .rightArrow where tab.selectedItems.contains(where: tab.opensAsFolder):
      tab.setSelectionExpanded(true, recursively: press.modifiers.contains(.option))
      return .handled
    case .leftArrow where tab.selectedItems.contains(where: tab.opensAsFolder):
      tab.setSelectionExpanded(false, recursively: press.modifiers.contains(.option))
      return .handled
    default:
      let keys = FileKeyHandler(tab: tab, returnKeyAction: returnKeyAction, alwaysShowsExtensions: alwaysShowsExtensions, locale: locale)
      return keys.handle(press, items: rows.map(\.item))
    }
  }
}

// MARK: - Task Keys

nonisolated private struct ChildrenKey: Hashable {
  let expandedFolders: Set<FileItem.ID>
  let generation: Int
}

nonisolated private struct LastOpenedKey: Hashable {
  let folder: URL?
  let isNeeded: Bool
  let generation: Int
}

// MARK: - Cells

/// The formatting settings shared by all cells of one table update.
private struct CellFormatting {

  let usesRelativeDates: Bool
  let sizeFormatter: ByteSizeFormatter
  let locale: Locale

  func date(_ date: Date?) -> some View {
    Text(date.map { ItemPresentation.dateString($0, relative: usesRelativeDates, locale: locale) } ?? "--")
      .monospacedDigit()
      .foregroundStyle(date == nil ? .secondary : .primary)
  }
}

/// The Name column: indentation, disclosure control, icon with link badge, and the name or its editor.
private struct NameCell: View {

  let row: FileRow
  let tab: TabModel
  let name: String
  let sizeUnits: SizeUnits
  let locale: Locale

  var body: some View {
    HStack(spacing: 4) {
      Color.clear
        .frame(width: CGFloat(row.depth) * 16, height: 1)
      disclosure
      if tab.renamingItemID == row.id {
        FileIcon(url: row.item.url)
          .overlay(alignment: .bottomLeading) {
            if row.item.isAliasFile || row.item.isSymbolicLink {
              LinkBadge()
            }
          }
        RenameField(item: row.item, tab: tab)
      } else {
        Group {
          FileIcon(url: row.item.url)
            .overlay(alignment: .bottomLeading) {
              if row.item.isAliasFile || row.item.isSymbolicLink {
                LinkBadge()
              }
            }
          Text(name)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        .fileItemAccessibility(item: row.item, tab: tab, name: name, sizeUnits: sizeUnits, locale: locale)
      }
    }
    .opacity(row.item.isHidden || FileClipboard.shared.isCut(row.item.url) ? 0.5 : 1)
  }

  @ViewBuilder
  private var disclosure: some View {
    if row.isExpandable {
      Button {
        tab.setExpanded(row.isExpanded == false, for: row.item, recursively: NSEvent.modifierFlags.contains(.option))
      } label: {
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .rotationEffect(.degrees(row.isExpanded ? 90 : 0))
          .frame(width: 12, height: 12)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(row.isExpanded ? Text("Collapse Folder") : Text("Expand Folder"))
    } else {
      Color.clear
        .frame(width: 12, height: 12)
    }
  }
}

/// The size of a file, or of a folder when folder sizes are calculated.
private struct SizeCell: View {

  let item: FileItem
  let calculatesFolderSizes: Bool
  let formatter: ByteSizeFormatter

  @State private var folderSize: FolderSize?

  var body: some View {
    Group {
      if let size = item.size {
        Text(formatter.string(for: size))
      } else if let folderSize {
        Text(formatter.string(for: folderSize.logicalBytes))
      } else if item.isDirectory && calculatesFolderSizes {
        ProgressView()
          .controlSize(.mini)
      } else {
        Text(verbatim: "--")
          .foregroundStyle(.secondary)
      }
    }
    .monospacedDigit()
    .task(id: calculatesFolderSizes && item.isDirectory ? item.id : nil) {
      guard calculatesFolderSizes, item.isDirectory else {
        folderSize = nil
        return
      }
      folderSize = try? await FolderSizeService.shared.size(of: item.url)
    }
  }
}

/// The version of an app or other bundle, loaded when the cell appears.
private struct VersionCell: View {

  let item: FileItem

  @State private var version: String?

  var body: some View {
    Text(version ?? "--")
      .foregroundStyle(version == nil ? .secondary : .primary)
      .task(id: item.id) {
        guard item.isPackage else {
          return
        }
        version = await SpotlightAttributes.bundleVersion(of: item.url)
      }
  }
}

#Preview("English") {
  ListFileView(tab: .preview(in: .english))
    .frame(width: 720, height: 320)
}

#Preview("Grouped, German") {
  let tab = TabModel.preview(in: .german)
  tab.viewSettings.grouping = .kind

  return ListFileView(tab: tab)
    .frame(width: 720, height: 360)
    .environment(\.locale, Locale(identifier: "de"))
}

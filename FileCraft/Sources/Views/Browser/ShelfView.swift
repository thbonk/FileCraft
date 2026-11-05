/*
 * ShelfView.swift
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

import AppKit
import QuickLook
import SwiftUI

/// The shelf below the panes of a browser window (shelf spec): a scrollable row of references to files and
/// folders that all windows share. Items are added by dropping them here and leave by Remove from Shelf, Clear
/// Shelf or, with the setting on, by dragging them out.
internal struct ShelfView: View {

  // MARK: - Properties

  internal let shelf: ShelfStore
  internal let window: BrowserWindowModel
  internal var operations: OperationQueueModel = .shared

  @AppStorage(SettingsKeys.removesShelfItemsAfterDrag.name)
  private var removesItemsAfterDrag = SettingsKeys.removesShelfItemsAfterDrag.defaultValue
  @Environment(\.appearsActive) private var appearsActive
  @State private var selection = SelectionModel()
  @State private var quickLookURL: URL?
  @State private var quickLookURLs: [URL] = []
  @State private var isTargeted = false
  @FocusState private var isFocused: Bool

  // MARK: - Body

  internal var body: some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background {
        if isTargeted {
          Rectangle()
            .fill(Color.accentColor.opacity(0.15))
        }
      }
      .contentShape(Rectangle())
      .onTapGesture {
        selection.deselectAll()
      }
      .dropDestination(for: URL.self) { urls, _ in
        isTargeted = false
        Task { await shelf.add(urls) }
      }
      .dropConfiguration { session in
        DropConfiguration(operation: dropOperation(for: session))
      }
      .onDropSessionUpdated { session in
        switch session.phase {
        case .entering:
          isTargeted = true
        case .exiting, .ended, .dataTransferCompleted:
          isTargeted = false
        case .active:
          break
        @unknown default:
          break
        }
      }
      .quickLookPreview($quickLookURL, in: quickLookURLs)
      // Items renamed, moved or deleted meanwhile get their new path or appear dimmed: when the shelf appears,
      // when the window becomes active and when an operation ends.
      .task(id: RefreshTrigger(isActive: appearsActive, activeOperations: operations.activeOperations.count)) {
        await shelf.refresh()
      }
  }

  // MARK: - Content

  @ViewBuilder private var content: some View {
    if shelf.items.isEmpty {
      ContentUnavailableView {
        Label("Shelf", systemImage: "tray")
      } description: {
        Text("Drag items here to collect them.")
      }
    } else {
      ScrollView(.horizontal) {
        LazyHStack(spacing: 4) {
          ForEach(shelf.items) { item in
            cell(item)
          }
        }
        .padding(8)
        .dragContainer(for: DraggedFile.self) { ids in
          draggedFiles(ids)
        }
        .dragContainerSelection(Array(selection.selection))
        .onDragSessionUpdated { session in
          dragSessionUpdated(session)
        }
      }
      .focusable()
      .focused($isFocused)
      .focusEffectDisabled()
      .onKeyPress(.space) {
        toggleQuickLook()
        return .handled
      }
      .onDeleteCommand {
        shelf.remove(Set(selectedItems.map(\.id)))
        selection.deselectAll()
      }
    }
  }

  private func cell(_ item: ShelfItem) -> some View {
    ShelfCell(
      item: item,
      isSelected: selection.selection.contains(Self.dragID(of: item)),
      isAvailable: isAvailable(item))
    .onTapGesture {
      click(item)
    }
    .contextMenu {
      contextMenu(for: targets(of: item))
    }
    .draggable(containerItemID: Self.dragID(of: item))
  }

  // MARK: - Context Menu

  @ViewBuilder
  private func contextMenu(for items: [ShelfItem]) -> some View {
    let available = items.filter(isAvailable)
    let currentFolder = window.activeTab.folderURL
    Button("Quick Look") {
      quickLook(available)
    }
    .disabled(available.isEmpty)
    Button("Reveal in Pane") {
      if let item = available.first {
        window.activeTab.reveal(item.url)
      }
    }
    .disabled(available.count != 1)
    Divider()
    Button("Copy Items to Current Folder") {
      transfer(available, kind: .copy)
    }
    .disabled(available.isEmpty || currentFolder == nil)
    Button("Move Items to Current Folder") {
      transfer(available, kind: .move)
    }
    .disabled(available.isEmpty || currentFolder == nil)
    Divider()
    Button("Remove from Shelf") {
      shelf.remove(Set(items.map(\.id)))
      selection.deselectAll()
    }
    Button("Clear Shelf") {
      shelf.clear()
      selection.deselectAll()
    }
  }

  // MARK: - Selection

  private var selectedItems: [ShelfItem] {
    shelf.items.filter { selection.selection.contains(Self.dragID(of: $0)) }
  }

  /// The items a context menu or drag acts on: the selection when it contains `item`, otherwise `item` alone.
  private func targets(of item: ShelfItem) -> [ShelfItem] {
    selection.selection.contains(Self.dragID(of: item)) ? selectedItems : [item]
  }

  private func click(_ item: ShelfItem) {
    isFocused = true
    let id = Self.dragID(of: item)
    let modifiers = NSEvent.modifierFlags
    if modifiers.contains(.command) {
      selection.toggle(id)
    } else if modifiers.contains(.shift) {
      selection.extend(to: id, in: shelf.items.map(Self.dragID))
    } else {
      selection.select(id)
    }
    if quickLookURL != nil {
      quickLook(selectedItems.filter(isAvailable))
    }
  }

  private func isAvailable(_ item: ShelfItem) -> Bool {
    shelf.unavailableIDs.contains(item.id) == false
  }

  // MARK: - Actions

  private func quickLook(_ items: [ShelfItem]) {
    quickLookURLs = items.map(\.url)
    quickLookURL = quickLookURLs.first
  }

  private func toggleQuickLook() {
    if quickLookURL == nil {
      quickLook(selectedItems.filter(isAvailable))
    } else {
      quickLookURL = nil
    }
  }

  private func transfer(_ items: [ShelfItem], kind: FileOperationKind) {
    let urls = items.map(\.url)
    let commands = window.fileCommands
    let shelf = shelf
    Task {
      await commands.transferShelfItems(urls, kind: kind, shelf: shelf)
    }
  }

  // MARK: - Dragging

  /// The ID of an item in drags, its path, as for the items of the file views; drop targets read it to choose
  /// between moving and copying.
  private static func dragID(of item: ShelfItem) -> FileItem.ID {
    item.reference.lastKnownPath
  }

  /// The available items among the dragged `ids`; unavailable items cannot be dragged.
  private func draggedFiles(_ ids: [FileItem.ID]) -> [DraggedFile] {
    let available = Dictionary(
      shelf.items.filter(isAvailable).map { (Self.dragID(of: $0), $0.url) },
      uniquingKeysWith: { first, _ in first })
    return ids.compactMap { id in available[id].map { DraggedFile(id: id, url: $0) } }
  }

  /// With "Remove items after dragging them out" on, items that another view or application accepted leave the
  /// shelf.
  private func dragSessionUpdated(_ session: DragSession) {
    guard case .ended(let operation) = session.phase, removesItemsAfterDrag else {
      return
    }
    switch operation {
    case .copy, .move, .alias, .delete:
      shelf.remove(itemsAt: session.draggedItemIDs(for: FileItem.ID.self).map { URL(filePath: $0) })
      selection.deselectAll()
    case .cancel, .forbidden:
      break
    @unknown default:
      break
    }
  }

  /// Adding what the shelf already holds does nothing, which the cursor shows; this also keeps items dragged
  /// within the shelf from counting as dragged out.
  private func dropOperation(for session: DropSession) -> DropOperation {
    let paths = session.localSession?.draggedItemIDs(for: FileItem.ID.self) ?? []
    guard paths.isEmpty == false else {
      return .copy
    }
    let shelfPaths = Set(shelf.items.map(\.url.comparablePath))
    let isOnShelf = paths.allSatisfy { shelfPaths.contains(URL(filePath: $0).comparablePath) }
    return isOnShelf ? .forbidden : .copy
  }
}

// MARK: - Refresh Trigger

/// What makes the shelf resolve its items again.
private struct RefreshTrigger: Hashable {
  let isActive: Bool
  let activeOperations: Int
}

// MARK: - Cell

/// One shelf item: its icon and name, dimmed when the item no longer exists or cannot be reached, with the full
/// path in the tooltip.
private struct ShelfCell: View {

  let item: ShelfItem
  let isSelected: Bool
  let isAvailable: Bool

  var body: some View {
    VStack(spacing: 4) {
      FileIcon(url: item.url, size: 48)
      Text(verbatim: item.name)
        .font(.caption)
        .lineLimit(2)
        .truncationMode(.middle)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 4)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background {
          if isSelected {
            RoundedRectangle(cornerRadius: 4)
              .fill(Color.accentColor)
          }
        }
    }
    .frame(width: 88)
    .padding(4)
    .background {
      if isSelected {
        RoundedRectangle(cornerRadius: 6)
          .fill(Color.secondary.opacity(0.2))
      }
    }
    .opacity(isAvailable ? 1 : 0.4)
    .contentShape(Rectangle())
    .help(Text(verbatim: item.reference.lastKnownPath))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: item.name))
    .accessibilityValue(isAvailable ? "" : String(localized: "Unavailable"))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

// MARK: - Previews

#Preview("English") {
  let folder = PreviewFixtures.homeFolder
  let missing = folder.appending(path: "Old Draft.pages")
  ShelfView(
    shelf: ShelfStore(
      previewItems: [folder.appending(path: "Report.pdf"), folder.appending(path: "Documents"), missing],
      unavailable: [missing]),
    window: BrowserWindowModel.preview(in: .english))
  .frame(width: 520, height: 130)
}

#Preview("German, Empty") {
  ShelfView(shelf: ShelfStore(previewItems: []), window: BrowserWindowModel.preview(in: .german))
    .frame(width: 520, height: 130)
    .environment(\.locale, Locale(identifier: "de"))
}

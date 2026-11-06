/*
 * IconFileView.swift
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

import AppKit
import SwiftUI

/// The icon view: a grid that reflows with the pane width, with click, ⇧-click, ⌘-click and rubber-band
/// selection, arrow-key navigation and sections when grouped.
internal struct IconFileView: View {

  // MARK: - Properties

  internal let tab: TabModel

  @AppStorage(SettingsKeys.alwaysShowsFileExtensions.name)
  private var alwaysShowsExtensions = SettingsKeys.alwaysShowsFileExtensions.defaultValue
  @AppStorage(SettingsKeys.returnKeyAction.name) private var returnKeyAction = SettingsKeys.returnKeyAction.defaultValue
  @AppStorage(SettingsKeys.sizeUnits.name) private var sizeUnits = SettingsKeys.sizeUnits.defaultValue
  @Environment(\.locale) private var locale
  @State private var gridWidth: CGFloat = 0
  @State private var viewportHeight: CGFloat = 0
  /// The frames of the cells laid out so far, in the grid's coordinate space, for rubber-band selection.
  @State private var cellFrames: [FileItem.ID: CGRect] = [:]
  @State private var rubberBand: CGRect?
  @State private var selectionBeforeRubberBand: Set<FileItem.ID> = []
  /// The item arrow keys move from; with ⇧ it differs from the selection anchor.
  @State private var cursorID: FileItem.ID?
  @FocusState private var isFocused: Bool

  private static let spacing: CGFloat = 12
  nonisolated private static let coordinateSpaceName = "iconGrid"

  // MARK: - Body

  internal var body: some View {
    let settings = tab.viewSettings
    let sections = tab.itemSections
    let items = sections.flatMap(\.items)
    let cellWidth = Self.cellWidth(iconSize: settings.iconSize, labelPosition: settings.labelPosition)
    ScrollViewReader { proxy in
      ScrollView {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: cellWidth, maximum: cellWidth), spacing: Self.spacing, alignment: .top)],
          alignment: .leading,
          spacing: Self.spacing,
          pinnedViews: [.sectionHeaders]
        ) {
          ForEach(sections, id: \.group) { section in
            Section {
              ForEach(section.items) { item in
                cell(for: item, settings: settings, width: cellWidth, order: items)
              }
            } header: {
              if let title = GroupTitles.title(for: section.group, locale: locale) {
                SectionHeader(title: title)
              }
            }
          }
        }
        .onGeometryChange(for: CGFloat.self) { geometry in
          geometry.size.width
        } action: { width in
          gridWidth = width
        }
        .padding(Self.spacing)
        .frame(maxWidth: .infinity, minHeight: viewportHeight, alignment: .topLeading)
        .background {
          Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
              isFocused = true
              if NSEvent.modifierFlags.isDisjoint(with: [.command, .shift]) {
                tab.deselectAll()
              }
            }
            .gesture(rubberBandGesture(over: Set(items.map(\.id))))
            .contextMenu {
              FileBackgroundContextMenu(tab: tab, folder: nil)
            }
        }
        .overlay(alignment: .topLeading) {
          rubberBandOverlay
        }
        .fileDragContainer(tab: tab, items: items)
        .coordinateSpace(.named(Self.coordinateSpaceName))
      }
      .onGeometryChange(for: CGFloat.self) { geometry in
        geometry.size.height
      } action: { height in
        viewportHeight = height
      }
      .focusable()
      .focused($isFocused)
      .onChange(of: tab.focusRequest) {
        isFocused = true
      }
      .onChange(of: isFocused) { _, isFocused in
        if isFocused {
          tab.didReceiveFocus()
        }
      }
      .focusEffectDisabled()
      .onKeyPress(phases: [.down, .repeat]) { press in
        if let direction = Self.direction(for: press.key), press.modifiers.isDisjoint(with: [.command, .option, .control]) {
          move(direction, extending: press.modifiers.contains(.shift), in: items, cellWidth: cellWidth, proxy: proxy)
          return .handled
        }
        guard press.phase == .down else {
          return .ignored
        }
        return FileKeyHandler(tab: tab, returnKeyAction: returnKeyAction, alwaysShowsExtensions: alwaysShowsExtensions, locale: locale)
          .handle(press, items: items)
      }
      .onChange(of: tab.listing.items) {
        let ids = Set(tab.listing.items.map(\.id))
        cellFrames = cellFrames.filter { ids.contains($0.key) }
      }
    }
  }

  // MARK: - Cells

  private func cell(for item: FileItem, settings: ViewSettings, width: CGFloat, order: [FileItem]) -> some View {
    IconCell(
      item: item,
      name: ItemPresentation.displayName(of: item, alwaysShowsExtensions: alwaysShowsExtensions),
      settings: settings,
      width: width,
      isSelected: tab.selection.contains(item.id),
      isRenaming: tab.renamingItemID == item.id,
      tab: tab,
      sizeUnits: sizeUnits,
      locale: locale)
    .id(item.id)
    .onGeometryChange(for: CGRect.self) { geometry in
      geometry.frame(in: .named(Self.coordinateSpaceName))
    } action: { frame in
      cellFrames[item.id] = frame
    }
    .onTapGesture(coordinateSpace: .local) { location in
      click(item, order: order, isOnName: Self.isOnName(location, settings: settings))
    }
    .simultaneousGesture(
      TapGesture(count: 2).onEnded {
        tab.open(item)
      })
    .contextMenu {
      FileItemContextMenu(items: tab.selection.contains(item.id) ? tab.selectedItems : [item], tab: tab)
    }
    .draggable(containerItemID: item.id)
    .fileDropTarget(tab.opensAsFolder(item) ? item.url : nil, tab: tab, springsOpen: true)
  }

  private static func cellWidth(iconSize: Double, labelPosition: LabelPosition) -> CGFloat {
    switch labelPosition {
    case .bottom:
      max(CGFloat(iconSize) + 32, 96)
    case .right:
      CGFloat(iconSize) + 180
    }
  }

  // MARK: - Selection

  /// Selects `item` as a click does; a click on the name of the item that was already the only selected one
  /// renames it after a pause, as in Finder.
  private func click(_ item: FileItem, order: [FileItem], isOnName: Bool = false) {
    isFocused = true
    cursorID = item.id
    let wasOnlySelection = tab.selection == [item.id]
    let modifiers = NSEvent.modifierFlags
    if modifiers.contains(.command) {
      tab.toggleSelection(item.id)
    } else if modifiers.contains(.shift) {
      tab.extendSelection(to: item.id, in: order.map(\.id))
    } else {
      tab.select(item.id)
      if wasOnlySelection, isOnName {
        tab.scheduleRename(of: item)
      }
    }
  }

  /// Whether `location`, in a cell's coordinates, is on the item's name rather than on its icon.
  private static func isOnName(_ location: CGPoint, settings: ViewSettings) -> Bool {
    // The icon and its padding come first, below or beside them the name.
    let iconExtent = CGFloat(settings.iconSize) + 8
    return settings.labelPosition == .bottom ? location.y > iconExtent : location.x > iconExtent
  }

  /// Selects the items whose cells intersect the dragged rectangle; with ⌘ or ⇧ in addition to the selection.
  private func rubberBandGesture(over ids: Set<FileItem.ID>) -> some Gesture {
    DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.coordinateSpaceName))
      .onChanged { value in
        if rubberBand == nil {
          let modifiers = NSEvent.modifierFlags
          selectionBeforeRubberBand = modifiers.isDisjoint(with: [.command, .shift]) ? [] : tab.selection
          isFocused = true
        }
        let rect = CGRect(
          x: min(value.startLocation.x, value.location.x),
          y: min(value.startLocation.y, value.location.y),
          width: abs(value.location.x - value.startLocation.x),
          height: abs(value.location.y - value.startLocation.y))
        rubberBand = rect
        let hits = cellFrames.compactMap { ids.contains($0.key) && rect.intersects($0.value) ? $0.key : nil }
        tab.selection = selectionBeforeRubberBand.union(hits)
      }
      .onEnded { _ in
        rubberBand = nil
      }
  }

  @ViewBuilder
  private var rubberBandOverlay: some View {
    if let rubberBand {
      Rectangle()
        .fill(Color.accentColor.opacity(0.15))
        .overlay {
          Rectangle().strokeBorder(Color.accentColor, lineWidth: 1)
        }
        .frame(width: rubberBand.width, height: rubberBand.height)
        .offset(x: rubberBand.minX, y: rubberBand.minY)
        .allowsHitTesting(false)
    }
  }

  // MARK: - Keyboard

  private static func direction(for key: KeyEquivalent) -> GridNavigation.Direction? {
    switch key {
    case .leftArrow:
      .left
    case .rightArrow:
      .right
    case .upArrow:
      .up
    case .downArrow:
      .down
    default:
      nil
    }
  }

  private func move(
    _ direction: GridNavigation.Direction,
    extending: Bool,
    in items: [FileItem],
    cellWidth: CGFloat,
    proxy: ScrollViewProxy
  ) {
    let ids = items.map(\.id)
    guard ids.isEmpty == false, tab.renamingItemID == nil else {
      return
    }
    let columns = GridNavigation.columnCount(for: gridWidth, cellWidth: cellWidth, spacing: Self.spacing)
    let currentID = cursorID.flatMap { tab.selection.contains($0) ? $0 : nil } ?? ids.first { tab.selection.contains($0) }
    let targetIndex: Int
    if let currentID, let index = ids.firstIndex(of: currentID) {
      guard let next = GridNavigation.index(from: index, moving: direction, columns: columns, count: ids.count) else {
        return
      }
      targetIndex = next
    } else {
      targetIndex = 0
    }
    let targetID = ids[targetIndex]
    if extending {
      tab.extendSelection(to: targetID, in: ids)
    } else {
      tab.select(targetID)
    }
    cursorID = targetID
    proxy.scrollTo(targetID)
  }
}

/// One item of icon view: icon or thumbnail, name or its editor, and optional item info.
private struct IconCell: View {

  let item: FileItem
  let name: String
  let settings: ViewSettings
  let width: CGFloat
  let isSelected: Bool
  let isRenaming: Bool
  let tab: TabModel
  let sizeUnits: SizeUnits
  let locale: Locale

  var body: some View {
    let isLabelBelow = settings.labelPosition == .bottom
    let stack = isLabelBelow ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 8))
    stack {
      ThumbnailIcon(item: item, size: CGFloat(settings.iconSize), showsPreview: settings.showsIconPreviews)
        .padding(4)
        .background {
          RoundedRectangle(cornerRadius: 6)
            .fill(isSelected ? Color.secondary.opacity(0.25) : Color.clear)
        }
      VStack(alignment: isLabelBelow ? .center : .leading, spacing: 2) {
        if isRenaming {
          RenameField(item: item, tab: tab, alignment: isLabelBelow ? .center : .leading)
        } else {
          Text(name)
            .font(settings.textSize.font)
            .lineLimit(2)
            .truncationMode(.middle)
            .multilineTextAlignment(isLabelBelow ? .center : .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background {
              RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor : Color.clear)
            }
        }
        if settings.showsItemInfo {
          ItemInfoLabel(item: item)
        }
      }
      .frame(maxWidth: isLabelBelow ? .infinity : nil, alignment: isLabelBelow ? .center : .leading)
    }
    .frame(width: width, alignment: isLabelBelow ? .center : .leading)
    .opacity(item.isHidden || FileClipboard.shared.isCut(item.url) ? 0.5 : 1)
    .contentShape(Rectangle())
    .fileItemAccessibility(item: item, tab: tab, name: name, sizeUnits: sizeUnits, locale: locale, isRenaming: isRenaming)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// The item count of a folder or the dimensions of an image, loaded when the cell appears.
private struct ItemInfoLabel: View {

  let item: FileItem

  @State private var info: ItemInfo?

  var body: some View {
    Group {
      switch info {
      case .itemCount(let count):
        Text("\(count) items")
      case .dimensions(let width, let height):
        Text(verbatim: "\(width) × \(height)")
      case nil:
        Text(verbatim: " ")
      }
    }
    .font(.caption)
    .foregroundStyle(.tint)
    .lineLimit(1)
    .task(id: item) {
      info = await ItemInfoProvider.info(for: item)
    }
  }
}

/// The header of one group in icon view.
private struct SectionHeader: View {

  let title: String

  var body: some View {
    Text(title)
      .font(.headline)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 4)
      .background(.bar)
  }
}

#Preview("English") {
  IconFileView(tab: .preview(in: .english))
    .frame(width: 600, height: 360)
}

#Preview("Grouped, German") {
  let tab = TabModel.preview(in: .german)
  tab.viewSettings.grouping = .kind
  tab.viewSettings.labelPosition = .right
  tab.viewSettings.showsItemInfo = true

  return IconFileView(tab: tab)
    .frame(width: 700, height: 400)
    .environment(\.locale, Locale(identifier: "de"))
}

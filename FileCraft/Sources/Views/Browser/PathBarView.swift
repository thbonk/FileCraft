/*
 * PathBarView.swift
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

/// The breadcrumb path of a tab's location. Double-clicking its empty area turns it into a path field.
///
/// When space is short, the middle segments collapse into an overflow menu while the first and the
/// last segments stay visible.
internal struct PathBarView: View {

  // MARK: - Properties

  internal let tab: TabModel
  /// Whether the path bar marks the active pane of a dual-pane window.
  internal let isHighlighted: Bool

  @State private var segments: [PathSegment] = []
  @State private var editedPath = ""
  @State private var isPathInvalid = false
  @FocusState private var isFieldFocused: Bool

  // MARK: - Body

  internal var body: some View {
    Group {
      if tab.isEditingPath {
        editor
      } else if tab.location == .computer {
        Label(tab.title, systemImage: Location.computer.systemImage)
          .labelStyle(.titleAndIcon)
          .lineLimit(1)
      } else if case .tag(let name) = tab.location {
        Label {
          Text(verbatim: name)
        } icon: {
          TagDots(tagNames: [name])
        }
        .lineLimit(1)
      } else if tab.location.searchQuery != nil, segments.isEmpty {
        Label(tab.title, systemImage: tab.location.systemImage)
          .labelStyle(.titleAndIcon)
          .lineLimit(1)
      } else {
        breadcrumbs
      }
    }
    .padding(.horizontal, 6)
    .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
    .background {
      Rectangle()
        .fill(isHighlighted ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(Color.clear))
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: beginEditing)
    }
    .onChange(of: tab.isEditingPath, initial: true) { _, isEditing in
      if isEditing {
        editedPath = tab.folderURL?.path(percentEncoded: false) ?? ""
        isPathInvalid = false
      }
    }
    .task(id: shownFolder) {
      guard let shownFolder else {
        segments = []
        return
      }
      segments = await PathComponents.load(for: shownFolder)
    }
  }

  /// The folder whose path the bar shows: the tab's folder or, in search results, the folder of the single selected
  /// item.
  private var shownFolder: URL? {
    if let folderURL = tab.folderURL {
      return folderURL
    }
    guard tab.location.searchQuery != nil, tab.selection.count == 1, let item = tab.selectedItems.first else {
      return nil
    }
    return item.url.deletingLastPathComponent()
  }

  // MARK: - Breadcrumbs

  private var breadcrumbs: some View {
    ViewThatFits(in: .horizontal) {
      segmentRow(visibleTail: nil)
      segmentRow(visibleTail: 3)
      segmentRow(visibleTail: 2)
      segmentRow(visibleTail: 1)
    }
  }

  /// A row of segments; with `visibleTail`, only the first and the last `visibleTail` segments are shown.
  private func segmentRow(visibleTail: Int?) -> some View {
    let collapsed = collapsedSegments(visibleTail: visibleTail)
    return HStack(spacing: 0) {
      if let first = segments.first, collapsed.isEmpty == false {
        PathSegmentButton(segment: first, tab: tab)
        overflowMenu(collapsed)
        ForEach(segments.suffix(visibleTail ?? 0)) { segment in
          PathSegmentButton(segment: segment, tab: tab)
        }
      } else {
        ForEach(segments) { segment in
          PathSegmentButton(segment: segment, tab: tab)
        }
      }
    }
    .fixedSize()
  }

  private func collapsedSegments(visibleTail: Int?) -> [PathSegment] {
    guard let visibleTail, segments.count > visibleTail + 1 else {
      return []
    }
    return Array(segments.dropFirst().dropLast(visibleTail))
  }

  private func overflowMenu(_ collapsed: [PathSegment]) -> some View {
    Menu {
      ForEach(collapsed) { segment in
        Button(segment.name) {
          tab.navigate(toFolder: segment.url)
        }
      }
    } label: {
      Image(systemName: "ellipsis")
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .accessibilityLabel(Text("More Folders"))
  }

  // MARK: - Editing

  private var editor: some View {
    PathField(text: $editedPath, base: tab.folderURL, isFocused: $isFieldFocused, placement: .overlay, onSubmit: commitEditing)
      .overlay {
        if isPathInvalid {
          RoundedRectangle(cornerRadius: 5)
            .stroke(.red)
        }
      }
      .help(isPathInvalid ? Text("Folder not found") : Text(verbatim: ""))
      .onAppear {
        isFieldFocused = true
      }
      .onExitCommand(perform: endEditing)
      .onChange(of: editedPath) {
        isPathInvalid = false
      }
      .onChange(of: isFieldFocused) { _, isFocused in
        if isFocused == false {
          endEditing()
        }
      }
  }

  private func beginEditing() {
    tab.isEditingPath = true
  }

  private func endEditing() {
    tab.isEditingPath = false
    isPathInvalid = false
  }

  /// Shows the typed folder, or the folder containing a typed file with that file selected.
  private func commitEditing() {
    guard let url = PathInputParser.url(for: editedPath, relativeTo: tab.folderURL) else {
      isPathInvalid = true
      return
    }
    Task {
      guard let item = try? await FileSystemService().item(at: url) else {
        isPathInvalid = true
        return
      }
      if item.isDirectory && item.isPackage == false {
        tab.navigate(toFolder: item.url)
      } else {
        tab.reveal(item.url)
      }
      endEditing()
    }
  }
}

/// One folder of the path bar with a button that lists its subfolders.
private struct PathSegmentButton: View {

  // MARK: - Properties

  let segment: PathSegment
  let tab: TabModel

  @State private var showsSubfolders = false

  // MARK: - Body

  var body: some View {
    HStack(spacing: 0) {
      Button {
        tab.navigate(toFolder: segment.url)
      } label: {
        Label {
          Text(segment.name)
            .lineLimit(1)
        } icon: {
          FileIcon(url: segment.url, size: 14)
        }
      }
      .buttonStyle(.borderless)
      .fileDropTarget(segment.url, tab: tab, springsOpen: true)
      Button {
        showsSubfolders = true
      } label: {
        Image(systemName: "chevron.right")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 3)
      }
      .buttonStyle(.borderless)
      .help(Text("Show Subfolders"))
      .accessibilityLabel(Text("Show Subfolders"))
      .popover(isPresented: $showsSubfolders, arrowEdge: .bottom) {
        SubfolderList(folder: segment.url) { url in
          showsSubfolders = false
          tab.navigate(toFolder: url)
        }
      }
    }
  }
}

/// The subfolders of a folder, loaded when the popover opens.
private struct SubfolderList: View {

  // MARK: - Properties

  let folder: URL
  let onSelect: (URL) -> Void

  @State private var subfolders: [FileItem]?

  // MARK: - Body

  var body: some View {
    Group {
      if let subfolders, subfolders.isEmpty {
        Text("No Subfolders")
          .foregroundStyle(.secondary)
          .padding()
      } else if let subfolders {
        List(subfolders) { item in
          Button {
            onSelect(item.url)
          } label: {
            Label {
              Text(item.localizedName)
            } icon: {
              FileIcon(url: item.url)
            }
          }
          .buttonStyle(.plain)
        }
        .frame(width: 260, height: min(CGFloat(subfolders.count) * 24 + 16, 360))
      } else {
        ProgressView()
          .controlSize(.small)
          .padding()
      }
    }
    .task {
      let items = (try? await FileSystemService().contentsOfDirectory(at: folder, includingHiddenItems: false)) ?? []
      subfolders = ItemSorting(order: ItemSortOrder()).sorted(items.filter { $0.isDirectory && $0.isPackage == false })
    }
  }
}

#Preview {
  VStack(spacing: 0) {
    PathBarView(tab: .preview(in: .english), isHighlighted: false)
    Divider()
    PathBarView(tab: .preview(in: .german), isHighlighted: true)
      .environment(\.locale, Locale(identifier: "de"))
  }
  .frame(width: 480)
}

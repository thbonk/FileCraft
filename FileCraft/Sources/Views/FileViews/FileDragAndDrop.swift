/*
 * FileDragAndDrop.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-04.
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
import CoreTransferable
import SwiftUI

/// A file or folder being dragged. It carries its file URL, so that Finder and other applications accept it too.
internal struct DraggedFile: Identifiable, Transferable {

  /// The item's ID in the file views, its path.
  internal let id: FileItem.ID
  internal let url: URL

  internal static var transferRepresentation: some TransferRepresentation {
    ProxyRepresentation(exporting: \.url)
  }
}

extension View {

  /// Makes the items of a file view draggable: dragging a selected item drags the whole selection.
  internal func fileDragContainer(tab: TabModel, items: [FileItem]) -> some View {
    let urls = Dictionary(items.map { ($0.id, $0.url) }, uniquingKeysWith: { first, _ in first })
    return dragContainer(for: DraggedFile.self) { ids in
      ids.compactMap { id in urls[id].map { DraggedFile(id: id, url: $0) } }
    }
    .dragContainerSelection(Array(tab.selection))
  }

  /// Accepts items dropped onto `folder` with the drag-and-drop rules; nil accepts nothing. With `springsOpen`,
  /// hovering opens the folder in `tab` after the spring-loading delay, or at once with Space.
  internal func fileDropTarget(_ folder: URL?, tab: TabModel?, springsOpen: Bool = false) -> some View {
    modifier(FileDropTarget(folder: folder, tab: tab, springsOpen: springsOpen))
  }
}

/// A drop target for files: it highlights while targeted, shows the operation at the cursor, performs the drop
/// through the window's file commands and springs folders open.
private struct FileDropTarget: ViewModifier {

  // MARK: - Properties

  let folder: URL?
  let tab: TabModel?
  let springsOpen: Bool

  @AppStorage(SettingsKeys.springLoadsFolders.name) private var springLoadsFolders = SettingsKeys.springLoadsFolders.defaultValue
  @AppStorage(SettingsKeys.springLoadingDelay.name) private var springLoadingDelay = SettingsKeys.springLoadingDelay.defaultValue
  @State private var isTargeted = false
  @State private var springLoading: Task<Void, Never>?
  @State private var spaceMonitor: Any?

  // MARK: - Body

  func body(content: Content) -> some View {
    content
      .dropDestination(for: URL.self, isEnabled: folder != nil) { urls, session in
        endHovering()
        guard let folder, let commands = tab?.pane?.window?.fileCommands else {
          return
        }
        let keys = Self.keys(of: session.suggestedOperations)
        Task { await commands.drop(urls, into: folder, keys: keys) }
      }
      .dropConfiguration { session in
        DropConfiguration(operation: operation(for: session))
      }
      .onDropSessionUpdated { session in
        switch session.phase {
        case .entering:
          beginHovering()
        case .exiting, .ended, .dataTransferCompleted:
          endHovering()
        case .active:
          break
        @unknown default:
          break
        }
      }
      .background {
        if isTargeted {
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.accentColor.opacity(0.2))
        }
      }
  }

  // MARK: - Operation

  /// The operation the cursor shows: what the drop will do with the local items, a copy for items from other
  /// applications, and nothing for a folder dropped into itself.
  private func operation(for session: DropSession) -> DropOperation {
    guard let folder else {
      return .forbidden
    }
    let keys = Self.keys(of: session.suggestedOperations)
    let paths = session.localSession?.draggedItemIDs(for: FileItem.ID.self) ?? []
    guard paths.isEmpty == false else {
      return keys == .alias ? .alias : (keys == .move ? .move : .copy)
    }
    switch DropPolicy().action(for: paths.map { URL(filePath: $0) }, into: folder, keys: keys) {
    case .move:
      return .move
    case .copy:
      return .copy
    case .alias:
      return .alias
    case .nothing, .refuse:
      return .forbidden
    }
  }

  /// The forced operation: AppKit leaves only copy with ⌥, only move with ⌘ and only alias with ⌥⌘.
  private static func keys(of operations: DropOperation.Set) -> DropKeys {
    switch operations {
    case .alias:
      .alias
    case .copy:
      .copy
    case .move:
      .move
    default:
      .none
    }
  }

  // MARK: - Spring Loading

  private func beginHovering() {
    isTargeted = true
    guard springsOpen, springLoadsFolders, folder != nil else {
      return
    }
    let delay = Duration.seconds(springLoadingDelay)
    springLoading?.cancel()
    springLoading = Task {
      try? await Task.sleep(for: delay)
      guard Task.isCancelled == false else {
        return
      }
      springOpen()
    }
    // Space opens the folder at once (design decision D9).
    spaceMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      guard event.charactersIgnoringModifiers == " " else {
        return event
      }
      springOpen()
      return nil
    }
  }

  private func endHovering() {
    isTargeted = false
    springLoading?.cancel()
    springLoading = nil
    if let spaceMonitor {
      NSEvent.removeMonitor(spaceMonitor)
    }
    spaceMonitor = nil
  }

  private func springOpen() {
    guard let folder, let tab else {
      return
    }
    endHovering()
    tab.navigate(toFolder: folder)
  }
}

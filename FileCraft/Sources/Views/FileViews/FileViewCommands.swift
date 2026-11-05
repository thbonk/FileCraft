/*
 * FileViewCommands.swift
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

/// The context menu commands for file items, shared by all file views.
internal struct FileItemContextMenu: View {

  // MARK: - Properties

  internal let items: [FileItem]
  internal let tab: TabModel

  // MARK: - Body

  internal var body: some View {
    if items.isEmpty == false {
      let urls = items.map(\.url)
      Button("Open") {
        tab.open(items)
      }
      if items.contains(where: tab.opensAsFolder) {
        Button("Open in New Tab") {
          tab.openInNewTabs(items)
        }
      }
      if items.count == 1, let folder = items.first, tab.opensAsFolder(folder), let window = tab.pane?.window,
        window.otherPane != nil
      {
        Button("Open in Other Pane") {
          window.openInOtherPane(folder)
        }
      }
      // Built when the menu opens, so Launch Services is asked only then.
      OpenWithMenu(applications: OpenWithProvider.applications(toOpen: urls)) {
        tab.applicationChoiceRequest = urls
      } open: { application in
        WorkspaceActions.open(urls, withApplicationAt: application)
      }
      Button("Quick Look") {
        tab.quickLook(items)
      }
      if items.count == 1, let item = items.first {
        if item.isPackage {
          Button("Show Package Contents") {
            tab.showPackageContents(item)
          }
        }
        if item.isAliasFile || item.isSymbolicLink {
          Button("Show Original") {
            Task {
              await tab.showOriginal(of: item)
            }
          }
        }
        Button("Rename") {
          tab.beginRename(item)
        }
      }
      Button("Duplicate") {
        run { await $0.duplicate(urls) }
      }
      Button("Make Alias") {
        run { await $0.makeAlias(urls) }
      }
      Button("Make Symbolic Link") {
        run { await $0.makeSymbolicLink(urls) }
      }
      Button("Compress") {
        run { await $0.compress(urls) }
      }
      if urls.contains(where: ArchiveService.isArchive) {
        Button("Expand") {
          run { await $0.expand(urls) }
        }
      }
      Divider()
      if tab.pane?.window?.fileCommands.canPutBack(urls) == true {
        Button("Put Back") {
          run { await $0.putBack(urls) }
        }
      } else {
        Button("Move to Trash") {
          run { await $0.moveToTrash(urls) }
        }
      }
      if items.count == 1, let url = urls.first, let volume = ejectableVolume(at: url) {
        Button("Eject") {
          run { await $0.eject(volume) }
        }
      }
      Divider()
      Button("Copy Path") {
        PasteboardActions.copyPaths(of: urls, as: .posix)
      }
      Button("Add to Shelf") {
        tab.pane?.window?.layout.isShelfVisible = true
        Task {
          await ShelfStore.shared.add(urls)
        }
      }
      Button("Reveal in Finder") {
        WorkspaceActions.revealInFinder(
          urls,
          fileCraftIsFileViewer: SettingsStore().value(for: SettingsKeys.usesFileCraftAsFileViewer))
      }
      if items.contains(where: tab.opensAsFolder) {
        Button("Open in Terminal") {
          WorkspaceActions.openInTerminal(
            items.filter(tab.opensAsFolder).map(\.url),
            bundleIdentifier: SettingsStore().value(for: SettingsKeys.terminalBundleIdentifier))
        }
      }
    }
  }

  // MARK: - Private

  /// Runs a file command of the tab's window.
  private func run(_ command: @escaping @MainActor (FileCommandModel) async -> Void) {
    guard let commands = tab.pane?.window?.fileCommands else {
      return
    }
    Task {
      await command(commands)
    }
  }

  /// The volume at `url` when it can be ejected, as in the Computer location.
  private func ejectableVolume(at url: URL) -> Volume? {
    SidebarSources.shared.volumes.first { $0.canEject && $0.url.comparablePath == url.comparablePath }
  }
}

/// The Open With submenu: the default application first and marked, the other applications, then Other….
internal struct OpenWithMenu: View {

  // MARK: - Properties

  internal let applications: [ApplicationChoice]
  /// Asks for any application with Open With > Other….
  internal let chooseOther: () -> Void
  internal let open: (URL) -> Void

  // MARK: - Body

  internal var body: some View {
    Menu("Open With") {
      ForEach(applications) { application in
        Button {
          open(application.url)
        } label: {
          if application.isDefault {
            Text("\(application.name) (default)")
          } else {
            Text(verbatim: application.name)
          }
        }
      }
      if applications.isEmpty == false {
        Divider()
      }
      Button("Other…", action: chooseOther)
    }
  }
}

/// The keyboard commands shared by all file views: Return, ⌘↓, Space and type-to-select.
///
/// Arrow keys are left to each view, because their meaning depends on the layout.
internal struct FileKeyHandler {

  // MARK: - Properties

  internal let tab: TabModel
  internal let returnKeyAction: ReturnKeyAction
  internal let alwaysShowsExtensions: Bool
  internal let locale: Locale

  private static let typeSelectCharacters = CharacterSet.alphanumerics
    .union(.punctuationCharacters)
    .union(.symbols)
    .union(.whitespaces)

  // MARK: - Handling

  /// Handles `press` for the items of a view in display order.
  internal func handle(_ press: KeyPress, items: [FileItem]) -> KeyPress.Result {
    guard tab.renamingItemID == nil else {
      return .ignored
    }
    let selected = tab.selectedItems
    switch press.key {
    case .return:
      if returnKeyAction == .rename, selected.count == 1, let item = selected.first {
        tab.beginRename(item)
      } else {
        tab.open(selected)
      }
      return .handled
    case .downArrow where press.modifiers.contains(.command):
      tab.open(selected)
      return .handled
    case .space where press.modifiers.isEmpty:
      tab.toggleQuickLook()
      return .handled
    case .tab where press.modifiers.isEmpty:
      // With dual pane on, Tab moves to the other pane's file view; otherwise focus moves on as usual.
      return tab.pane?.window?.focusOtherPane() == true ? .handled : .ignored
    case FunctionKey.f7, FunctionKey.f8:
      return handleFunctionKey(press.key, selected: selected)
    default:
      return typeSelect(press, items: items)
    }
  }

  /// F7 creates a new folder and F8 moves the selection to the Trash, when the function-key setting is on. F5
  /// and F6 are the shortcuts of Tools > Copy to Other Pane and Move to Other Pane.
  private func handleFunctionKey(_ key: KeyEquivalent, selected: [FileItem]) -> KeyPress.Result {
    guard SettingsStore().value(for: SettingsKeys.usesFunctionKeys), let commands = tab.pane?.window?.fileCommands else {
      return .ignored
    }
    let urls = selected.map(\.url)
    if key == FunctionKey.f7 {
      Task { await commands.newFolder() }
    } else {
      Task { await commands.moveToTrash(urls) }
    }
    return .handled
  }

  private func typeSelect(_ press: KeyPress, items: [FileItem]) -> KeyPress.Result {
    let characters = press.characters
    guard
      press.modifiers.subtracting(.shift).isEmpty,
      characters.isEmpty == false,
      characters.unicodeScalars.allSatisfy({ Self.typeSelectCharacters.contains($0) })
    else {
      return .ignored
    }
    let entries = items.map { (id: $0.id, name: ItemPresentation.displayName(of: $0, alwaysShowsExtensions: alwaysShowsExtensions)) }
    tab.typeSelect(characters, in: entries, locale: locale)
    return .handled
  }
}

/// The badge that marks aliases and symbolic links.
internal struct LinkBadge: View {

  internal var size: CGFloat = 8

  internal var body: some View {
    Image(systemName: "arrowshape.turn.up.right.circle.fill")
      .font(.system(size: size))
      .symbolRenderingMode(.palette)
      .foregroundStyle(.white, .black.opacity(0.75))
      .accessibilityLabel(Text("Alias or symbolic link"))
  }
}

extension BrowserTextSize {
  /// The font of item names and metadata for this text size.
  internal var font: Font {
    switch self {
    case .small:
      .callout
    case .medium:
      .body
    case .large:
      .title3
    }
  }
}

#Preview {
  Menu("Context Menu") {
    FileItemContextMenu(items: Array(PreviewFixtures.items(in: .english).prefix(1)), tab: .preview(in: .english))
  }
  .padding()
}

/*
 * FileCommandModel.swift
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

import Foundation
import Observation

/// The file commands of one browser window: creating, duplicating, aliasing, trashing, putting back, deleting and
/// ejecting, with their undo actions and alerts. They act on the active tab.
@Observable
internal final class FileCommandModel {

  // MARK: - Types

  /// A failed command, explained in an alert.
  internal struct Failure: Identifiable {
    internal let id = UUID()
    internal let title: LocalizedStringResource
    internal let message: String?
  }

  /// A Copy To… or Move To… waiting for its destination.
  internal struct DestinationRequest: Identifiable {
    internal let id = UUID()
    internal let kind: FileOperationKind
    internal let urls: [URL]
  }

  // MARK: - Properties

  /// The items waiting for the confirmation of Delete Immediately.
  internal var deleteConfirmation: [URL] = []
  /// The items that could not be moved to the Trash; the alert offers deleting them immediately.
  internal var trashFailures: [URL] = []
  internal var isConfirmingEmptyTrash = false
  /// Whether FileCraft could not read a Trash folder, which needs Full Disk Access.
  internal var needsFullDiskAccessToEmptyTrash = false
  internal var failure: Failure?
  /// The Copy To… or Move To… whose destination sheet is shown.
  internal var destinationRequest: DestinationRequest?

  /// The window whose active tab the commands act on.
  @ObservationIgnored internal weak var window: BrowserWindowModel?
  /// The window's undo manager, which the window view hands over.
  @ObservationIgnored internal weak var undoManager: UndoManager?

  @ObservationIgnored private let creator: ItemCreator
  @ObservationIgnored private let trash: TrashService
  @ObservationIgnored private let putBackStore: PutBackStore
  @ObservationIgnored private let operations: OperationQueueModel
  @ObservationIgnored private let settings: SettingsStore
  @ObservationIgnored private let volumes: () -> [Volume]
  @ObservationIgnored private let clipboard: FileClipboard
  @ObservationIgnored private let pasteboardURLs: () -> [URL]

  /// Registers undo actions with the window's undo manager.
  internal var undoRegistrar: FileUndoRegistrar {
    FileUndoRegistrar(undoManager: undoManager, trash: trash, putBackStore: putBackStore, operations: operations)
  }

  private var tab: TabModel? {
    window?.activeTab
  }

  // MARK: - Initialization

  internal init(
    creator: ItemCreator = ItemCreator(),
    trash: TrashService = TrashService(),
    putBackStore: PutBackStore = .shared,
    operations: OperationQueueModel = .shared,
    settings: SettingsStore = SettingsStore(),
    volumes: @escaping () -> [Volume] = { SidebarSources.shared.volumes },
    clipboard: FileClipboard = .shared,
    pasteboardURLs: @escaping () -> [URL] = { PasteboardActions.fileURLs() }
  ) {
    self.creator = creator
    self.trash = trash
    self.putBackStore = putBackStore
    self.operations = operations
    self.settings = settings
    self.volumes = volumes
    self.clipboard = clipboard
    self.pasteboardURLs = pasteboardURLs
  }

  // MARK: - Availability

  /// Whether new items can be created, which needs a folder as the location.
  internal var canCreateItems: Bool {
    tab?.folderURL != nil
  }

  internal var hasSelection: Bool {
    tab?.selection.isEmpty == false
  }

  /// The selected items, which the menu commands act on.
  internal var selectedURLs: [URL] {
    tab?.selectedItems.map(\.url) ?? []
  }

  /// Whether Put Back applies to `urls`: some of them were moved to the Trash by FileCraft.
  internal func canPutBack(_ urls: [URL]) -> Bool {
    putBackMoves(for: urls).isEmpty == false
  }

  /// The volume that Eject ejects: a selected volume, otherwise the volume of the current folder, when it can be
  /// ejected.
  internal var ejectableVolume: Volume? {
    let ejectable = volumes().filter(\.canEject)
    guard let tab, ejectable.isEmpty == false else {
      return nil
    }
    let selectedPaths = Set(tab.selectedItems.map(\.url.comparablePath))
    if let selected = ejectable.first(where: { selectedPaths.contains($0.url.comparablePath) }) {
      return selected
    }
    guard let folderPath = tab.folderURL?.comparablePath else {
      return nil
    }
    return ejectable
      .filter { folderPath == $0.url.comparablePath || folderPath.hasPrefix($0.url.comparablePath + "/") }
      .max { $0.url.comparablePath.count < $1.url.comparablePath.count }
  }

  // MARK: - Creating

  /// File > New Folder: creates "untitled folder" in the current folder, selects it and starts renaming it.
  internal func newFolder() async {
    guard let tab, let folder = tab.folderURL else {
      return
    }
    do {
      let url = try await creator.makeFolder(in: folder)
      undoRegistrar.registerCreation(of: [url], actionName: String(localized: "New Folder"))
      tab.selectCreatedItems([url], renaming: url)
    } catch {
      failure = Failure(title: "The folder could not be created.", message: error.localizedDescription)
    }
  }

  /// File > New Folder with Selection: creates a folder, moves the selected items into it, selects it and starts
  /// renaming it.
  internal func newFolderWithSelection(_ items: [URL]) async {
    guard let tab, let folder = tab.folderURL else {
      return
    }
    guard items.isEmpty == false else {
      return
    }
    do {
      let newFolder = try await creator.makeFolder(in: folder)
      let moves = items.map { ItemMove(from: $0, to: newFolder.appending(path: $0.lastPathComponent)) }
      let failed = Set(await Self.rename(moves))
      undoRegistrar.registerGrouping(into: newFolder, moves: moves.filter { failed.contains($0) == false })
      tab.selectCreatedItems([newFolder], renaming: newFolder)
      if failed.isEmpty == false {
        failure = Failure(title: "Some items could not be moved into the new folder.", message: nil)
      }
    } catch {
      failure = Failure(title: "The folder could not be created.", message: error.localizedDescription)
    }
  }

  /// File > New Text File: creates an empty "untitled.txt" in the current folder and selects it.
  internal func newTextFile() async {
    guard let tab, let folder = tab.folderURL else {
      return
    }
    do {
      let url = try await creator.makeTextFile(in: folder)
      undoRegistrar.registerCreation(of: [url], actionName: String(localized: "New Text File"))
      tab.selectCreatedItems([url])
    } catch {
      failure = Failure(title: "The text file could not be created.", message: error.localizedDescription)
    }
  }

  /// File > Duplicate: copies each item into its folder as "<name> copy" and selects the copies.
  internal func duplicate(_ items: [URL]) async {
    guard let tab else {
      return
    }
    var created: [URL] = []
    // One copy operation per folder; copying an item into its own folder names the copy "<name> copy".
    let byFolder = Dictionary(grouping: items) { $0.deletingLastPathComponent().comparablePath }
    for (_, urls) in byFolder.sorted(by: { $0.key < $1.key }) {
      guard let folder = urls.first?.deletingLastPathComponent() else {
        continue
      }
      let request = FileOperationRequest(
        kind: .copy, sources: urls, destination: folder, verifiesCopies: settings.value(for: SettingsKeys.verifiesCopies))
      let id = await operations.enqueue(request)
      created += await operations.waitUntilFinished(id)?.results ?? []
    }
    undoRegistrar.registerCreation(of: created, actionName: String(localized: "Duplicate"))
    tab.selectCreatedItems(created)
  }

  /// Tools > Batch Rename…: performs `moves` as one undoable action and selects the renamed items. When an item
  /// cannot be renamed, the batch is reverted and an alert names the item.
  @discardableResult
  internal func batchRename(_ moves: [ItemMove]) async -> Bool {
    do {
      try await BatchRenamer().rename(moves)
    } catch {
      failure = Failure(
        title: "“\(error.url.lastPathComponent)” could not be renamed. No items were renamed.",
        message: error.underlyingError.localizedDescription)
      return false
    }
    undoRegistrar.registerBatchRename(moves)
    tab?.selectCreatedItems(moves.map(\.to))
    return true
  }

  /// File > Make Alias: creates a Finder alias next to each item and selects the aliases.
  internal func makeAlias(_ items: [URL]) async {
    await makeLinks(to: items, actionName: String(localized: "Make Alias")) { [creator] item in
      try await creator.makeAlias(of: item)
    }
  }

  /// File > Make Symbolic Link: creates a symbolic link next to each item and selects the links.
  internal func makeSymbolicLink(_ items: [URL]) async {
    await makeLinks(to: items, actionName: String(localized: "Make Symbolic Link")) { [creator] item in
      try await creator.makeSymbolicLink(to: item)
    }
  }

  // MARK: - Copying and Moving

  /// The folder of the other pane's current tab, the destination of Copy to Other Pane and Move to Other Pane.
  internal var otherPaneFolder: URL? {
    window?.otherPane?.currentTab.folderURL
  }

  /// Copies or moves `urls` into `folder` through the Operations queue, registers the undo action, and selects
  /// the new items when the active tab shows `folder`.
  ///
  /// - Returns: Each item that was copied or moved, from its source to its new place.
  @discardableResult
  internal func transfer(_ urls: [URL], to folder: URL, kind: FileOperationKind) async -> [ItemMove] {
    guard urls.isEmpty == false, kind == .copy || kind == .move else {
      return []
    }
    let request = FileOperationRequest(
      kind: kind, sources: urls, destination: folder, verifiesCopies: settings.value(for: SettingsKeys.verifiesCopies))
    let id = await operations.enqueue(request)
    guard let finished = await operations.waitUntilFinished(id) else {
      return []
    }
    let actionName = Self.actionName(for: kind, of: urls)
    if kind == .copy {
      undoRegistrar.registerCreation(of: finished.transfers.map(\.to), actionName: actionName)
    } else {
      undoRegistrar.registerMove(finished.transfers, actionName: actionName)
    }
    if let tab = window?.activeTab, tab.folderURL?.comparablePath == folder.comparablePath {
      tab.selectCreatedItems(finished.results)
    }
    return finished.transfers
  }

  /// The shelf's Copy Items to Current Folder and Move Items to Current Folder: copies or moves `urls` into the
  /// active tab's folder. Moved items stay on `shelf`, pointing to their new places.
  internal func transferShelfItems(_ urls: [URL], kind: FileOperationKind, shelf: ShelfStore = .shared) async {
    guard let folder = tab?.folderURL else {
      return
    }
    let moves = await transfer(urls, to: folder, kind: kind)
    if kind == .move {
      await shelf.relocate(moves)
    }
  }

  /// Edit > Paste: copies `urls` into the current folder, or moves them when they are the items cut last.
  internal func paste(_ urls: [URL]) async {
    guard let folder = tab?.folderURL else {
      return
    }
    await transfer(urls, to: folder, kind: clipboard.takeCut(urls) ? .move : .copy)
  }

  /// Edit > Move Items Here: moves the items on the pasteboard into the current folder.
  internal func moveItemsHere() async {
    guard let folder = tab?.folderURL else {
      return
    }
    let urls = pasteboardURLs()
    clipboard.clear()
    await transfer(urls, to: folder, kind: .move)
  }

  /// Drops `urls` onto `folder` with the drag-and-drop rules: move on the same volume, copy across volumes, the
  /// held `keys` forcing a copy, move or aliases. A folder dropped into itself is refused with the reason.
  internal func drop(_ urls: [URL], into folder: URL, keys: DropKeys, policy: DropPolicy = DropPolicy()) async {
    switch policy.action(for: urls, into: folder, keys: keys) {
    case .move:
      await transfer(urls, to: folder, kind: .move)
    case .copy:
      await transfer(urls, to: folder, kind: .copy)
    case .alias:
      await makeLinks(to: urls, actionName: String(localized: "Make Alias")) { [creator] item in
        try await creator.makeAlias(of: item, in: folder)
      }
    case .nothing:
      break
    case .refuse(let reason):
      failure = Failure(title: "The items can’t be moved there.", message: reason)
    }
  }

  /// File > Copy To… and Move To…: asks for the destination first.
  internal func requestTransfer(of urls: [URL], kind: FileOperationKind) {
    guard urls.isEmpty == false else {
      return
    }
    destinationRequest = DestinationRequest(kind: kind, urls: urls)
  }

  /// Tools > Copy to Other Pane (F5) and Move to Other Pane (F6).
  internal func transferToOtherPane(_ urls: [URL], kind: FileOperationKind) async {
    guard let folder = otherPaneFolder else {
      return
    }
    await transfer(urls, to: folder, kind: kind)
  }

  /// The undo action name, such as "Move of 3 Items".
  internal static func actionName(for kind: FileOperationKind, of urls: [URL]) -> String {
    let name = urls.first?.lastPathComponent ?? ""
    switch (kind, urls.count) {
    case (.move, 1):
      return String(localized: "Move of “\(name)”")
    case (.move, let count):
      return String(localized: "Move of \(count) Items")
    case (_, 1):
      return String(localized: "Copy of “\(name)”")
    case (_, let count):
      return String(localized: "Copy of \(count) Items")
    }
  }

  // MARK: - Archives

  /// File > Compress and Compress With Format: puts `urls` into one archive and selects it.
  ///
  /// - Parameter format: The archive format; nil uses the default format from Settings.
  internal func compress(_ urls: [URL], format: CompressionFormat? = nil) async {
    guard let first = urls.first else {
      return
    }
    let folder = archiveFolder(near: first)
    let request = FileOperationRequest(
      kind: .compress, sources: urls, destination: folder,
      archiveFormat: format ?? settings.value(for: SettingsKeys.compressionFormat))
    let id = await operations.enqueue(request)
    guard let finished = await operations.waitUntilFinished(id) else {
      return
    }
    undoRegistrar.registerCreation(of: finished.results, actionName: String(localized: "Compress"))
    selectResults(finished.results, in: folder)
  }

  /// File > Expand: expands the archives among `urls`, moves them to the Trash when the setting asks for it, and
  /// selects the expanded items.
  internal func expand(_ urls: [URL]) async {
    let archives = urls.filter(ArchiveService.isArchive)
    var created: [URL] = []
    var expandedArchives: [URL] = []
    let byFolder = Dictionary(grouping: archives) { archiveFolder(near: $0).comparablePath }
    for (_, group) in byFolder.sorted(by: { $0.key < $1.key }) {
      guard let first = group.first else {
        continue
      }
      let id = await operations.enqueue(FileOperationRequest(kind: .expand, sources: group, destination: archiveFolder(near: first)))
      guard let finished = await operations.waitUntilFinished(id) else {
        continue
      }
      created += finished.results
      if finished.state == .completed {
        expandedArchives += group
      }
    }
    var trashedArchives: [ItemMove] = []
    if settings.value(for: SettingsKeys.trashesArchiveAfterExpanding), expandedArchives.isEmpty == false {
      let result = await trash.moveToTrash(expandedArchives)
      putBackStore.record(result.moves)
      trashedArchives = result.moves
    }
    undoRegistrar.registerExpansion(created: created, trashedArchives: trashedArchives)
    if let folder = created.first?.deletingLastPathComponent() {
      selectResults(created, in: folder)
    }
  }

  /// Whether Expand applies to some of `urls`.
  internal func canExpand(_ urls: [URL]) -> Bool {
    urls.contains(where: ArchiveService.isArchive)
  }

  /// The folder for new archives and expanded items: the folder chosen in Settings, otherwise the folder of `url`.
  private func archiveFolder(near url: URL) -> URL {
    let chosenPath = settings.value(for: SettingsKeys.archiveDestinationPath)
    if settings.value(for: SettingsKeys.archiveDestination) == .chosenFolder, chosenPath.isEmpty == false,
      FileCopier.isDirectory(URL(filePath: chosenPath))
    {
      return URL(filePath: chosenPath, directoryHint: .isDirectory)
    }
    return url.deletingLastPathComponent()
  }

  /// Selects the results when the setting asks for it and the active tab shows `folder`.
  private func selectResults(_ urls: [URL], in folder: URL) {
    guard settings.value(for: SettingsKeys.selectsResult), let tab = window?.activeTab,
      tab.folderURL?.comparablePath == folder.comparablePath
    else {
      return
    }
    tab.selectCreatedItems(urls)
  }

  // MARK: - Trash

  /// File > Move to Trash: moves `urls` to the Trash; items that cannot go there are offered for deletion.
  internal func moveToTrash(_ urls: [URL]) async {
    guard urls.isEmpty == false else {
      return
    }
    let result = await trash.moveToTrash(urls)
    putBackStore.record(result.moves)
    undoRegistrar.registerTrash(of: result.moves, actionName: String(localized: "Move to Trash"))
    trashFailures = result.failures
    if let item = result.unchangeable.first {
      // Neither the Trash nor deleting can change these items, so nothing else is offered.
      failure = Failure(
        title: "“\(item.lastPathComponent)” can’t be moved to the Trash.",
        message: String(localized: "macOS protects this location, or its volume is read-only, so it can’t be changed."))
    }
  }

  /// File > Put Back: returns the items among `urls` that FileCraft moved to the Trash to their original places.
  internal func putBack(_ urls: [URL]) async {
    let moves = putBackMoves(for: urls)
    guard moves.isEmpty == false else {
      return
    }
    let failed = Set(await trash.putBack(moves))
    let restored = moves.filter { failed.contains($0) == false }
    putBackStore.remove(trashed: restored.map(\.to))
    // Undoing Put Back moves the items to the Trash again.
    undoRegistrar.registerCreation(of: restored.map(\.from), actionName: String(localized: "Put Back"))
    if failed.isEmpty == false {
      failure = Failure(title: "Some items could not be put back.", message: String(localized: "An item with the same name may be at the original location, or the location no longer exists."))
    }
  }

  /// File > Delete Immediately…: asks for confirmation first.
  internal func requestDeleteImmediately(_ urls: [URL]) {
    deleteConfirmation = urls
  }

  /// Deletes `urls` without using the Trash, through the Operations queue.
  internal func deleteImmediately(_ urls: [URL]) async {
    let byFolder = Dictionary(grouping: urls) { $0.deletingLastPathComponent().comparablePath }
    for (_, urls) in byFolder.sorted(by: { $0.key < $1.key }) {
      guard let folder = urls.first?.deletingLastPathComponent() else {
        continue
      }
      await operations.enqueue(FileOperationRequest(kind: .delete, sources: urls, destination: folder))
    }
  }

  /// FileCraft > Empty Trash…: asks for confirmation first, unless the warning is turned off.
  internal func requestEmptyTrash() async {
    if settings.value(for: SettingsKeys.warnsBeforeEmptyingTrash) {
      isConfirmingEmptyTrash = true
    } else {
      await emptyTrash()
    }
  }

  /// Deletes the contents of the user's Trash folders on all volumes, through the Operations queue.
  internal func emptyTrash() async {
    let contents = await TrashService.contents(of: await TrashService.trashFolders())
    needsFullDiskAccessToEmptyTrash = contents.contains { $0.isReadable == false }
    var ids: [UUID] = []
    for content in contents where content.items.isEmpty == false {
      ids.append(await operations.enqueue(FileOperationRequest(kind: .delete, sources: content.items, destination: content.folder)))
    }
    for id in ids {
      _ = await operations.waitUntilFinished(id)
    }
    await putBackStore.removeMissingItems()
  }

  // MARK: - Eject

  /// File > Eject: ejects `ejectableVolume`; the unmount sends panes showing the volume to the home folder.
  internal func eject() async {
    guard let volume = ejectableVolume else {
      return
    }
    await eject(volume)
  }

  /// Ejects `volume`, explaining in an alert when it is in use or ejecting fails.
  internal func eject(_ volume: Volume) async {
    switch await VolumeActions.eject(volume.url) {
    case .ejected:
      break
    case .busy:
      failure = Failure(title: "“\(volume.name)” can't be ejected because it is in use.", message: nil)
    case .failed(let message):
      failure = Failure(title: "“\(volume.name)” could not be ejected.", message: message)
    }
  }

  // MARK: - Private

  /// The items among `urls` that FileCraft moved to the Trash, from their original places to the Trash.
  private func putBackMoves(for urls: [URL]) -> [ItemMove] {
    urls.compactMap { url in
      putBackStore.originalLocation(of: url).map { ItemMove(from: $0, to: url) }
    }
  }

  private func makeLinks(to items: [URL], actionName: String, make: @escaping @Sendable (URL) async throws -> URL) async {
    guard let tab else {
      return
    }
    var created: [URL] = []
    var lastError: (any Error)?
    for item in items {
      do {
        created.append(try await make(item))
      } catch {
        lastError = error
      }
    }
    undoRegistrar.registerCreation(of: created, actionName: actionName)
    tab.selectCreatedItems(created)
    if let lastError {
      failure = Failure(title: "Some items could not be created.", message: lastError.localizedDescription)
    }
  }

  /// Moves items within their volume and returns the moves that failed.
  @concurrent
  private static func rename(_ moves: [ItemMove]) async -> [ItemMove] {
    moves.filter { move in
      (try? FileOperationWorker.renameWithinVolume(move.from, move.to)) != true
    }
  }
}

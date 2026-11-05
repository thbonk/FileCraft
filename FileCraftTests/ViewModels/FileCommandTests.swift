/*
 * FileCommandTests.swift
 * FileCraftTests
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
import Synchronization
import Testing
@testable import FileCraft

/// The file commands of a window with their undo actions. A fake Trash in the temporary folder stands in for the
/// user's Trash, which the tests never touch.
@Suite(.timeLimit(.minutes(1)))
internal struct FileCommandTests {

  // MARK: - Trash

  @Test
  internal func `Move to Trash records Put Back, and items that cannot go there are offered for deletion`() async throws {
    let directory = try TemporaryDirectory()
    let fixture = try await Fixture(in: directory, refusing: ["stuck.txt"])
    let file = try directory.createFile("a.txt")
    let stuck = try directory.createFile("stuck.txt")

    await fixture.commands.moveToTrash([file, stuck])

    let trashed = fixture.trash.folder.appending(path: "a.txt")
    #expect(fixture.exists(trashed))
    #expect(fixture.exists(file) == false)
    #expect(fixture.store.originalLocation(of: trashed)?.comparablePath == file.comparablePath)
    #expect(fixture.commands.trashFailures.map(\.comparablePath) == [stuck.comparablePath])
  }

  @Test
  internal func `An item the system only copied into the Trash counts as failed, and the copy goes`() async throws {
    let directory = try TemporaryDirectory()
    let trashFolder = try directory.createFolder("CopyTrash")
    let file = try directory.createFile("system.plist", contents: "s")
    // As for a protected original: the system copies the item into the Trash and cannot delete the original.
    let service = TrashService { urls in
      var trashed: [URL: URL] = [:]
      for url in urls {
        let copy = trashFolder.appending(path: url.lastPathComponent)
        try? FileManager.default.copyItem(at: url, to: copy)
        trashed[url] = copy
      }
      return trashed
    }

    let result = await service.moveToTrash([file])

    #expect(result.moves.isEmpty)
    #expect(result.failures.map(\.comparablePath) == [file.comparablePath])
    #expect(try FileManager.default.contentsOfDirectory(atPath: trashFolder.path(percentEncoded: false)).isEmpty)
    #expect(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
  }

  @Test
  internal func `Items in locations macOS protects are refused without trying the Trash`() async throws {
    let calls = RecycleCalls()
    let service = TrashService { urls in
      calls.record(urls)
      return [:]
    }
    let protected = URL(filePath: "/System/Library/Accessibility/AccessibilityDefinitions.plist")

    let result = await service.moveToTrash([protected])

    #expect(result.unchangeable == [protected])
    #expect(result.failures.isEmpty)
    #expect(calls.count == 0)
  }

  @Test
  internal func `Undoing Move to Trash puts the items back, and Redo moves them to the Trash again`() async throws {
    let directory = try TemporaryDirectory()
    let fixture = try await Fixture(in: directory)
    let file = try directory.createFile("a.txt")

    try await fixture.inUndoGroup {
      await fixture.commands.moveToTrash([file])
    }
    let actionName = fixture.undoManager.undoActionName
    fixture.undoManager.undo()
    await FileUndoQueue.shared.waitUntilIdle()
    let isBack = fixture.exists(file)
    fixture.undoManager.redo()
    await FileUndoQueue.shared.waitUntilIdle()

    #expect(actionName == String(localized: "Move to Trash"))
    #expect(isBack)
    #expect(fixture.exists(file) == false)
    #expect(fixture.exists(fixture.trash.folder.appending(path: "a.txt")))
  }

  @Test
  internal func `Put Back returns items to their original folder`() async throws {
    let directory = try TemporaryDirectory()
    let fixture = try await Fixture(in: directory)
    try directory.createFolder("Documents")
    let file = try directory.createFile("Documents/draft.txt")
    await fixture.commands.moveToTrash([file])
    let trashed = fixture.trash.folder.appending(path: "draft.txt")

    let canPutBack = fixture.commands.canPutBack([trashed])
    await fixture.commands.putBack([trashed])

    #expect(canPutBack)
    #expect(fixture.exists(file))
    #expect(fixture.store.originalLocation(of: trashed) == nil)
  }

  // MARK: - Creating

  @Test
  internal func `New Folder creates the folder in the tab's folder, and Undo moves it to the Trash`() async throws {
    let directory = try TemporaryDirectory()
    let fixture = try await Fixture(in: directory)
    let name = UniqueNameGenerator().untitledFolderName(existingNames: [Fixture.trashName])

    try await fixture.inUndoGroup {
      await fixture.commands.newFolder()
    }
    let folder = directory.url.appending(path: name)
    let created = fixture.exists(folder)
    let actionName = fixture.undoManager.undoActionName
    fixture.undoManager.undo()
    await FileUndoQueue.shared.waitUntilIdle()

    #expect(created)
    #expect(actionName == String(localized: "New Folder"))
    #expect(fixture.exists(folder) == false)
    #expect(fixture.exists(fixture.trash.folder.appending(path: name)))
  }

  @Test
  internal func `New Folder with Selection moves the items into a new folder, and Undo moves them out again`() async throws {
    let directory = try TemporaryDirectory()
    let fixture = try await Fixture(in: directory)
    let first = try directory.createFile("a.txt")
    let second = try directory.createFile("b.txt")
    let name = UniqueNameGenerator().untitledFolderName(existingNames: [Fixture.trashName, "a.txt", "b.txt"])

    try await fixture.inUndoGroup {
      await fixture.commands.newFolderWithSelection([first, second])
    }
    let folder = directory.url.appending(path: name)
    let grouped = try fixture.contents(of: folder)
    fixture.undoManager.undo()
    await FileUndoQueue.shared.waitUntilIdle()

    #expect(grouped == ["a.txt", "b.txt"])
    #expect(fixture.exists(first) && fixture.exists(second))
    #expect(fixture.exists(folder) == false)
  }

  @Test
  internal func `Duplicate copies items into their folder under the localized copy name`() async throws {
    let directory = try TemporaryDirectory()
    let fixture = try await Fixture(in: directory)
    let plan = try directory.createFile("plan.key", contents: "p")
    let names = UniqueNameGenerator()
    let firstName = names.duplicateName(of: "plan.key", isFolder: false, existingNames: ["plan.key"])
    let secondName = names.duplicateName(of: "plan.key", isFolder: false, existingNames: ["plan.key", firstName])

    try await fixture.inUndoGroup {
      await fixture.commands.duplicate([plan])
      await fixture.commands.duplicate([plan])
    }

    #expect(fixture.exists(directory.url.appending(path: firstName)))
    #expect(fixture.exists(directory.url.appending(path: secondName)))
    #expect(fixture.undoManager.undoActionName == String(localized: "Duplicate"))
  }

  // MARK: - Copying and Moving

  @Test
  internal func `Paste copies items, but moves the items cut last`() async throws {
    let directory = try TemporaryDirectory()
    let fixture = try await Fixture(in: directory)
    try directory.createFolder("Source")
    let copied = try directory.createFile("Source/a.txt")
    let cut = try directory.createFile("Source/b.txt")

    await fixture.commands.paste([copied])
    fixture.clipboard.markCut([cut])
    let isDimmed = fixture.clipboard.isCut(cut)
    await fixture.commands.paste([cut])

    #expect(fixture.exists(copied))
    #expect(fixture.exists(directory.url.appending(path: "a.txt")))
    #expect(isDimmed)
    #expect(fixture.exists(cut) == false)
    #expect(fixture.exists(directory.url.appending(path: "b.txt")))
    #expect(fixture.clipboard.cutPaths.isEmpty)
  }

  @Test
  internal func `Undoing a move puts the item back under its original name`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("Source")
    let file = try directory.createFile("Source/report.pdf", contents: "new")
    try directory.createFile("report.pdf", contents: "old")
    let fixture = try await Fixture(in: directory, pasteboardURLs: { [file] })
    let actionName = FileCommandModel.actionName(for: .move, of: [file])

    // The destination has a report.pdf, so the moved one is kept as "report 2.pdf" without asking.
    var progressTransfers: [ItemMove] = []
    try await fixture.inUndoGroup {
      let id = await fixture.operations.enqueue(
        FileOperationRequest(kind: .move, sources: [file], destination: directory.url, conflictPolicy: .keepBoth))
      progressTransfers = await fixture.operations.waitUntilFinished(id)?.transfers ?? []
      fixture.commands.undoRegistrar.registerMove(progressTransfers, actionName: actionName)
    }
    let moved = directory.url.appending(path: "report 2.pdf")
    let wasMoved = fixture.exists(moved)
    fixture.undoManager.undo()
    await FileUndoQueue.shared.waitUntilIdle()

    #expect(progressTransfers.map(\.to.lastPathComponent) == ["report 2.pdf"])
    #expect(wasMoved)
    #expect(fixture.exists(file))
    #expect(fixture.exists(moved) == false)
    let name = "report.pdf"
    #expect(actionName == String(localized: "Move of “\(name)”"))
  }

  @Test
  internal func `Move Items Here reads the pasteboard and ends a cut`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("Source")
    let file = try directory.createFile("Source/a.txt")
    let fixture = try await Fixture(in: directory, pasteboardURLs: { [file] })
    fixture.clipboard.markCut([file])

    try await fixture.inUndoGroup {
      await fixture.commands.moveItemsHere()
    }

    #expect(fixture.exists(directory.url.appending(path: "a.txt")))
    #expect(fixture.exists(file) == false)
    #expect(fixture.clipboard.cutPaths.isEmpty)
    #expect(fixture.undoManager.undoActionName == FileCommandModel.actionName(for: .move, of: [file]))
  }

  @Test
  internal func `Move Items to Current Folder moves shelf items, which then point to their new places`() async throws {
    let directory = try TemporaryDirectory()
    let fixture = try await Fixture(in: directory)
    try directory.createFolder("A")
    try directory.createFolder("B")
    let first = try directory.createFile("A/one.txt")
    let second = try directory.createFile("B/two.txt")
    let shelf = ShelfStore(storage: JSONFileStorage(fileURL: directory.url.appending(path: "Shelf.json")))
    await shelf.loadIfNeeded()
    await shelf.add([first, second])

    await fixture.commands.transferShelfItems([first, second], kind: .move, shelf: shelf)

    let moved = ["one.txt", "two.txt"].map { directory.url.appending(path: $0).comparablePath }
    #expect(shelf.items.map(\.url.comparablePath) == moved)
    #expect(fixture.exists(first) == false)
    #expect(fixture.exists(second) == false)
  }

  @Test
  internal func `Undoing a copy moves the copies to the Trash, and Redo puts them back`() async throws {
    let directory = try TemporaryDirectory()
    let fixture = try await Fixture(in: directory)
    try directory.createFolder("Source")
    try directory.createFolder("Target")
    let first = try directory.createFile("Source/a.txt")
    let second = try directory.createFile("Source/b.txt")
    let target = directory.url.appending(path: "Target")

    try await fixture.inUndoGroup {
      await fixture.commands.transfer([first, second], to: target, kind: .copy)
    }
    let actionName = fixture.undoManager.undoActionName
    fixture.undoManager.undo()
    await FileUndoQueue.shared.waitUntilIdle()
    let afterUndo = try fixture.contents(of: target)
    fixture.undoManager.redo()
    await FileUndoQueue.shared.waitUntilIdle()

    #expect(actionName == String(localized: "Copy of \(2) Items"))
    #expect(afterUndo.isEmpty)
    #expect(try fixture.contents(of: target) == ["a.txt", "b.txt"])
    #expect(fixture.exists(first) && fixture.exists(second))
  }

  // MARK: - Drag and Drop

  @Test
  internal func `Dropping moves items on the same volume, and with option and command makes aliases`() async throws {
    let directory = try TemporaryDirectory()
    let fixture = try await Fixture(in: directory)
    let target = try directory.createFolder("Target")
    let moved = try directory.createFile("a.txt")
    let original = try directory.createFile("b.txt")
    let aliasName = UniqueNameGenerator().aliasName(of: "b.txt", existingNames: [])

    try await fixture.inUndoGroup {
      await fixture.commands.drop([moved], into: target, keys: .none)
      await fixture.commands.drop([original], into: target, keys: .alias)
    }

    #expect(fixture.exists(target.appending(path: "a.txt")))
    #expect(fixture.exists(moved) == false)
    #expect(fixture.exists(original))
    #expect(try target.appending(path: aliasName).resourceValues(forKeys: [.isAliasFileKey]).isAliasFile == true)
  }

  @Test
  internal func `Dropping a folder into its own folder is refused with the reason`() async throws {
    let directory = try TemporaryDirectory()
    let fixture = try await Fixture(in: directory)
    let folder = try directory.createFolder("A")
    let subfolder = try directory.createFolder("A/B")

    await fixture.commands.drop([folder], into: subfolder, keys: .none)

    #expect(fixture.commands.failure?.message == String(localized: "A folder can’t be copied or moved into itself."))
    #expect(try fixture.contents(of: subfolder).isEmpty)
  }

  // MARK: - Archives

  @Test
  internal func `Compress and Expand create items next to the originals, and Undo moves them to the Trash`() async throws {
    let directory = try TemporaryDirectory()
    let fixture = try await Fixture(in: directory)
    try directory.createFolder("Source")
    let folder = try directory.createFolder("Source/Photos")
    try directory.createFile("Source/Photos/a.jpg", contents: "a")
    let archive = directory.url.appending(path: "Source/Photos.zip")

    try await fixture.inUndoGroup {
      await fixture.commands.compress([folder], format: .zip)
    }
    let compressed = fixture.exists(archive)
    try FileManager.default.removeItem(at: folder)
    try await fixture.inUndoGroup {
      await fixture.commands.expand([archive])
    }
    let expanded = fixture.exists(folder)
    let actionName = fixture.undoManager.undoActionName
    fixture.undoManager.undo()
    await FileUndoQueue.shared.waitUntilIdle()

    #expect(compressed)
    #expect(expanded)
    #expect(actionName == String(localized: "Expand"))
    #expect(fixture.exists(folder) == false)
    #expect(fixture.exists(fixture.trash.folder.appending(path: "Photos")))
  }

  // MARK: - Renaming

  @Test
  internal func `Renaming asks before changing an extension, and Undo renames back`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFile("notes.txt")
    let items = try await FileSystemService().contentsOfDirectory(at: directory.url, includingHiddenItems: false)
    let fixture = try await Fixture(in: directory, items: items)
    let notes = try #require(items.first { $0.name == "notes.txt" })
    let warns = SettingsStore().value(for: SettingsKeys.warnsBeforeChangingExtension)

    let unconfirmed = await fixture.tab.commitRename(of: notes, to: "notes.md")
    var confirmed: TabModel.RenameResult?
    try await fixture.inUndoGroup {
      confirmed = await fixture.tab.commitRename(of: notes, to: "notes.md", confirmsExtensionChange: true)
    }
    let renamed = fixture.exists(directory.url.appending(path: "notes.md"))
    fixture.undoManager.undo()
    await FileUndoQueue.shared.waitUntilIdle()

    #expect(unconfirmed == (warns ? .needsExtensionConfirmation(oldExtension: "txt", newExtension: "md") : .renamed))
    #expect(confirmed == .renamed || warns == false)
    #expect(renamed)
    #expect(fixture.exists(directory.url.appending(path: "notes.txt")))
  }

  @Test
  internal func `A click on the selected name starts renaming after a pause, unless the selection changes`() async throws {
    let first = FileItem(url: URL(filePath: "/tmp/a.txt"), size: 1)
    let second = FileItem(url: URL(filePath: "/tmp/b.txt"), size: 1)
    let tab = TabModel(location: .tag("Test"), listing: DirectoryListing(staticItems: [first, second]))
    tab.select(first.id)

    tab.scheduleRename(of: first, after: .milliseconds(50))
    try await Task.sleep(for: .milliseconds(300))
    let renamed = tab.renamingItemID
    tab.cancelRename()
    tab.scheduleRename(of: first, after: .milliseconds(50))
    tab.select(second.id)
    tab.selectionDidChange()
    try await Task.sleep(for: .milliseconds(300))

    #expect(renamed == first.id)
    #expect(tab.renamingItemID == nil)
  }

  // MARK: - Batch Rename

  @Test
  internal func `A batch rename with exchanged names is undone in one step`() async throws {
    let directory = try TemporaryDirectory()
    let fixture = try await Fixture(in: directory)
    let a = try directory.createFile("a.txt", contents: "A")
    let b = try directory.createFile("b.txt", contents: "B")
    let c = try directory.createFile("c.txt", contents: "C")
    let moves = [ItemMove(from: a, to: b), ItemMove(from: b, to: a), ItemMove(from: c, to: directory.url.appending(path: "d.txt"))]

    var succeeded = false
    try await fixture.inUndoGroup {
      succeeded = await fixture.commands.batchRename(moves)
    }
    let renamed = try fixture.contents(of: directory.url)
    let actionName = fixture.undoManager.undoActionName
    fixture.undoManager.undo()
    await FileUndoQueue.shared.waitUntilIdle()

    #expect(succeeded)
    #expect(renamed.contains("d.txt"))
    #expect(try String(contentsOf: a, encoding: .utf8) == "A")
    #expect(try String(contentsOf: b, encoding: .utf8) == "B")
    #expect(fixture.exists(c))
    #expect(actionName == String(localized: "Batch Rename"))
  }

  @Test
  internal func `A failed batch rename reports the item and renames nothing`() async throws {
    let directory = try TemporaryDirectory()
    let fixture = try await Fixture(in: directory)
    let a = try directory.createFile("a.txt")
    try directory.createFile("taken.txt")

    let succeeded = await fixture.commands.batchRename([ItemMove(from: a, to: directory.url.appending(path: "taken.txt"))])

    #expect(succeeded == false)
    #expect(fixture.commands.failure != nil)
    #expect(fixture.exists(a))
  }
}

// MARK: - Fixture

/// A window on a temporary folder with commands that use a fake Trash and their own Put Back store.
private struct Fixture {

  static let trashName = ".FakeTrash"

  let trash: FakeTrash
  let store: PutBackStore
  let commands: FileCommandModel
  let tab: TabModel
  let window: BrowserWindowModel
  let undoManager: UndoManager
  let clipboard = FileClipboard()
  let operations = OperationQueueModel(engine: FileOperationEngine())

  init(
    in directory: TemporaryDirectory,
    refusing refusedNames: Set<String> = [],
    items: [FileItem] = [],
    pasteboardURLs: @escaping () -> [URL] = { [] }
  ) async throws {
    trash = FakeTrash(folder: try directory.createFolder(Self.trashName), refusedNames: refusedNames)
    store = PutBackStore(storage: JSONFileStorage(fileURL: directory.url.appending(path: "PutBack.json")))
    await store.loadIfNeeded()
    commands = FileCommandModel(
      trash: TrashService(recycle: trash.recycle),
      putBackStore: store,
      operations: operations,
      volumes: { [] },
      clipboard: clipboard,
      pasteboardURLs: pasteboardURLs)
    tab = TabModel(location: .folder(try FileReference(url: directory.url)), listing: DirectoryListing(staticItems: items))
    window = BrowserWindowModel(primaryPane: PaneModel(tab: tab), fileCommands: commands)
    undoManager = UndoManager()
    undoManager.groupsByEvent = false
    commands.undoManager = undoManager
  }

  /// Runs `body` inside one undo group.
  func inUndoGroup(_ body: () async throws -> Void) async throws {
    undoManager.beginUndoGrouping()
    try await body()
    undoManager.endUndoGrouping()
  }

  func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
  }

  func contents(of folder: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).sorted()
  }
}

/// Moves items into a folder, as the Trash does, and refuses some names, as a volume without a Trash does.
nonisolated private final class FakeTrash: Sendable {

  let folder: URL
  let refusedNames: Set<String>

  init(folder: URL, refusedNames: Set<String>) {
    self.folder = folder
    self.refusedNames = refusedNames
  }

  @Sendable
  func recycle(_ urls: [URL]) async -> [URL: URL] {
    var trashed: [URL: URL] = [:]
    for url in urls where refusedNames.contains(url.lastPathComponent) == false {
      let target = folder.appending(path: url.lastPathComponent)
      if (try? FileManager.default.moveItem(at: url, to: target)) != nil {
        trashed[url] = target
      }
    }
    return trashed
  }
}

/// Counts the items handed to `recycle`.
nonisolated private final class RecycleCalls: Sendable {

  private let urls = Mutex<[URL]>([])

  var count: Int {
    urls.withLock { $0.count }
  }

  func record(_ newURLs: [URL]) {
    urls.withLock { $0 += newURLs }
  }
}

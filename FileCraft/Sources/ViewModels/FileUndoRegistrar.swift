/*
 * FileUndoRegistrar.swift
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

/// Registers file changes with a window's undo manager, so that Edit > Undo reverts them and Edit > Redo repeats
/// them, named after the change (design decision D10).
///
/// Undoing registers the opposite action right away, while the undo manager is still undoing, so that it becomes
/// the redo action. The file system work follows asynchronously, one change after the other. Undoing a creation
/// moves the created items to the Trash, so nothing is ever deleted by Undo.
internal struct FileUndoRegistrar {

  // MARK: - Properties

  internal let undoManager: UndoManager?
  internal var trash = TrashService()
  internal var putBackStore: PutBackStore = .shared
  internal var queue: FileUndoQueue = .shared
  /// Moves items back across volumes.
  internal var operations: OperationQueueModel = .shared

  // MARK: - Registering

  /// Registers items that `actionName` created: Undo moves them to the Trash, Redo puts them back.
  internal func registerCreation(of urls: [URL], actionName: String) {
    guard urls.isEmpty == false else {
      return
    }
    registerTrashing(urls, actionName: actionName)
  }

  /// Registers items that were moved to the Trash: Undo puts them back, Redo moves them to the Trash again.
  internal func registerTrash(of moves: [ItemMove], actionName: String) {
    guard moves.isEmpty == false else {
      return
    }
    registerPuttingBack(queue.run { moves }, originals: moves.map(\.from), actionName: actionName)
  }

  /// Registers moved items: Undo moves them back to their original places and names, Redo moves them again.
  ///
  /// - Parameter moves: From each item's original place to its new place.
  internal func registerMove(_ moves: [ItemMove], actionName: String) {
    guard moves.isEmpty == false else {
      return
    }
    let registrar = self
    register(actionName: actionName) {
      let back = moves.map(\.reversed)
      registrar.registerMove(back, actionName: actionName)
      _ = registrar.queue.run {
        await registrar.move(back)
      }
    }
  }

  /// Registers Expand as one undo step: Undo moves the expanded items to the Trash and puts back the archives
  /// that the setting moved to the Trash.
  internal func registerExpansion(created: [URL], trashedArchives: [ItemMove]) {
    guard let undoManager, created.isEmpty == false || trashedArchives.isEmpty == false else {
      return
    }
    let actionName = String(localized: "Expand")
    undoManager.beginUndoGrouping()
    registerCreation(of: created, actionName: actionName)
    registerTrash(of: trashedArchives, actionName: actionName)
    undoManager.setActionName(actionName)
    undoManager.endUndoGrouping()
  }

  /// Registers a rename from `url` to `newURL`.
  internal func registerRename(of url: URL, to newURL: URL) {
    let registrar = self
    register(actionName: String(localized: "Rename")) {
      registrar.registerRename(of: newURL, to: url)
      _ = registrar.queue.run {
        _ = try? await RenameService().rename(newURL, to: url.lastPathComponent)
      }
    }
  }

  /// Registers a batch rename as one action; undoing renames all items back, which handles exchanged names too.
  ///
  /// - Parameter moves: From each item's old URL to its new URL.
  internal func registerBatchRename(_ moves: [ItemMove]) {
    let registrar = self
    register(actionName: String(localized: "Batch Rename")) {
      let reversed = moves.map(\.reversed)
      registrar.registerBatchRename(reversed)
      _ = registrar.queue.run {
        try? await BatchRenamer().rename(reversed)
      }
    }
  }

  /// Registers New Folder with Selection: Undo moves the items out of `folder` again and moves the folder to the
  /// Trash; Redo puts the folder back and moves the items into it.
  ///
  /// - Parameter moves: From the items' original places into `folder`.
  internal func registerGrouping(into folder: URL, moves: [ItemMove]) {
    let registrar = self
    register(actionName: String(localized: "New Folder with Selection")) {
      let ungrouping = registrar.queue.run { () -> [ItemMove] in
        await Self.rename(moves.map(\.reversed))
        return await registrar.moveToTrash([folder])
      }
      registrar.registerRegrouping(after: ungrouping, into: folder, moves: moves)
    }
  }

  // MARK: - Private

  /// The items are at their original places; undoing moves them to the Trash.
  private func registerTrashing(_ originals: [URL], actionName: String) {
    let registrar = self
    register(actionName: actionName) {
      let trashing = registrar.queue.run { await registrar.moveToTrash(originals) }
      registrar.registerPuttingBack(trashing, originals: originals, actionName: actionName)
    }
  }

  /// The items are in the Trash once `trashing` finished; undoing puts them back.
  private func registerPuttingBack(_ trashing: Task<[ItemMove], Never>, originals: [URL], actionName: String) {
    let registrar = self
    register(actionName: actionName) {
      registrar.registerTrashing(originals, actionName: actionName)
      _ = registrar.queue.run {
        await registrar.putBack(await trashing.value)
      }
    }
  }

  private func registerRegrouping(after ungrouping: Task<[ItemMove], Never>, into folder: URL, moves: [ItemMove]) {
    let registrar = self
    register(actionName: String(localized: "New Folder with Selection")) {
      registrar.registerGrouping(into: folder, moves: moves)
      _ = registrar.queue.run {
        await registrar.putBack(await ungrouping.value)
        await Self.rename(moves)
      }
    }
  }

  /// Registers `undo` under `actionName`. Outside an open undo group, which only an undo manager without
  /// automatic grouping can have, the registration gets a group of its own instead of raising an exception.
  private func register(actionName: String, undo: @escaping () -> Void) {
    guard let undoManager else {
      return
    }
    let needsGroup = undoManager.groupingLevel == 0 && undoManager.groupsByEvent == false
      && undoManager.isUndoing == false && undoManager.isRedoing == false
    if needsGroup {
      undoManager.beginUndoGrouping()
    }
    undoManager.registerUndo(withTarget: FileUndoQueue.shared) { _ in
      undo()
    }
    undoManager.setActionName(actionName)
    if needsGroup {
      undoManager.endUndoGrouping()
    }
  }

  private func moveToTrash(_ urls: [URL]) async -> [ItemMove] {
    let result = await trash.moveToTrash(urls)
    putBackStore.record(result.moves)
    return result.moves
  }

  private func putBack(_ moves: [ItemMove]) async {
    let failed = Set(await trash.putBack(moves))
    putBackStore.remove(trashed: moves.filter { failed.contains($0) == false }.map(\.to))
  }

  /// Moves items to exact places: within a volume as renames, across volumes through the Operations queue.
  private func move(_ moves: [ItemMove]) async {
    let acrossVolumes = await Self.renameWithinVolumes(moves)
    let byFolder = Dictionary(grouping: acrossVolumes) { $0.to.deletingLastPathComponent().comparablePath }
    for (_, group) in byFolder.sorted(by: { $0.key < $1.key }) {
      guard let folder = group.first?.to.deletingLastPathComponent() else {
        continue
      }
      let id = await operations.enqueue(FileOperationRequest(kind: .move, sources: group.map(\.from), destination: folder))
      _ = await operations.waitUntilFinished(id)
    }
  }

  /// Renames the moves within their volumes and returns those that cross volumes.
  @concurrent
  private static func renameWithinVolumes(_ moves: [ItemMove]) async -> [ItemMove] {
    moves.filter { move in
      (try? FileOperationWorker.renameWithinVolume(move.from, move.to)) == false
    }
  }

  @concurrent
  private static func rename(_ moves: [ItemMove]) async {
    for move in moves {
      _ = try? FileOperationWorker.renameWithinVolume(move.from, move.to)
    }
  }
}

/// Runs the file work of undo and redo one change after the other, so that a quick redo waits for its undo.
internal final class FileUndoQueue {

  // MARK: - Properties

  /// The queue of the app; it is also the target of the registered undo actions.
  internal static let shared = FileUndoQueue()

  private var last: Task<Void, Never>?

  // MARK: - Running

  /// Runs `work` after all work queued before it.
  @discardableResult
  internal func run<Result: Sendable>(_ work: @escaping () async -> Result) -> Task<Result, Never> {
    let previous = last
    let task = Task {
      await previous?.value
      return await work()
    }
    last = Task {
      _ = await task.value
    }
    return task
  }

  /// Waits until all queued work has finished, for tests.
  internal func waitUntilIdle() async {
    await last?.value
  }
}

/*
 * FileOperationWorker.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-03.
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

import Darwin
import Foundation

/// The number of items and bytes of one source item, counted before the work starts.
nonisolated internal struct SourceTotals: Hashable, Sendable {
  internal let items: Int
  internal let bytes: Int64
}

/// Does the work of one copy or move request, item by item. It blocks, so it runs on a thread of its own.
nonisolated internal enum FileOperationWorker {

  // MARK: - Types

  /// Moves an item within its volume; returns false when source and destination are on different volumes.
  internal typealias RenameWithinVolume = @Sendable (URL, URL) throws -> Bool
  /// Removes an existing item that Replace overwrites.
  internal typealias DiscardExisting = @Sendable (URL) throws -> Void
  /// Puts a question to the user and returns the answer, or nil when the operation was cancelled meanwhile.
  internal typealias AskUser = @Sendable (OperationQuestion.Topic) -> OperationAnswer?
  /// Runs a job through the privileged helper for Authenticate and Retry and waits until it finished.
  internal typealias RunPrivileged = @Sendable (HelperJob, OperationControl) throws -> Void

  // MARK: - Work

  /// Copies or moves each source of `request` into its destination folder.
  ///
  /// Name conflicts are resolved with the request's policy or by asking; a failed item, also one inside a folder,
  /// is retried, skipped or stops the operation as the user answers. A move across volumes copies each source item
  /// and deletes it only after everything inside it was copied.
  ///
  /// - Parameter ask: Answers the questions; by default they go to the user through `control`.
  internal static func perform(
    _ request: FileOperationRequest,
    totals: [SourceTotals],
    control: OperationControl,
    renameWithinVolume: @escaping RenameWithinVolume = Self.renameWithinVolume,
    discardExisting: @escaping DiscardExisting = Self.moveToTrash,
    ask: AskUser? = nil,
    runPrivileged: @escaping RunPrivileged = { try PrivilegedRunner().runBlocking($0, control: $1) }
  ) {
    let run = OperationRun(
      request: request,
      control: control,
      renameWithinVolume: renameWithinVolume,
      discardExisting: discardExisting,
      ask: ask ?? { control.ask($0) },
      runPrivileged: runPrivileged)
    run.perform(totals: totals)
  }

  /// Moves `source` to `destination` with `rename(2)` semantics and without replacing anything.
  ///
  /// - Returns: false when the destination is on another volume.
  @Sendable
  internal static func renameWithinVolume(_ source: URL, _ destination: URL) throws -> Bool {
    let code: Int32 = source.withUnsafeFileSystemRepresentation { sourcePath in
      destination.withUnsafeFileSystemRepresentation { destinationPath in
        guard let sourcePath, let destinationPath else {
          return EINVAL
        }
        return renamex_np(sourcePath, destinationPath, UInt32(RENAME_EXCL)) == 0 ? 0 : errno
      }
    }
    if code == 0 {
      return true
    }
    if code == EXDEV {
      return false
    }
    throw OperationFailure.error(code: code, item: source)
  }

  @Sendable
  internal static func moveToTrash(_ url: URL) throws {
    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
  }
}

/// One run of `FileOperationWorker`: the request and the answers that apply to all later questions. It lives on the
/// operation's thread only.
nonisolated private final class OperationRun {

  // MARK: - Types

  /// What a conflict is about, which decides the answers for all conflicts that apply to it.
  private enum ConflictKind: Hashable {
    case files
    case folders
    /// A file and a folder.
    case mixed

    init(source: ItemSummary, existing: ItemSummary) {
      switch (source.isFolder, existing.isFolder) {
      case (true, true):
        self = .folders
      case (false, false):
        self = .files
      default:
        self = .mixed
      }
    }
  }

  // MARK: - Properties

  private let request: FileOperationRequest
  private let control: OperationControl
  private let renameWithinVolume: FileOperationWorker.RenameWithinVolume
  private let discardExisting: FileOperationWorker.DiscardExisting
  private let ask: FileOperationWorker.AskUser
  private let runPrivileged: FileOperationWorker.RunPrivileged
  /// Whether the last successful `attempt` went through the privileged helper.
  private var usedHelper = false
  /// Choices made with "Apply to all conflicts", by kind of conflict.
  private var standingChoices: [ConflictKind: ConflictChoice] = [:]
  /// Whether Skip was chosen with "Apply to all errors".
  private var skipsFailures = false
  /// Whether the current source was merged into an existing folder.
  private var placedByMerging = false

  // MARK: - Initialization

  init(
    request: FileOperationRequest,
    control: OperationControl,
    renameWithinVolume: @escaping FileOperationWorker.RenameWithinVolume,
    discardExisting: @escaping FileOperationWorker.DiscardExisting,
    ask: @escaping FileOperationWorker.AskUser,
    runPrivileged: @escaping FileOperationWorker.RunPrivileged
  ) {
    self.request = request
    self.control = control
    self.renameWithinVolume = renameWithinVolume
    self.discardExisting = discardExisting
    self.ask = ask
    self.runPrivileged = runPrivileged
  }

  // MARK: - Running

  func perform(totals: [SourceTotals]) {
    // All sources go into one archive.
    if request.kind == .compress {
      compressAll(totals: totals)
      return
    }
    for (index, source) in request.sources.enumerated() {
      guard control.waitWhilePaused() else {
        return
      }
      let total = totals.indices.contains(index) ? totals[index] : SourceTotals(items: 1, bytes: 0)
      control.update {
        $0.currentItemName = source.lastPathComponent
        $0.sourceItems = 0
        $0.sourceBytes = 0
        $0.fileBytes = 0
      }
      do {
        let result: URL?
        placedByMerging = false
        switch request.kind {
        case .copy, .move:
          result = try place(source, into: request.destination)
        case .delete:
          _ = try deleteTree(source)
          result = nil
        case .expand:
          let expanded = try expandArchive(source)
          control.update { $0.results.append(contentsOf: expanded) }
          result = nil
        case .compress:
          result = nil
        }
        complete(total)
        if let result {
          // A merged folder existed before, so undo must not move it; only new items count as transfers.
          let isMerged = placedByMerging
          control.update {
            $0.results.append(result)
            if isMerged == false {
              $0.transfers.append(ItemMove(from: source, to: result))
            }
          }
        }
      } catch {
        // Cancelled or stopped; the partial copy is already removed.
        return
      }
    }
  }

  // MARK: - Placing Items

  /// Copies or moves `source` into `folder`, resolving a name conflict first.
  ///
  /// - Returns: The item at the destination, or nil when the source was skipped.
  /// - Throws: `CancellationError` when the operation was cancelled or stopped.
  private func place(_ source: URL, into folder: URL) throws -> URL? {
    let target = folder.appending(path: source.lastPathComponent)
    guard Self.exists(target) else {
      return try transfer(source, to: target) ? target : nil
    }
    if target.comparablePath == source.comparablePath {
      // Moving an item into its own folder changes nothing; copying it there makes a duplicate, as in Finder.
      guard request.kind == .copy else {
        return nil
      }
      let name = UniqueNameGenerator().duplicateName(
        of: source.lastPathComponent, isFolder: FileCopier.isDirectory(source), existingNames: Self.names(in: folder))
      let duplicate = folder.appending(path: name)
      return try transfer(source, to: duplicate) ? duplicate : nil
    }
    switch try decideConflict(between: source, and: target) {
    case .replace:
      let discardExisting = discardExisting
      guard try attempt(target, target: target, { try discardExisting(target) }) else {
        return nil
      }
      return try transfer(source, to: target) ? target : nil
    case .keepBoth:
      let name = UniqueNameGenerator().availableName(
        for: source.lastPathComponent, isFolder: FileCopier.isDirectory(source), existingNames: Self.names(in: folder))
      let renamed = folder.appending(path: name)
      return try transfer(source, to: renamed) ? renamed : nil
    case .skip:
      return nil
    case .stop:
      control.cancel()
      throw CancellationError()
    case .merge:
      placedByMerging = true
      try merge(source, into: target)
      return target
    }
  }

  /// Copies or moves `source` to `target`, which does not exist. A moved or copied application may then run in place,
  /// as after a move in Finder, instead of from a temporary copy (App Translocation).
  ///
  /// - Returns: false when the item was skipped after a failure.
  private func transfer(_ source: URL, to target: URL) throws -> Bool {
    let isTransferred = try transferItem(source, to: target)
    if isTransferred, Quarantine.isApplicationBundle(target) {
      // An application the helper placed belongs to root, so this may fail; the application is in place either way.
      _ = try? Quarantine.allowRunningInPlace(at: target)
    }
    return isTransferred
  }

  private func transferItem(_ source: URL, to target: URL) throws -> Bool {
    switch request.kind {
    case .delete, .compress, .expand:
      // These go through `deleteTree(_:)`, `compressAll(totals:)` and `expandArchive(_:)` instead.
      return false
    case .copy:
      return try copyTree(source, to: target)
    case .move:
      var isRenamed = false
      let renameWithinVolume = renameWithinVolume
      let move = HelperJob.move(source: Self.path(source), destination: Self.path(target))
      guard try attempt(source, target: target, privileged: move, { isRenamed = try renameWithinVolume(source, target) }) else {
        return false
      }
      if isRenamed || usedHelper {
        return true
      }
      // Across volumes the source goes only when everything inside it was copied.
      let failuresBefore = control.snapshot.errors.count
      guard try copyTree(source, to: target), control.snapshot.errors.count == failuresBefore else {
        return false
      }
      let deletion = HelperJob.delete(path: Self.path(source))
      return try attempt(source, target: target, privileged: deletion, { try FileManager.default.removeItem(at: source) })
    }
  }

  /// Copies the contents of the folder `source` into the existing folder `target`, or moves them there, resolving
  /// conflicts between the contents the same way. A moved folder is removed when nothing was left in it.
  private func merge(_ source: URL, into target: URL) throws {
    var names: [String] = []
    guard try attempt(source, target: target, { names = try FileCopier.childNames(of: source) }) else {
      return
    }
    for name in names {
      guard control.waitWhilePaused() else {
        throw CancellationError()
      }
      _ = try place(source.appending(path: name), into: target)
    }
    control.update { $0.sourceItems += 1 }
    if request.kind == .move {
      // Skipped items stay in the source folder, which then stays too.
      _ = try attempt(source, target: target, { try FileCopier.removeFolderIfEmpty(at: source) })
    }
  }

  // MARK: - Copying

  /// Copies `source` to `target`, which does not exist; the items inside a folder are copied one by one, and the
  /// folder's own permissions and dates follow after them.
  ///
  /// - Returns: false when the item was skipped after a failure.
  private func copyTree(_ source: URL, to target: URL) throws -> Bool {
    guard control.waitWhilePaused() else {
      throw CancellationError()
    }
    guard FileCopier.isDirectory(source) else {
      return try copyFile(source, to: target)
    }
    // When the destination folder cannot be created, the helper copies the whole folder.
    let folderCopy = HelperJob.copy(source: Self.path(source), destination: Self.path(target))
    guard try attempt(source, target: target, privileged: folderCopy, { try FileCopier.makeFolder(at: target) }) else {
      return false
    }
    if usedHelper {
      control.update { $0.sourceItems += 1 }
      return true
    }
    do {
      var names: [String] = []
      guard try attempt(source, target: target, { names = try FileCopier.childNames(of: source) }) else {
        FileCopier.removePartialCopy(at: target)
        return false
      }
      for name in names {
        _ = try copyTree(source.appending(path: name), to: target.appending(path: name))
      }
      _ = try attempt(source, target: target, { try FileCopier.copyMetadata(from: source, to: target) })
    } catch {
      // Cancelled or stopped: the partial copy goes.
      FileCopier.removePartialCopy(at: target)
      throw error
    }
    control.update { $0.sourceItems += 1 }
    return true
  }

  /// Copies a file or symbolic link and verifies a copied file when the request asks for it.
  ///
  /// - Returns: false when the item was skipped after a failure.
  private func copyFile(_ source: URL, to target: URL) throws -> Bool {
    let cloning = request.allowsCloning
    let control = control
    let fileCopy = HelperJob.copy(source: Self.path(source), destination: Self.path(target))
    guard try attempt(source, target: target, privileged: fileCopy, { try FileCopier.copyItem(source, to: target, cloning: cloning, control: control) }) else {
      return false
    }
    let sourcePath = source.path(percentEncoded: false)
    if request.verifiesCopies, FileCopier.isRegularFile(source),
      FileVerifier.contentsMatch(sourcePath, target.path(percentEncoded: false)) == false
    {
      control.update { $0.errors.append(FileOperationError(url: source, reason: String(localized: "verification failed"))) }
    }
    let size = FileCopier.fileSize(atPath: sourcePath)
    control.update {
      $0.sourceItems += 1
      $0.sourceBytes += size
      $0.fileBytes = 0
    }
    return true
  }

  // MARK: - Archives

  /// Puts all sources into one archive in the destination folder, named after the single item or "Archive".
  private func compressAll(totals: [SourceTotals]) {
    let sources = request.sources
    guard let first = sources.first else {
      return
    }
    control.update { $0.currentItemName = first.lastPathComponent }
    let folder = request.destination
    let existingNames = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
    let name = UniqueNameGenerator().archiveName(
      forItemNamed: sources.count == 1 ? first.lastPathComponent : nil,
      pathExtension: ArchiveService.pathExtension(of: request.archiveFormat),
      existingNames: existingNames)
    let archive = folder.appending(path: name)
    let format = request.archiveFormat
    let control = control
    do {
      guard try attempt(first, target: archive, { try ArchiveService.compress(sources, into: archive, format: format, control: control) }) else {
        return
      }
    } catch {
      return
    }
    for total in totals {
      complete(total)
    }
    control.update { $0.results.append(archive) }
  }

  /// Expands `archive` into the destination folder.
  ///
  /// - Returns: The expanded top-level items; none when the archive was skipped after a failure.
  private func expandArchive(_ archive: URL) throws -> [URL] {
    var expanded: [URL] = []
    let folder = request.destination
    let control = control
    _ = try attempt(archive, target: folder) {
      expanded = try ArchiveService.expand(archive, into: folder, control: control)
    }
    return expanded
  }

  // MARK: - Deleting

  /// Deletes `item` without using the Trash; a folder's contents go first, and a symbolic link is deleted itself,
  /// never what it points to.
  ///
  /// - Returns: false when the item, or something inside it, was skipped after a failure.
  private func deleteTree(_ item: URL) throws -> Bool {
    guard control.waitWhilePaused() else {
      throw CancellationError()
    }
    guard FileCopier.isDirectory(item) else {
      let size = FileCopier.fileSize(atPath: item.path(percentEncoded: false))
      let deletion = HelperJob.delete(path: Self.path(item))
      guard try attempt(item, target: item, privileged: deletion, { try FileCopier.removeFile(at: item) }) else {
        return false
      }
      control.update {
        $0.sourceItems += 1
        $0.sourceBytes += size
      }
      return true
    }
    var names: [String] = []
    // A folder that cannot be read or emptied is deleted by the helper as a whole.
    let deletion = HelperJob.delete(path: Self.path(item))
    guard try attempt(item, target: item, privileged: deletion, { names = try FileCopier.childNames(of: item) }) else {
      return false
    }
    if usedHelper {
      control.update { $0.sourceItems += 1 }
      return true
    }
    var removedEverything = true
    for name in names {
      removedEverything = try deleteTree(item.appending(path: name)) && removedEverything
    }
    // A skipped item keeps its folder.
    guard removedEverything else {
      return false
    }
    let isRemoved = try attempt(item, target: item, privileged: deletion) {
      guard try FileCopier.removeFolderIfEmpty(at: item) else {
        throw OperationFailure.error(code: ENOTEMPTY, item: item)
      }
    }
    if isRemoved {
      control.update { $0.sourceItems += 1 }
    }
    return isRemoved
  }

  // MARK: - Questions

  /// The choice for a conflict between `source` and the existing `target`: the request's policy, a choice made
  /// for all conflicts of this kind, or the user's answer.
  private func decideConflict(between source: URL, and target: URL) throws -> ConflictChoice {
    switch request.conflictPolicy {
    case .replace:
      return .replace
    case .keepBoth:
      return .keepBoth
    case .skip:
      return .skip
    case .stop:
      return .stop
    case .ask:
      break
    }
    let sourceSummary = ItemSummary(url: source)
    let existingSummary = ItemSummary(url: target)
    let kind = ConflictKind(source: sourceSummary, existing: existingSummary)
    if let choice = standingChoices[kind] {
      return choice
    }
    guard case .conflict(var choice, let appliesToAll)? = ask(.conflict(source: sourceSummary, existing: existingSummary)) else {
      throw CancellationError()
    }
    if choice == .merge && kind != .folders {
      // Only folders merge.
      choice = .keepBoth
    }
    if appliesToAll {
      remember(choice, for: kind)
    }
    return choice
  }

  /// Remembers a choice made for all conflicts. Replace applies only to conflicts between items of the same kind,
  /// so that a folder is never replaced by a file, or a file by a folder, without asking; Merge applies only to
  /// folders.
  private func remember(_ choice: ConflictChoice, for kind: ConflictKind) {
    switch choice {
    case .replace:
      if kind != .mixed {
        standingChoices[kind] = .replace
      }
    case .merge:
      standingChoices[.folders] = .merge
    case .keepBoth, .skip:
      standingChoices = [.files: choice, .folders: choice, .mixed: choice]
    case .stop:
      break
    }
  }

  /// Runs `body` until it succeeds, the user skips `item` or stops the operation. With `job`, a permission failure
  /// offers Authenticate and Retry, which runs `job` through the privileged helper instead; `usedHelper` tells.
  ///
  /// - Parameters:
  ///   - item: The item that a failure is reported for.
  ///   - target: Where the item goes; it names the destination in messages about writing.
  ///   - job: The helper's job that does what `body` does.
  /// - Returns: false when the item was skipped; the failure is then listed in the operation's errors.
  /// - Throws: `CancellationError` when the operation was cancelled or stopped.
  private func attempt(_ item: URL, target: URL, privileged job: HelperJob? = nil, _ body: () throws -> Void) throws -> Bool {
    usedHelper = false
    var failure: (any Error)?
    while true {
      guard control.isCancelled == false else {
        throw CancellationError()
      }
      if failure == nil {
        do {
          try body()
          return true
        } catch is CancellationError {
          throw CancellationError()
        } catch {
          failure = error
        }
      }
      guard let error = failure else {
        continue
      }
      control.update { $0.fileBytes = 0 }
      let reason = OperationFailure.reason(for: error, item: item, target: target)
      if skipsFailures == false {
        let canAuthenticate = job != nil && (OperationFailure.isPermissionError(error) || error is PrivilegedRunner.RunnerError)
        let topic = OperationQuestion.Topic.failure(item: item, reason: reason, isPermissionError: canAuthenticate)
        guard case .failure(let choice, let appliesToAll)? = ask(topic) else {
          throw CancellationError()
        }
        switch choice {
        case .retry:
          failure = nil
          continue
        case .authenticateAndRetry:
          guard let job else {
            failure = nil
            continue
          }
          do {
            try runPrivileged(job, control)
            usedHelper = true
            return true
          } catch is CancellationError {
            throw CancellationError()
          } catch {
            // The helper's reason is shown with the next question.
            failure = error
            continue
          }
        case .stop:
          control.cancel()
          throw CancellationError()
        case .skip:
          skipsFailures = appliesToAll
        }
      }
      control.update { $0.errors.append(FileOperationError(url: item, reason: reason)) }
      return false
    }
  }

  // MARK: - Helpers

  private func complete(_ total: SourceTotals) {
    control.update {
      $0.completedItems += total.items
      $0.completedBytes += total.bytes
      $0.sourceItems = 0
      $0.sourceBytes = 0
      $0.fileBytes = 0
    }
  }

  private static func path(_ url: URL) -> String {
    url.path(percentEncoded: false)
  }

  /// Whether an item, also a broken symbolic link, exists at `url`.
  private static func exists(_ url: URL) -> Bool {
    var status = stat()
    return lstat(url.path(percentEncoded: false), &status) == 0
  }

  private static func names(in folder: URL) -> [String] {
    (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
  }
}

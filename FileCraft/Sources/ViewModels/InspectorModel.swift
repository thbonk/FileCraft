/*
 * InspectorModel.swift
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
import Observation
import UniformTypeIdentifiers

/// A failed inspector edit, shown below the edited field.
nonisolated internal enum InspectorEditError: Hashable, Sendable {
  case invalidName(NameValidationError)
  /// The edit failed with a localized description of the error.
  case failed(String)
  /// The edit failed for lack of rights; Authenticate and Retry makes it through the privileged helper.
  case needsAuthorization(String)
}

/// A change the inspector makes to an item. Each edit knows its inverse, which undo performs.
nonisolated internal enum InspectorEdit: Hashable, Sendable {
  /// Renames the item at the URL from the first name to the second.
  case rename(URL, from: String, to: String)
  /// Replaces the item's tags.
  case tags(URL, from: [String], to: [String])
  case attribute(URL, ItemAttribute, from: Bool, to: Bool)
  /// Changes the item's POSIX permission bits.
  case mode(URL, from: UInt16, to: UInt16)
  /// Changes the application that opens the item.
  case application(URL, from: URL, to: URL)
  /// Changes the default application of a type, as Change All does.
  case typeApplication(UTType, from: URL, to: URL)
  /// Several edits that apply and undo together, as for a multiple selection.
  case batch([InspectorEdit])

  /// The edit that reverts this one.
  internal var inverse: InspectorEdit {
    switch self {
    case .rename(let url, let oldName, let newName):
      .rename(url.deletingLastPathComponent().appending(path: newName), from: newName, to: oldName)
    case .tags(let url, let oldTags, let newTags):
      .tags(url, from: newTags, to: oldTags)
    case .attribute(let url, let attribute, let oldValue, let newValue):
      .attribute(url, attribute, from: newValue, to: oldValue)
    case .mode(let url, let oldMode, let newMode):
      .mode(url, from: newMode, to: oldMode)
    case .application(let url, let oldApplication, let newApplication):
      .application(url, from: newApplication, to: oldApplication)
    case .typeApplication(let type, let oldApplication, let newApplication):
      .typeApplication(type, from: newApplication, to: oldApplication)
    case .batch(let edits):
      .batch(edits.reversed().map(\.inverse))
    }
  }

  /// The name of the action in Edit > Undo.
  internal var actionName: String {
    switch self {
    case .rename:
      String(localized: "Rename")
    case .tags:
      String(localized: "Change Tags")
    case .attribute(_, let attribute, _, _):
      switch attribute {
      case .locked:
        String(localized: "Change Locked")
      case .hidden:
        String(localized: "Change Hidden")
      case .hiddenExtension:
        String(localized: "Change Hide Extension")
      }
    case .mode:
      String(localized: "Change Permissions")
    case .application, .typeApplication:
      String(localized: "Change Application")
    case .batch(let edits):
      edits.first?.actionName ?? String(localized: "Change Permissions")
    }
  }
}

/// The state of an inspector or Get Info window: the items it shows, their loaded details and edits.
///
/// Edits run one after the other, apply to the file system right away and register an undo action, so that
/// Edit > Undo reverts them.
@Observable
internal final class InspectorModel {

  // MARK: - Properties

  /// The items shown; one item shows its details, several items a summary.
  internal private(set) var urls: [URL] = []
  /// The details of a single item, once loaded.
  internal private(set) var details: ItemDetails?
  /// The snapshots of several items, once loaded.
  internal private(set) var items: [FileItem] = []
  /// The recursive size of a single folder, or the total size of several items.
  internal private(set) var totalSize: FolderSize?
  internal private(set) var isCalculatingSize = false
  /// Why the items could not be read.
  internal private(set) var loadFailure: String?
  /// The last edit that failed; cleared by the next edit.
  internal private(set) var editError: InspectorEditError?
  /// The edit that `retryWithAuthorization()` makes through the privileged helper, and where its undo goes.
  @ObservationIgnored private var editNeedingAuthorization: (edit: InspectorEdit, undoManager: UndoManager?)?
  /// Receives the new location of a renamed item, for example to keep it selected.
  @ObservationIgnored internal var didRename: ((URL) -> Void)?
  /// The applications that can open the single item, and the one that opens it.
  internal private(set) var applications: [ApplicationChoice] = []
  internal private(set) var currentApplication: URL?
  /// The default application of the single item's type, before Change All.
  internal private(set) var typeDefaultApplication: URL?
  /// The Locked attribute of several items.
  internal private(set) var lockedStates: [URL: Bool] = [:]

  /// The last edit; every edit waits for the previous one.
  @ObservationIgnored private var pendingEdit: Task<Void, Never>?
  /// Attribute changes of several items that apply together; see `queueAttribute`.
  @ObservationIgnored private var queuedEdits: [InspectorEdit] = []
  /// Applies `queuedEdits` once the toggle has set all its bindings.
  @ObservationIgnored private var queueFlush: Task<Void, Never>?
  @ObservationIgnored private let renameService = RenameService()

  // MARK: - Loading

  /// Shows `urls` and loads their details. Call it from a view's `.task(id:)`, which cancels loading when the
  /// items change.
  internal func show(_ urls: [URL]) async {
    if urls != self.urls {
      self.urls = urls
      details = nil
      items = []
      totalSize = nil
      editError = nil
    }
    loadFailure = nil
    if urls.count == 1, let url = urls.first {
      await loadDetails(of: url)
    } else if urls.isEmpty == false {
      await loadSummary(of: urls)
    }
  }

  /// Waits until every edit so far has finished.
  internal func waitForPendingEdits() async {
    await queueFlush?.value
    await pendingEdit?.value
  }

  // MARK: - Editing

  /// Renames the single item to `newName` after validating it; Edit > Undo renames it back.
  internal func rename(to newName: String, undoManager: UndoManager?) {
    guard let item = details?.item, newName != item.name else {
      return
    }
    apply(.rename(item.url, from: item.name, to: newName), undoManager: undoManager)
  }

  // MARK: - Tags

  /// The tags shown: those of the single item, or of any of several items, in the order they first appear.
  internal var tags: [String] {
    var seen = Set<String>()
    return editedItems.flatMap(\.tagNames).filter { seen.insert($0).inserted }
  }

  /// The tags that only some of several items carry.
  internal var partialTags: Set<String> {
    let editedItems = editedItems
    return Set(tags.filter { tag in editedItems.contains { $0.tagNames.contains(tag) == false } })
  }

  /// Adds `tag` to every shown item that does not carry it yet.
  internal func addTag(_ tag: String, undoManager: UndoManager?) {
    let edits = editedItems.compactMap { item -> InspectorEdit? in
      item.tagNames.contains(tag) ? nil : .tags(item.url, from: item.tagNames, to: item.tagNames + [tag])
    }
    applyAll(edits, undoManager: undoManager)
  }

  /// Removes `tag` from every shown item.
  internal func removeTag(_ tag: String, undoManager: UndoManager?) {
    let edits = editedItems.compactMap { item -> InspectorEdit? in
      item.tagNames.contains(tag) ? .tags(item.url, from: item.tagNames, to: item.tagNames.filter { $0 != tag }) : nil
    }
    applyAll(edits, undoManager: undoManager)
  }

  // MARK: - Attributes

  /// The value of `attribute` for `item`.
  internal func value(of attribute: ItemAttribute, for item: FileItem) -> Bool {
    switch attribute {
    case .locked:
      details?.item.url == item.url ? details?.isLocked == true : lockedStates[item.url] == true
    case .hidden:
      item.isHidden
    case .hiddenExtension:
      item.hasHiddenExtension
    }
  }

  /// Sets `attribute` of every shown item.
  internal func setAttribute(_ attribute: ItemAttribute, to isOn: Bool, undoManager: UndoManager?) {
    let edits = editedItems.compactMap { item -> InspectorEdit? in
      let current = value(of: attribute, for: item)
      return current == isOn ? nil : .attribute(item.url, attribute, from: current, to: isOn)
    }
    applyAll(edits, undoManager: undoManager)
  }

  /// Sets `attribute` of one of several items. A mixed-state toggle sets every item's binding in one go, so the
  /// changes are collected and applied as one undoable edit.
  internal func queueAttribute(_ attribute: ItemAttribute, of item: FileItem, to isOn: Bool, undoManager: UndoManager?) {
    let current = value(of: attribute, for: item)
    guard current != isOn else {
      return
    }
    let isFirstChange = queuedEdits.isEmpty
    queuedEdits.append(.attribute(item.url, attribute, from: current, to: isOn))
    guard isFirstChange else {
      return
    }
    queueFlush = Task { [weak self] in
      guard let self else {
        return
      }
      let edits = queuedEdits
      queuedEdits.removeAll()
      applyAll(edits, undoManager: undoManager)
    }
  }

  // MARK: - Permissions

  /// Turns the permission bit `bit` of the single item on or off.
  internal func setPermission(_ bit: UInt16, to isOn: Bool, undoManager: UndoManager?) {
    guard let item = details?.item, let mode = item.permissions else {
      return
    }
    let newMode = isOn ? mode | bit : mode & ~bit
    if newMode != mode {
      apply(.mode(item.url, from: mode, to: newMode), undoManager: undoManager)
    }
  }

  /// Applies the single folder's permissions to everything inside it; see `ItemEditor.enclosedModeChanges`.
  internal func applyPermissionsToEnclosedItems(undoManager: UndoManager?) {
    guard let item = details?.item, item.isDirectory, let mode = item.permissions else {
      return
    }
    perform { model in
      let edits = await ItemEditor.enclosedModeChanges(in: item.url, applying: mode)
      guard edits.isEmpty == false else {
        return
      }
      if await model.execute(.batch(edits)) {
        model.registerUndo(of: .batch(edits), with: undoManager)
      }
    }
  }

  // MARK: - Open With

  /// Makes `application` open the single item.
  internal func setApplication(_ application: URL, undoManager: UndoManager?) {
    guard let item = details?.item, let current = currentApplication, current != application else {
      return
    }
    currentApplication = application
    apply(.application(item.url, from: current, to: application), undoManager: undoManager)
  }

  /// Makes the application that opens the single item the default for its whole type, as Change All does.
  internal func changeAllToCurrentApplication(undoManager: UndoManager?) {
    guard
      let type = details?.item.contentType,
      let current = currentApplication,
      let previous = typeDefaultApplication,
      previous != current
    else {
      return
    }
    apply(.typeApplication(type, from: previous, to: current), undoManager: undoManager)
  }

  /// Whether Change All would change anything.
  internal var canChangeAll: Bool {
    details?.item.contentType != nil && currentApplication != nil && currentApplication != typeDefaultApplication
  }

  /// Applies `edit` after the edits before it and, when it succeeds, registers its inverse with `undoManager`.
  internal func apply(_ edit: InspectorEdit, undoManager: UndoManager?) {
    perform { model in
      if await model.execute(edit) {
        model.registerUndo(of: edit, with: undoManager)
      } else if model.editNeedingAuthorization?.edit == edit {
        model.editNeedingAuthorization = (edit, undoManager)
      }
    }
  }

  /// Authenticate and Retry: makes the edit that failed for lack of rights through the privileged helper.
  internal func retryWithAuthorization(runner: PrivilegedRunner = PrivilegedRunner()) {
    guard let pending = editNeedingAuthorization else {
      return
    }
    editNeedingAuthorization = nil
    perform { model in
      do {
        try await Self.applyThroughHelper(pending.edit, runner: runner)
        model.registerUndo(of: pending.edit, with: pending.undoManager)
      } catch {
        model.editError = .failed(error.localizedDescription)
      }
      await model.refresh()
    }
  }

  // MARK: - Private

  /// The single item, or the several items, that tag and attribute edits change.
  private var editedItems: [FileItem] {
    details.map { [$0.item] } ?? items
  }

  /// Applies `edits` as one undoable edit.
  private func applyAll(_ edits: [InspectorEdit], undoManager: UndoManager?) {
    guard let first = edits.first else {
      return
    }
    apply(edits.count == 1 ? first : .batch(edits), undoManager: undoManager)
  }

  private func loadDetails(of url: URL) async {
    do {
      let loaded = try await InspectorLoader.details(of: url)
      guard Task.isCancelled == false else {
        return
      }
      details = loaded
      guard loaded.item.isDirectory else {
        await loadApplications(for: loaded.item)
        return
      }
      isCalculatingSize = true
      let size = try? await FolderSizeService.shared.size(of: url)
      guard Task.isCancelled == false else {
        return
      }
      totalSize = size
      isCalculatingSize = false
    } catch {
      guard Task.isCancelled == false else {
        return
      }
      loadFailure = error.localizedDescription
    }
  }

  /// Loads the snapshots of several items and then their total size, folders included.
  private func loadSummary(of urls: [URL]) async {
    let loaded = await FileSystemService().items(at: urls)
    guard Task.isCancelled == false else {
      return
    }
    items = loaded
    lockedStates = await ItemEditor.lockedStates(of: loaded.map(\.url))
    isCalculatingSize = true
    var itemCount = 0
    var logicalBytes: Int64 = 0
    var physicalBytes: Int64 = 0
    for item in loaded {
      if item.isDirectory, let size = try? await FolderSizeService.shared.size(of: item.url) {
        itemCount += size.itemCount + 1
        logicalBytes += size.logicalBytes
        physicalBytes += size.physicalBytes
      } else {
        itemCount += 1
        logicalBytes += item.size ?? 0
        physicalBytes += item.allocatedSize ?? item.size ?? 0
      }
      guard Task.isCancelled == false else {
        return
      }
    }
    totalSize = FolderSize(itemCount: itemCount, logicalBytes: logicalBytes, physicalBytes: physicalBytes)
    isCalculatingSize = false
  }

  private func loadApplications(for item: FileItem) async {
    async let choices = OpenWithProvider.loadApplications(toOpen: [item.url])
    let (current, typeDefault) = await ItemEditor.applications(for: item.url, type: item.contentType)
    let loadedChoices = await choices
    guard Task.isCancelled == false else {
      return
    }
    applications = loadedChoices
    currentApplication = current
    typeDefaultApplication = typeDefault
  }

  /// Runs `edit` after the edits before it.
  private func perform(_ edit: @escaping (InspectorModel) async -> Void) {
    let previousEdit = pendingEdit
    pendingEdit = Task { [weak self] in
      await previousEdit?.value
      guard let self else {
        return
      }
      editError = nil
      await edit(self)
    }
  }

  /// Registers undoing `edit`. Undoing registers the opposite action right away, while the undo manager is still
  /// undoing, so that it becomes the redo action; the file system work follows asynchronously.
  private func registerUndo(of edit: InspectorEdit, with undoManager: UndoManager?) {
    guard let undoManager else {
      return
    }
    undoManager.registerUndo(withTarget: self) { model in
      let inverse = edit.inverse
      model.registerUndo(of: inverse, with: undoManager)
      model.perform { model in
        _ = await model.execute(inverse)
      }
    }
    undoManager.setActionName(edit.actionName)
  }

  /// Performs `edit` on the file system and shows the result.
  ///
  /// - Returns: Whether the edit succeeded.
  private func execute(_ edit: InspectorEdit) async -> Bool {
    if case .rename(let url, let oldName, let newName) = edit {
      return await executeRename(of: url, from: oldName, to: newName)
    }
    do {
      try await Self.applyToFileSystem(edit)
    } catch {
      if Self.canApplyThroughHelper(edit), OperationFailure.isPermissionError(error) {
        editError = .needsAuthorization(error.localizedDescription)
        editNeedingAuthorization = (edit, nil)
      } else {
        editError = .failed(error.localizedDescription)
      }
      await refresh()
      return false
    }
    await refresh()
    return true
  }

  /// Performs an edit other than renaming.
  private static func applyToFileSystem(_ edit: InspectorEdit) async throws {
    switch edit {
    case .rename:
      return
    case .tags(let url, _, let tags):
      try await ItemEditor.setTags(tags, of: url)
    case .attribute(let url, let attribute, _, let isOn):
      try await ItemEditor.set(attribute, to: isOn, of: url)
    case .mode(let url, _, let mode):
      try await ItemEditor.setMode(mode, of: url)
    case .application(let url, _, let application):
      try await ItemEditor.setApplication(application, forItemAt: url)
    case .typeApplication(let type, _, let application):
      try await ItemEditor.setApplication(application, forType: type)
    case .batch(let edits):
      for edit in edits {
        try await applyToFileSystem(edit)
      }
    }
  }

  /// Whether the privileged helper can make `edit`: permissions and the Locked attribute.
  internal static func canApplyThroughHelper(_ edit: InspectorEdit) -> Bool {
    switch edit {
    case .mode, .attribute(_, .locked, _, _):
      true
    case .batch(let edits):
      edits.allSatisfy(canApplyThroughHelper)
    case .rename, .tags, .attribute, .application, .typeApplication:
      false
    }
  }

  /// Makes `edit` through the privileged helper.
  private static func applyThroughHelper(_ edit: InspectorEdit, runner: PrivilegedRunner) async throws {
    switch edit {
    case .mode(let url, _, let mode):
      _ = try await runner.send(.setMode(path: url.path(percentEncoded: false), mode: mode))
    case .attribute(let url, .locked, _, let isLocked):
      var status = stat()
      let current = lstat(url.path(percentEncoded: false), &status) == 0 ? status.st_flags : 0
      let flags = isLocked ? current | UInt32(UF_IMMUTABLE) : current & ~UInt32(UF_IMMUTABLE)
      _ = try await runner.send(.setFlags(path: url.path(percentEncoded: false), flags: flags))
    case .batch(let edits):
      for edit in edits {
        try await applyThroughHelper(edit, runner: runner)
      }
    case .rename, .tags, .attribute, .application, .typeApplication:
      throw PrivilegedRunner.RunnerError.helper(.invalidRequest)
    }
  }

  /// Reads the shown items again after an edit.
  private func refresh() async {
    if urls.count == 1, let url = urls.first {
      await loadDetails(of: url)
    } else if urls.isEmpty == false {
      let loaded = await FileSystemService().items(at: urls)
      items = loaded
      lockedStates = await ItemEditor.lockedStates(of: loaded.map(\.url))
    }
  }

  private func executeRename(of url: URL, from oldName: String, to newName: String) async -> Bool {
    let siblingNames = await InspectorLoader.siblingNames(of: url)
    if let error = NameValidator.validate(newName, originalName: oldName, existingNames: siblingNames) {
      editError = .invalidName(error)
      return false
    }
    do {
      let newURL = try await renameService.rename(url, to: newName)
      didRename?(newURL)
      if urls.map(\.comparablePath) == [url.comparablePath] {
        urls = [newURL]
        await loadDetails(of: newURL)
      }
      return true
    } catch {
      editError = .failed(error.localizedDescription)
      return false
    }
  }
}

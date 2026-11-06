/*
 * TabModel.swift
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

import Foundation
import Observation
import SwiftUI

/// One tab of a pane: location, history, view settings, selection, inline expansion, renaming and listing.
@Observable
internal final class TabModel: Identifiable {

  // MARK: - Types

  /// The outcome of committing an inline rename.
  internal enum RenameResult: Equatable {
    case renamed
    case invalid(NameValidationError)
    /// Renaming failed with a localized description of the error.
    case failed(String)
    /// The new name changes the extension, which the user confirms first, unless the warning is turned off.
    case needsExtensionConfirmation(oldExtension: String, newExtension: String)
  }

  // MARK: - Properties

  internal let id = UUID()
  internal private(set) var history: NavigationHistory
  internal var viewSettings: ViewSettings
  internal private(set) var selectionModel = SelectionModel()
  /// The quick filter text; empty when no filter is active.
  internal var filterText = ""
  /// What the search field and the search bar edit: the scope, the search text of the Subfolders and This Mac
  /// scopes, criteria and options. A search location's own parameters while one is shown.
  internal var searchParameters = SearchParameters()
  internal let listing: DirectoryListing
  /// The display name of the current location.
  internal private(set) var title: String
  /// The folders expanded inline in list view.
  internal private(set) var expandedFolders: Set<FileItem.ID> = []
  /// The loaded children of expanded folders.
  internal private(set) var children: [FileItem.ID: [FileItem]] = [:]
  /// The item whose name is being edited.
  internal private(set) var renamingItemID: FileItem.ID?
  /// Whether the path bar shows a text field instead of breadcrumbs, as after Edit > Edit Path.
  internal var isEditingPath = false
  /// The applications that can open the selected items, for File > Open With; see `refreshOpenWithApplications()`.
  internal private(set) var openWithApplications: [ApplicationChoice] = []
  /// The items waiting for the application chosen with Open With > Other….
  internal var applicationChoiceRequest: [URL]?
  /// An alias or symbolic link whose original is missing; the view asks whether to delete it.
  internal var brokenAlias: FileItem?
  /// A failure to report, such as a missing terminal application.
  internal var failureMessage: LocalizedStringResource?
  /// The dates items were last opened, loaded from Spotlight when the list view needs them.
  internal private(set) var lastOpenedDates: [FileItem.ID: Date] = [:]
  internal var columnCustomization = TableColumnCustomization<FileRow>()
  /// The folders opened in column view after the tab's folder, in order.
  internal private(set) var columnChain: [FileItem] = []
  /// The selection of each column in column view, by column index; column 0 shows the tab's folder.
  internal private(set) var columnSelections: [Int: Set<FileItem.ID>] = [:]
  /// The item shown in Quick Look, or nil while the panel is closed.
  internal var quickLookURL: URL?
  /// The column that selects its first item once loaded, after → moved into it.
  internal private(set) var pendingFirstSelectionColumn: Int?
  /// Increases whenever the listing changed on disk, so that views reload dependent data.
  internal private(set) var refreshGeneration = 0
  /// Increases when the tab's file view should take keyboard focus, as after Tab in the other pane.
  internal private(set) var focusRequest = 0
  /// Increases with View > Reload, which loads the location again.
  internal private(set) var reloadGeneration = 0
  /// The pane that holds the tab; the pane sets it.
  @ObservationIgnored internal weak var pane: PaneModel?
  /// Where double-clicked folders open; tests replace it instead of changing the user's settings.
  @ObservationIgnored internal var folderOpeningBehavior: () -> FolderOpeningBehavior = {
    SettingsStore().value(for: SettingsKeys.folderOpeningBehavior)
  }

  /// Folders whose children expand as soon as they are loaded, after an ⌥-click.
  @ObservationIgnored private var recursivelyExpandedFolders: Set<FileItem.ID> = []
  /// The refresh generation each folder's children were loaded in.
  @ObservationIgnored private var childrenGenerations: [FileItem.ID: Int] = [:]
  /// The selected items of the active column in column view.
  @ObservationIgnored private var columnSelectedItems: [FileItem] = []
  @ObservationIgnored private var typeSelectBuffer = TypeSelectBuffer()
  /// The items to select once the listing contains them, as normalized paths; see `reveal(_:)`.
  @ObservationIgnored private var pendingRevealPaths: Set<String> = []
  /// Created items to select once the listing shows them, which can take more than one listing change.
  @ObservationIgnored private var pendingCreatedPaths: Set<String> = []
  /// The created item to rename once the listing shows it, as after New Folder.
  @ObservationIgnored private var pendingRenamePath: String?
  /// Starts renaming after a click on the name of the selected item and a pause.
  @ObservationIgnored private var scheduledRename: Task<Void, Never>?
  /// Runs the search after the user paused typing or editing criteria.
  @ObservationIgnored private var scheduledSearch: Task<Void, Never>?
  /// The search the tab shows, recorded as a recent search when the tab leaves it.
  @ObservationIgnored private var shownSearch: SearchQuery?
  /// Records visited folders for Go > Recent Folders; nil in previews and tests.
  @ObservationIgnored private let recents: RecentsStore?
  @ObservationIgnored private let fileSystem = FileSystemService()
  @ObservationIgnored private let renameService = RenameService()

  internal var location: Location {
    history.current
  }

  internal var folderURL: URL? {
    location.folderURL
  }

  /// The selected item identifiers, bound to the file views.
  internal var selection: Set<FileItem.ID> {
    get {
      selectionModel.selection
    }
    set {
      selectionModel.replace(with: newValue)
    }
  }

  /// The items of the tab's folder after the quick filter, in display order.
  internal var visibleItems: [FileItem] {
    sorting.sorted(filteredItems)
  }

  /// The list view rows in display order: the visible items, the loaded children of expanded folders, and,
  /// when grouped, one section after the other.
  internal var outlineRows: [FileRow] {
    guard viewSettings.grouping != .none else {
      return OutlineRows.rows(
        for: filteredItems,
        children: children,
        expanded: expandedFolders,
        sorting: sorting,
        isExpandable: opensAsFolder)
    }
    return outlineSections.flatMap(\.rows)
  }

  /// The list view rows grouped by the tab's grouping key.
  internal var outlineSections: [OutlineSection] {
    let sorting = sorting
    return sorting.sections(of: filteredItems, groupedBy: viewSettings.grouping).map { section in
      OutlineSection(
        group: section.group,
        rows: OutlineRows.rows(
          for: section.items,
          children: children,
          expanded: expandedFolders,
          sorting: sorting,
          isExpandable: opensAsFolder))
    }
  }

  /// The visible items grouped by the tab's grouping key, for icon view.
  internal var itemSections: [ItemSection] {
    sorting.sections(of: filteredItems, groupedBy: viewSettings.grouping)
  }

  /// The selected items in display order, including selected children of expanded folders and, in column
  /// view, the selection of the active column.
  internal var selectedItems: [FileItem] {
    guard selection.isEmpty == false else {
      return []
    }
    if viewSettings.viewMode == .columns, columnSelectedItems.isEmpty == false {
      return columnSelectedItems
    }
    return outlineRows.filter { selection.contains($0.id) }.map(\.item)
  }

  internal var snapshot: TabSnapshot {
    TabSnapshot(history: history, viewSettings: viewSettings)
  }

  private var sorting: ItemSorting {
    ItemSorting(order: viewSettings.sortOrder)
  }

  private var filteredItems: [FileItem] {
    let items =
      lastOpenedDates.isEmpty
      ? listing.items
      : listing.items.map { item in lastOpenedDates[item.id].map(item.with(lastOpenedDate:)) ?? item }
    guard filterText.isEmpty == false else {
      return items
    }
    return items.filter { $0.localizedName.localizedStandardContains(filterText) }
  }

  /// The search started in this tab begins here: the folder shown or, in search results, the search's own origin.
  private var searchOrigin: FileReference? {
    switch location {
    case .folder(let reference):
      reference
    case .search(let query):
      query.origin
    case .computer, .tag:
      nil
    }
  }

  // MARK: - Initialization

  internal init(
    history: NavigationHistory,
    viewSettings: ViewSettings = ViewSettings(settings: SettingsStore()),
    listing: DirectoryListing = DirectoryListing(),
    recents: RecentsStore? = nil
  ) {
    self.history = history
    self.viewSettings = viewSettings
    self.listing = listing
    self.recents = recents
    title = history.current.displayName
    shownSearch = history.current.searchQuery
    searchParameters = shownSearch?.parameters ?? SearchParameters()
    if let savedColumns = SettingsStore().listColumnDefaults(),
      let customization = try? JSONDecoder().decode(TableColumnCustomization<FileRow>.self, from: savedColumns)
    {
      columnCustomization = customization
    }
  }

  internal convenience init(
    location: Location,
    viewSettings: ViewSettings = ViewSettings(settings: SettingsStore()),
    listing: DirectoryListing = DirectoryListing(),
    recents: RecentsStore? = nil
  ) {
    self.init(history: NavigationHistory(current: location), viewSettings: viewSettings, listing: listing, recents: recents)
  }

  internal convenience init(snapshot: TabSnapshot, recents: RecentsStore? = nil) {
    self.init(history: snapshot.history, viewSettings: snapshot.viewSettings, recents: recents)
  }

  // MARK: - Navigation

  /// Shows `location` and records the previous location in the back history.
  internal func navigate(to location: Location) {
    guard location != history.current else {
      return
    }
    history.navigate(to: location)
    didChangeLocation()
  }

  /// Shows the folder at `url`.
  internal func navigate(toFolder url: URL) {
    guard let reference = try? FileReference(url: url) else {
      return
    }
    navigate(to: .folder(reference))
  }

  internal func goBack() {
    guard history.goBack() != nil else {
      return
    }
    didChangeLocation()
  }

  internal func goForward() {
    guard history.goForward() != nil else {
      return
    }
    didChangeLocation()
  }

  /// Jumps to an entry of the Back history menu.
  internal func goBack(toMenuIndex index: Int) {
    guard history.goBack(toMenuIndex: index) != nil else {
      return
    }
    didChangeLocation()
  }

  /// Jumps to an entry of the Forward history menu.
  internal func goForward(toMenuIndex index: Int) {
    guard history.goForward(toMenuIndex: index) != nil else {
      return
    }
    didChangeLocation()
  }

  /// Whether Go > Enclosing Folder applies: every folder has a parent folder or, for a volume, Computer.
  internal var canGoToEnclosingFolder: Bool {
    folderURL != nil
  }

  /// Shows the parent of the current folder with the folder just left selected; a volume's parent is Computer.
  internal func goToEnclosingFolder() {
    guard let folderURL else {
      return
    }
    reveal(folderURL)
  }

  /// Shows the folder that contains `url`, or Computer for a volume, and selects the item there once the listing
  /// contains it.
  internal func reveal(_ url: URL) {
    if Self.isVolumeRoot(url) {
      navigate(to: .computer)
    } else {
      navigate(toFolder: url.deletingLastPathComponent())
    }
    select(revealing: url)
  }

  /// Opens folders in the tab and files with their default application.
  internal func open(_ item: FileItem) {
    cancelScheduledRename()
    if opensAsFolder(item) {
      openFolder(item)
    } else {
      openFiles([item])
    }
  }

  /// Opens files with their default applications and shows the first folder among `items` in the tab; further
  /// folders open in new tabs behind this one.
  internal func open(_ items: [FileItem]) {
    openFiles(items.filter { opensAsFolder($0) == false })
    let folders = items.filter(opensAsFolder)
    guard let first = folders.first else {
      return
    }
    openInNewTabs(folders.dropFirst(), selects: false)
    openFolder(first)
  }

  /// Shows a folder the user opened where the General settings say: in this tab, a new tab or a new window.
  private func openFolder(_ folder: FileItem) {
    switch folderOpeningBehavior() {
    case .sameTab:
      navigate(toFolder: folder.url)
    case .newTab:
      openInNewTabs([folder])
    case .newWindow:
      guard let window = pane?.window, let reference = try? FileReference(url: folder.url) else {
        navigate(toFolder: folder.url)
        return
      }
      window.requestNewWindow(showing: .folder(reference))
    }
  }

  /// Replaces the location without adding history, as a window opened for a particular folder does.
  internal func replaceLocation(with location: Location) {
    guard location != history.current else {
      return
    }
    history.replaceCurrent(with: location)
    didChangeLocation()
  }

  /// Opens each folder among `items` in a new tab right after this one; with `selects`, the first new tab
  /// becomes current.
  /// Authenticate to View: lists the tab's folder, which FileCraft may not read, through the privileged helper.
  internal func authenticateToView(runner: PrivilegedRunner = PrivilegedRunner()) async {
    guard let folder = folderURL else {
      return
    }
    do {
      guard case .listing(let entries) = try await runner.send(.list(path: folder.path(percentEncoded: false))) else {
        return
      }
      let items = entries.map { entry in
        FileItem(
          url: folder.appending(path: entry.name, directoryHint: entry.isDirectory ? .isDirectory : .notDirectory),
          name: entry.name,
          isDirectory: entry.isDirectory,
          isHidden: entry.name.hasPrefix("."),
          isSymbolicLink: entry.isSymbolicLink,
          size: entry.isDirectory ? nil : entry.size,
          modificationDate: entry.modificationDate)
      }
      listing.showPrivilegedItems(items)
    } catch {
      failureMessage = "The folder could not be listed: \(error.localizedDescription)"
    }
  }

  /// Opens files with their default applications; archives expand in FileCraft when that setting is on.
  private func openFiles(_ files: [FileItem]) {
    let expandsArchives = SettingsStore().value(for: SettingsKeys.expandsArchivesInFileCraft)
    let archives = expandsArchives ? files.map(\.url).filter(ArchiveService.isArchive) : []
    for file in files where archives.contains(file.url) == false {
      WorkspaceActions.open(file.url)
    }
    if archives.isEmpty == false, let commands = pane?.window?.fileCommands {
      Task { await commands.expand(archives) }
    }
  }

  internal func openInNewTabs(_ items: some Collection<FileItem>, selects: Bool = true) {
    guard let pane, let start = pane.index(of: self) else {
      return
    }
    let references = items.filter(opensAsFolder).compactMap { try? FileReference(url: $0.url) }
    for (offset, reference) in references.enumerated() {
      let tab = TabModel(location: .folder(reference), recents: recents)
      pane.insertTab(tab, at: start + 1 + offset, selects: selects && offset == 0)
    }
  }

  // MARK: - Focus

  /// Asks the tab's file view to take keyboard focus.
  internal func requestFocus() {
    focusRequest += 1
  }

  /// Makes the tab's pane the active pane, as when its file view receives keyboard focus.
  internal func didReceiveFocus() {
    guard let pane else {
      return
    }
    pane.window?.activate(pane)
  }

  /// Opens the selected items, as File > Open and ⌘↓ do.
  internal func openSelection() {
    open(selectedItems)
  }

  /// Shows the contents of a package such as an app.
  internal func showPackageContents(_ item: FileItem) {
    navigate(toFolder: item.url)
  }

  /// Whether `item` opens and expands like a folder in this tab.
  internal func opensAsFolder(_ item: FileItem) -> Bool {
    item.isDirectory && (item.isPackage == false || viewSettings.treatsPackagesAsFolders)
  }

  // MARK: - Selection

  internal func select(_ id: FileItem.ID) {
    selectionModel.select(id)
  }

  internal func toggleSelection(_ id: FileItem.ID) {
    selectionModel.toggle(id)
  }

  internal func extendSelection(to id: FileItem.ID, in order: [FileItem.ID]) {
    selectionModel.extend(to: id, in: order)
  }

  /// Selects the first of `entries` whose name starts with the characters typed within the last second.
  internal func typeSelect(_ characters: String, in entries: [(id: FileItem.ID, name: String)], locale: Locale) {
    let prefix = typeSelectBuffer.append(characters, at: .now)
    if let match = TypeSelectBuffer.firstMatch(for: prefix, in: entries, locale: locale) {
      selectionModel.select(match)
    }
  }

  /// View > Reload: loads the tab's location again.
  internal func reload() {
    reloadGeneration += 1
  }

  internal func selectAll() {
    selectionModel.selectAll(in: outlineRows.map(\.id))
  }

  internal func deselectAll() {
    selectionModel.deselectAll()
  }

  internal func invertSelection() {
    selectionModel.invert(in: outlineRows.map(\.id))
  }

  /// Keeps the tab consistent after the listing changed on disk: items that are gone are deselected,
  /// and the next refresh generation makes views reload expanded children and Spotlight dates.
  internal func listingDidChange() {
    refreshGeneration += 1
    selectionModel.prune(keeping: Set(outlineRows.map(\.id)).union(expandedFolders))
    // The first listing after `reveal(_:)` decides; later changes must not select the item again.
    applyPendingReveal()
    pendingRevealPaths.removeAll()
    applyPendingCreatedItems()
  }

  // MARK: - Column View

  /// Starts column view with the current selection in the first column, so that switching the view mode keeps
  /// the selection; a single selected folder opens in the next column.
  internal func showSelectionInColumns() {
    let items = visibleItems
    let selected = Set(items.filter { selection.contains($0.id) }.map(\.id))
    selectInColumn(0, selection: selected, items: items)
  }

  /// Records the selection of a column: a single selected folder opens in the next column, and deeper
  /// columns close.
  internal func selectInColumn(_ column: Int, selection newSelection: Set<FileItem.ID>, items: [FileItem]) {
    columnSelections = columnSelections.filter { $0.key < column }
    columnSelections[column] = newSelection
    columnChain = Array(columnChain.prefix(column))
    let selected = items.filter { newSelection.contains($0.id) }
    if selected.count == 1, let item = selected.first, opensAsFolder(item) {
      columnChain.append(item)
    }
    columnSelectedItems = selected
    selectionModel.replace(with: newSelection)
  }

  /// Asks `column` to select its first item, as → does when it enters a folder.
  internal func requestFirstSelection(inColumn column: Int) {
    pendingFirstSelectionColumn = column
  }

  /// Selects the first of `items` if `column` was asked to; call it whenever the column's items change.
  internal func applyPendingFirstSelection(inColumn column: Int, items: [FileItem]) {
    guard pendingFirstSelectionColumn == column, let first = items.first else {
      return
    }
    pendingFirstSelectionColumn = nil
    selectInColumn(column, selection: [first.id], items: items)
  }

  /// Returns from `column` to its parent column, as ← does: the column stays open, its selection ends.
  internal func leaveColumn(_ column: Int) {
    guard column > 0, columnChain.indices.contains(column - 1) else {
      return
    }
    let folder = columnChain[column - 1]
    columnSelections = columnSelections.filter { $0.key < column }
    columnChain = Array(columnChain.prefix(column))
    columnSelectedItems = [folder]
    selectionModel.replace(with: [folder.id])
  }

  // MARK: - Quick Look

  /// The items the Quick Look panel browses with its arrow keys: the selection when several items are selected,
  /// otherwise every item of the view in display order. In column view only the selection, because deeper
  /// columns are not part of the tab's listing.
  internal var quickLookURLs: [URL] {
    let selected = selectedItems
    guard selected.count < 2, viewSettings.viewMode != .columns else {
      return selected.map(\.url)
    }
    let items = viewSettings.viewMode == .list ? outlineRows.map(\.item) : itemSections.flatMap(\.items)
    return items.map(\.url)
  }

  /// Opens Quick Look for the selected items, or closes it when it is open.
  internal func toggleQuickLook() {
    quickLookURL = quickLookURL == nil ? selectedItems.first?.url : nil
  }

  /// Opens Quick Look for `items`, selecting them.
  internal func quickLook(_ items: [FileItem]) {
    guard let first = items.first else {
      return
    }
    if items.contains(where: { selection.contains($0.id) }) == false {
      selectionModel.replace(with: Set(items.map(\.id)))
    }
    quickLookURL = first.url
  }

  /// Keeps an open preview on the selected item.
  internal func selectionDidChange() {
    cancelScheduledRename()
    guard quickLookURL != nil, let first = selectedItems.first, first.url != quickLookURL else {
      return
    }
    quickLookURL = first.url
  }

  /// Selects the item the Quick Look panel moved to.
  internal func quickLookDidMove(to url: URL?) {
    quickLookURL = url
    guard let url, let row = outlineRows.first(where: { $0.item.url == url }) else {
      return
    }
    if selection.contains(row.id) == false {
      selectionModel.select(row.id)
    }
  }

  // MARK: - Expansion

  /// Expands or collapses a folder in list view; recursively also affects all nested folders.
  internal func setExpanded(_ isExpanded: Bool, for item: FileItem, recursively: Bool) {
    guard opensAsFolder(item) else {
      return
    }
    if isExpanded {
      expandedFolders.insert(item.id)
      if recursively {
        recursivelyExpandedFolders.insert(item.id)
        expandLoadedDescendants(of: item.id)
      }
    } else {
      let collapsed = recursively ? expandedFolders.filter { Self.isPath($0, inside: item.id) || $0 == item.id } : [item.id]
      expandedFolders.subtract(collapsed)
      recursivelyExpandedFolders.subtract(collapsed)
    }
  }

  /// Expands or collapses the selected folders.
  internal func setSelectionExpanded(_ isExpanded: Bool, recursively: Bool) {
    for item in selectedItems where opensAsFolder(item) {
      setExpanded(isExpanded, for: item, recursively: recursively)
    }
  }

  /// Loads the children of expanded folders that are missing or older than the current refresh generation.
  /// Call it from a view's `.task`.
  internal func loadExpandedChildren() async {
    let includesHiddenItems = SettingsStore().value(for: SettingsKeys.showsHiddenFiles)
    let generation = refreshGeneration
    while let folderID = expandedFolders.first(where: { children[$0] == nil || childrenGenerations[$0] != generation }) {
      let items = (try? await fileSystem.contentsOfDirectory(at: URL(filePath: folderID), includingHiddenItems: includesHiddenItems)) ?? []
      guard Task.isCancelled == false else {
        return
      }
      children[folderID] = items
      childrenGenerations[folderID] = generation
      if recursivelyExpandedFolders.contains(folderID) {
        expandLoadedDescendants(of: folderID)
      }
    }
  }

  // MARK: - Renaming

  /// Starts editing the name of `item` and selects it.
  internal func beginRename(_ item: FileItem) {
    cancelScheduledRename()
    selectionModel.select(item.id)
    renamingItemID = item.id
  }

  /// Starts renaming `item` after a pause, as a click on the name of the selected item does in Finder. Opening,
  /// another selection or another location cancels it.
  internal func scheduleRename(of item: FileItem, after delay: Duration = .milliseconds(800)) {
    cancelScheduledRename()
    scheduledRename = Task { [weak self] in
      try? await Task.sleep(for: delay)
      guard let self, Task.isCancelled == false, self.selection == [item.id], self.renamingItemID == nil else {
        return
      }
      self.beginRename(item)
    }
  }

  internal func cancelScheduledRename() {
    scheduledRename?.cancel()
    scheduledRename = nil
  }

  /// Selects items created in this tab's folder as soon as the listing shows them; with `renaming`, that item's
  /// name is edited then, as after New Folder.
  internal func selectCreatedItems(_ urls: [URL], renaming: URL? = nil) {
    guard urls.isEmpty == false else {
      return
    }
    pendingCreatedPaths = Set(urls.map(Self.revealKey(for:)))
    pendingRenamePath = renaming.map(Self.revealKey(for:))
    applyPendingCreatedItems()
  }

  internal func cancelRename() {
    renamingItemID = nil
  }

  /// Validates `newName` and renames `item`, registering the undo action; the editor stays open when the result is
  /// not `.renamed`.
  ///
  /// - Parameter confirmsExtensionChange: Whether the user already confirmed a changed extension.
  internal func commitRename(of item: FileItem, to newName: String, confirmsExtensionChange: Bool = false) async -> RenameResult {
    guard newName != item.name else {
      renamingItemID = nil
      return .renamed
    }
    let siblingNames = siblings(of: item).map(\.name)
    if let error = NameValidator.validate(newName, originalName: item.name, existingNames: siblingNames) {
      return .invalid(error)
    }
    if confirmsExtensionChange == false, let change = Self.extensionChange(of: item, to: newName),
      SettingsStore().value(for: SettingsKeys.warnsBeforeChangingExtension)
    {
      return .needsExtensionConfirmation(oldExtension: change.old, newExtension: change.new)
    }
    do {
      let newURL = try await renameService.rename(item.url, to: newName)
      renamingItemID = nil
      selectionModel.select(newURL.path(percentEncoded: false))
      pane?.window?.fileCommands.undoRegistrar.registerRename(of: item.url, to: newURL)
      return .renamed
    } catch {
      return .failed(error.localizedDescription)
    }
  }

  // MARK: - Paths and Other Applications

  /// The items that Copy Path and Reveal in Finder act on: the selected items, or the tab's folder.
  internal var pathTargets: [URL] {
    let selected = selectedItems.map(\.url)
    if selected.isEmpty, let folderURL {
      return [folderURL]
    }
    return selected
  }

  /// The folders that Open in Terminal opens: the selected folders and the folders of selected files, or the
  /// tab's folder when nothing is selected.
  internal var terminalFolders: [URL] {
    let selected = selectedItems
    guard selected.isEmpty == false else {
      return folderURL.map { [$0] } ?? []
    }
    var seenPaths = Set<String>()
    return selected
      .map { opensAsFolder($0) ? $0.url : $0.url.deletingLastPathComponent() }
      .filter { seenPaths.insert(Self.revealKey(for: $0)).inserted }
  }

  /// Whether `pathTargets` is not empty; cheap enough for menu validation.
  internal var hasPathTargets: Bool {
    selection.isEmpty == false || folderURL != nil
  }

  /// The selected item when exactly one alias or symbolic link is selected, for File > Show Original.
  internal var selectedLink: FileItem? {
    guard selection.count == 1, let item = selectedItems.first, item.isAliasFile || item.isSymbolicLink else {
      return nil
    }
    return item
  }

  /// Copies the paths of `pathTargets` in `format`, one per line.
  internal func copyPaths(as format: PathFormat) {
    PasteboardActions.copyPaths(of: pathTargets, as: format)
  }

  internal func revealInFinder() {
    let fileCraftIsFileViewer = SettingsStore().value(for: SettingsKeys.usesFileCraftAsFileViewer)
    WorkspaceActions.revealInFinder(pathTargets, fileCraftIsFileViewer: fileCraftIsFileViewer)
  }

  internal func openInTerminal() {
    let bundleIdentifier = SettingsStore().value(for: SettingsKeys.terminalBundleIdentifier)
    if WorkspaceActions.openInTerminal(terminalFolders, bundleIdentifier: bundleIdentifier) == false {
      failureMessage = "No terminal application was found."
    }
  }

  /// Looks up the applications that can open the selection. Call it from a view's `.task` when the selection changes.
  internal func refreshOpenWithApplications() async {
    let urls = selectedItems.map(\.url)
    let applications = urls.isEmpty ? [] : await OpenWithProvider.loadApplications(toOpen: urls)
    guard Task.isCancelled == false else {
      return
    }
    openWithApplications = applications
  }

  /// Shows the original of `item` selected in its folder, or asks about deleting `item` when the original is missing.
  internal func showOriginal(of item: FileItem) async {
    switch await OriginalResolver.original(of: item) {
    case .original(let url):
      reveal(url)
    case .broken:
      brokenAlias = item
    case nil:
      return
    }
  }

  /// Moves the alias with the missing original to the Trash, as the alert's Delete Alias button does.
  internal func deleteBrokenAlias() async {
    guard let item = brokenAlias else {
      return
    }
    brokenAlias = nil
    do {
      try await WorkspaceActions.moveToTrash([item.url])
    } catch {
      failureMessage = "“\(item.localizedName)” could not be moved to the Trash."
    }
  }

  // MARK: - Search

  /// The text the search field shows: the quick filter, or the search text of the other scopes.
  internal var searchFieldText: String {
    searchParameters.scope == .thisFolder ? filterText : searchParameters.text
  }

  /// Whether the Subfolders scope applies, which needs a folder to search below.
  internal var canSearchSubfolders: Bool {
    searchOrigin != nil
  }

  /// Whether the tab shows the search bar with scope, criteria and options.
  internal var showsSearchBar: Bool {
    searchParameters.scope != .thisFolder || location.searchQuery != nil
  }

  /// Handles typing in the search field: This Folder filters at once, the other scopes search after a pause.
  /// Clearing the field ends a search.
  internal func setSearchText(_ text: String) {
    guard searchParameters.scope != .thisFolder else {
      filterText = text
      return
    }
    guard text != searchParameters.text else {
      return
    }
    searchParameters.text = text
    if text.isEmpty {
      endSearch()
    } else {
      scheduleSearch()
    }
  }

  /// Switches the search scope, keeping the text of the search field.
  internal func setSearchScope(_ scope: SearchScope) {
    guard scope != searchParameters.scope, scope != .subfolders || canSearchSubfolders else {
      return
    }
    let text = searchFieldText
    if scope == .thisFolder {
      cancelScheduledSearch()
      if location.searchQuery != nil {
        leaveSearch()
      }
      searchParameters.scope = .thisFolder
      searchParameters.text = ""
      filterText = text
    } else {
      filterText = ""
      searchParameters.scope = scope
      searchParameters.text = text
      runSearch()
    }
  }

  /// Runs the search again after its criteria or options changed, once the user pauses.
  internal func searchParametersDidChange() {
    guard searchParameters.scope != .thisFolder else {
      return
    }
    scheduleSearch()
  }

  /// Runs the search at once, as Return in the search field does, and remembers it as a recent search.
  internal func commitSearch() {
    if searchParameters.scope != .thisFolder {
      runSearch()
    }
    recordRecentSearch(searchParameters)
  }

  /// Runs a search from the search field's Recent Searches menu.
  internal func repeatSearch(_ parameters: SearchParameters) {
    guard parameters.scope != .subfolders || canSearchSubfolders else {
      return
    }
    cancelScheduledSearch()
    if parameters.scope == .thisFolder {
      if location.searchQuery != nil {
        leaveSearch()
      }
      searchParameters = parameters
      filterText = parameters.text
    } else {
      filterText = ""
      searchParameters = parameters
      runSearch()
    }
    recordRecentSearch(parameters)
  }

  /// Ends the search: a running search stops and the tab returns to the folder where the search started.
  internal func endSearch() {
    cancelScheduledSearch()
    if location.searchQuery != nil {
      leaveSearch()
    }
  }

  /// Stops a running search; the results found so far stay.
  internal func stopSearch() {
    cancelScheduledSearch()
    listing.stopSearch()
  }

  /// Shows the search for `searchParameters`: the first search of a run of typing adds a history entry, later ones
  /// replace it, so that Back returns to the folder where the search started.
  internal func runSearch() {
    cancelScheduledSearch()
    guard searchParameters.scope != .thisFolder else {
      return
    }
    guard searchParameters.isEmpty == false else {
      endSearch()
      return
    }
    guard searchParameters.scope != .subfolders || searchOrigin != nil else {
      return
    }
    let query = SearchQuery(parameters: searchParameters, origin: searchOrigin)
    switch location {
    case .search(let current):
      guard current != query else {
        return
      }
      history.replaceCurrent(with: .search(query))
      didChangeLocation()
    default:
      navigate(to: .search(query))
    }
  }

  // MARK: - Select by Pattern

  /// Selects the items whose names match `pattern`, replacing the selection or adding to it, and returns the number
  /// of matching items.
  @discardableResult
  internal func select(matching pattern: NamePattern, addingToSelection: Bool) -> Int {
    let matches = Set(outlineRows.filter { pattern.matches($0.item.name) }.map(\.id))
    selection = addingToSelection ? selection.union(matches) : matches
    return matches.count
  }

  /// The number of items whose names match `pattern`, for the Select by Pattern sheet.
  internal func countMatches(of pattern: NamePattern) -> Int {
    outlineRows.count { pattern.matches($0.item.name) }
  }

  private func scheduleSearch(after delay: Duration = .milliseconds(300)) {
    cancelScheduledSearch()
    scheduledSearch = Task { [weak self] in
      try? await Task.sleep(for: delay)
      guard Task.isCancelled == false else {
        return
      }
      self?.runSearch()
    }
  }

  private func cancelScheduledSearch() {
    scheduledSearch?.cancel()
    scheduledSearch = nil
  }

  /// Returns from search results to where the search started.
  private func leaveSearch() {
    guard let query = location.searchQuery else {
      return
    }
    if let previous = history.backStack.last, previous.searchQuery == nil {
      goBack()
    } else if let origin = query.origin {
      navigate(to: .folder(origin))
    } else if history.canGoBack {
      goBack()
    }
  }

  private func recordRecentSearch(_ parameters: SearchParameters) {
    guard parameters.isEmpty == false else {
      return
    }
    recents?.recordSearch(parameters)
  }

  // MARK: - View Options

  /// Makes the tab's view settings the defaults for new tabs in its view mode, and in list view also its columns.
  internal func saveViewOptionsAsDefaults(to store: SettingsStore = SettingsStore()) {
    store.saveViewDefaults(viewSettings)
    if viewSettings.viewMode == .list, let columns = try? JSONEncoder().encode(columnCustomization) {
      store.saveListColumnDefaults(columns)
    }
  }

  // MARK: - Last Opened Dates

  /// Loads the dates the listed items were last opened. Call it from a view's `.task`.
  internal func loadLastOpenedDates() async {
    let dates = await SpotlightAttributes.lastOpenedDates(of: listing.items.map(\.url))
    guard Task.isCancelled == false else {
      return
    }
    lastOpenedDates = dates
  }

  // MARK: - Private

  private func didChangeLocation() {
    let search = history.current.searchQuery
    if let shownSearch, search == nil {
      recordRecentSearch(shownSearch.parameters)
    }
    shownSearch = search
    searchParameters = search?.parameters ?? SearchParameters()
    if search == nil {
      cancelScheduledSearch()
    }
    selectionModel.deselectAll()
    pendingRevealPaths.removeAll()
    pendingCreatedPaths.removeAll()
    pendingRenamePath = nil
    cancelScheduledRename()
    filterText = ""
    expandedFolders.removeAll()
    recursivelyExpandedFolders.removeAll()
    children.removeAll()
    childrenGenerations.removeAll()
    columnChain.removeAll()
    columnSelections.removeAll()
    columnSelectedItems.removeAll()
    pendingFirstSelectionColumn = nil
    quickLookURL = nil
    renamingItemID = nil
    isEditingPath = false
    lastOpenedDates.removeAll()
    title = history.current.displayName
    if case .folder(let reference) = history.current {
      SettingsStore().set(reference.lastKnownPath, for: SettingsKeys.lastFolderPath)
      recents?.recordVisit(to: reference)
    }
  }

  /// Selects the item at `url` now if the listing contains it, otherwise after the next listing change.
  private func select(revealing url: URL) {
    pendingRevealPaths = [Self.revealKey(for: url)]
    applyPendingReveal()
  }

  /// Selects the created items that the listing shows; the item to rename starts renaming.
  private func applyPendingCreatedItems() {
    guard pendingCreatedPaths.isEmpty == false else {
      return
    }
    let matches = listing.items.filter { pendingCreatedPaths.contains(Self.revealKey(for: $0.url)) }
    guard matches.isEmpty == false else {
      return
    }
    selectionModel.replace(with: Set(matches.map(\.id)))
    // Items that appear in a later listing change are added then.
    if matches.count == pendingCreatedPaths.count {
      pendingCreatedPaths.removeAll()
    }
    if let path = pendingRenamePath, let item = matches.first(where: { Self.revealKey(for: $0.url) == path }) {
      pendingRenamePath = nil
      beginRename(item)
    }
  }

  /// The old and new extension when renaming `item` to `newName` changes the extension of a file or package.
  private static func extensionChange(of item: FileItem, to newName: String) -> (old: String, new: String)? {
    guard item.isDirectory == false || item.isPackage else {
      return nil
    }
    let oldExtension = (item.name as NSString).pathExtension
    let newExtension = (newName as NSString).pathExtension
    guard oldExtension.isEmpty == false, newExtension.isEmpty == false, oldExtension.lowercased() != newExtension.lowercased() else {
      return nil
    }
    return (oldExtension, newExtension)
  }

  private func applyPendingReveal() {
    guard pendingRevealPaths.isEmpty == false else {
      return
    }
    let matches = listing.items.filter { pendingRevealPaths.contains(Self.revealKey(for: $0.url)) }
    guard matches.isEmpty == false else {
      return
    }
    pendingRevealPaths.removeAll()
    selectionModel.replace(with: Set(matches.map(\.id)))
  }

  private func expandLoadedDescendants(of folderID: FileItem.ID) {
    for child in children[folderID] ?? [] where opensAsFolder(child) {
      expandedFolders.insert(child.id)
      recursivelyExpandedFolders.insert(child.id)
      expandLoadedDescendants(of: child.id)
    }
  }

  /// The items in the same folder as `item`.
  private func siblings(of item: FileItem) -> [FileItem] {
    if listing.items.contains(where: { $0.id == item.id }) {
      return listing.items
    }
    return children.values.first { $0.contains { $0.id == item.id } } ?? []
  }

  private static func isPath(_ path: String, inside folder: String) -> Bool {
    let prefix = folder.hasSuffix("/") ? folder : folder + "/"
    return path.hasPrefix(prefix)
  }

  /// The path of `url` without a trailing slash, so that folder URLs from any source compare equal.
  private static func revealKey(for url: URL) -> String {
    url.comparablePath
  }

  /// Whether `url` is the root of a volume: the startup volume or a volume mounted in /Volumes.
  ///
  /// Decided from the path alone, so that ⌘↑ never waits for a slow network volume.
  private static func isVolumeRoot(_ url: URL) -> Bool {
    let path = revealKey(for: url)
    return path == "/" || (path as NSString).deletingLastPathComponent == "/Volumes"
  }
}

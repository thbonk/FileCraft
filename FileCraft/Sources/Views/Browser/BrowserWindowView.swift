/*
 * BrowserWindowView.swift
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

import OSLog
import SwiftUI

/// A browser window: sidebar, one or two file panes, shelf and inspector.
///
/// The window's state is kept in scene storage and restored on relaunch unless restoration is turned off.
internal struct BrowserWindowView: View {

  // MARK: - Properties

  @SceneStorage("browserWindow.snapshot") private var storedSnapshot: Data?
  @AppStorage(SettingsKeys.restoresWindows.name) private var restoresWindows = SettingsKeys.restoresWindows.defaultValue
  @State private var model: BrowserWindowModel
  /// Whether restoring has started, so that it runs once per window.
  @State private var hasStartedRestoring = false
  /// Whether the stored state was applied or found missing. Until then, changes are not stored, so that the
  /// window as created at launch does not overwrite the state it is about to restore.
  @State private var hasRestored = false
  @Environment(\.appearsActive) private var appearsActive
  @Environment(\.dismissWindow) private var dismissWindow
  @Environment(\.openWindow) private var openWindow
  @Environment(\.undoManager) private var undoManager
  /// When the window appeared; an open request that arrives shortly after belongs to a window created for it.
  @State private var appearedAt: Date?

  private static let logger = Logger(subsystem: "de.meandmymac.FileCraft", category: "OpenRequests")
  private static let restorationLogger = Logger(subsystem: "de.meandmymac.FileCraft", category: "WindowRestoration")
  /// How long after appearing an untouched window still counts as created for an open request.
  private static let newWindowInterval: TimeInterval = 1.5

  /// Whether the view reads and writes scene storage; previews use a fixed model instead.
  private let persistsState: Bool
  private let favorites: FavoritesStore
  private let sidebarSources: SidebarSources

  // MARK: - Initialization

  /// Creates a window at the location configured for new windows, recording visited folders in the app's
  /// recents.
  internal init() {
    _model = State(initialValue: BrowserWindowModel(location: Self.newWindowLocation(), recents: .shared))
    persistsState = true
    favorites = .shared
    sidebarSources = .shared
  }

  /// Creates a window showing `model`, without state restoration.
  internal init(model: BrowserWindowModel) {
    _model = State(initialValue: model)
    persistsState = false
    favorites = FavoritesStore(previewFavorites: FavoritesStore.standardFolders)
    sidebarSources = SidebarSources(previewVolumes: PreviewFixtures.volumes, tags: PreviewFixtures.tagNames(in: .english))
  }

  // MARK: - Body

  internal var body: some View {
    NavigationSplitView(columnVisibility: sidebarVisibility) {
      SidebarView(window: model, favorites: favorites, sources: sidebarSources)
        .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 320)
    } detail: {
      ContentAreaView(window: model)
    }
    .inspector(isPresented: $model.layout.isInspectorVisible) {
      InspectorView(window: model)
        .inspectorColumnWidth(min: 220, ideal: 260, max: 420)
    }
    .navigationTitle(model.title)
    .toolbar(id: "browser") {
      BrowserToolbar(window: model)
    }
    .sheet(isPresented: $model.isShowingGoToFolder) {
      GoToFolderSheet(tab: model.activeTab, recents: model.recents)
    }
    .sheet(isPresented: $model.isShowingSelectByPattern) {
      SelectByPatternSheet(tab: model.activeTab)
    }
    .sheet(isPresented: $model.isShowingTags) {
      TagsSheet(urls: model.activeTab.pathTargets)
    }
    .sheet(item: $model.batchRename) { batchRename in
      BatchRenameSheet(model: batchRename, commands: model.fileCommands)
    }
    .focusedSceneValue(\.browserWindow, model)
    .modifier(FileCommandAlerts(commands: model.fileCommands))
    .background {
      tabSwitchingShortcuts
    }
    .onChange(of: model.closeRequest) {
      dismissWindow()
    }
    .onChange(of: model.newWindowRequest) {
      openWindow(id: "browser")
    }
    .onChange(of: model.infoWindowRequest) { _, references in
      if references.isEmpty == false, references.count <= BrowserWindowModel.infoWindowLimit {
        openInfoWindows(references)
      }
    }
    .alert(
      Text("Open \(model.infoWindowRequest.count) info windows?"),
      isPresented: isConfirmingInfoWindows
    ) {
      Button("Open") {
        openInfoWindows(model.infoWindowRequest)
      }
      Button("Cancel", role: .cancel) {
        model.infoWindowRequest = []
      }
    }
    // Open requests from the Dock and other applications go to an existing window; SwiftUI creates a window
    // when none is open.
    .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
    .onOpenURL { url in
      handleOpenRequest(url)
    }
    .onAppear {
      appearedAt = .now
      // File changes register their undo with the window's undo manager, which Edit > Undo uses.
      model.fileCommands.undoManager = undoManager
      // Lets the operations open their window for questions, summaries and the quit confirmation, also after
      // this window closed: the action belongs to the app's scenes, not to this window.
      OperationQueueModel.shared.presentWindow = { [openWindow] in
        openWindow(id: OperationsView.windowID)
      }
      // The welcome window opens once, in front of the first browser window, until the user finished or skipped it.
      if Self.hasOfferedWelcome == false, AppEnvironment.isTestHost == false, WelcomeModel.showsAtLaunch() {
        Self.hasOfferedWelcome = true
        openWindow(id: WelcomeView.windowID)
      }
      // The Dock menu's New Window, which also works after the last window closed.
      AppDelegate.openBrowserWindow = { [openWindow] in
        openWindow(id: "browser")
      }
    }
    .task {
      await restoreStateIfNeeded()
    }
    .task {
      await model.recents?.loadIfNeeded()
    }
    .task {
      await favorites.loadIfNeeded()
    }
    // Favorites renamed or moved in Finder show their new names when FileCraft becomes active again.
    .task(id: appearsActive) {
      if appearsActive {
        BrowserWindowModel.mostRecentlyActive = model
        await favorites.refresh()
      }
    }
    .onDisappear {
      ActiveBrowserWindow.shared.close(model)
    }
    .task {
      guard persistsState else {
        return
      }
      for await event in VolumeMonitor().events() {
        if case .unmounted(let volume) = event {
          model.volumeDidUnmount(volume)
        }
      }
    }
    .onChange(of: model.snapshot) { _, snapshot in
      guard persistsState, hasRestored else {
        return
      }
      storedSnapshot = try? JSONEncoder().encode(snapshot)
    }
  }

  // MARK: - Private

  /// Whether to ask before opening more than `infoWindowLimit` Get Info windows.
  private var isConfirmingInfoWindows: Binding<Bool> {
    Binding {
      model.infoWindowRequest.count > BrowserWindowModel.infoWindowLimit
    } set: { isPresented in
      if isPresented == false {
        model.infoWindowRequest = []
      }
    }
  }

  private func openInfoWindows(_ references: [FileReference]) {
    for reference in references {
      openWindow(id: InfoWindowView.windowID, value: reference)
    }
    model.infoWindowRequest = []
  }

  /// ⌃⇥ and ⌃⇧⇥ switch tabs in addition to the menu's ⇧⌘] and ⇧⌘[. The buttons are invisible but stay in the
  /// view hierarchy, because hidden buttons lose their shortcuts; Shift-Tab arrives as the back-tab character.
  private var tabSwitchingShortcuts: some View {
    Group {
      Button("Show Next Tab") {
        model.selectNextTab()
      }
      .keyboardShortcut(.tab, modifiers: .control)
      Button("Show Previous Tab") {
        model.selectPreviousTab()
      }
      .keyboardShortcut(KeyEquivalent("\u{19}"), modifiers: [.control, .shift])
    }
    .frame(width: 0, height: 0)
    .opacity(0)
    .accessibilityHidden(true)
  }

  private var sidebarVisibility: Binding<NavigationSplitViewVisibility> {
    Binding {
      model.layout.isSidebarVisible ? .all : .detailOnly
    } set: { visibility in
      model.layout.isSidebarVisible = visibility != .detailOnly
    }
  }

  /// Shows a folder or reveals a file that the Dock or another application asked FileCraft to open.
  private func handleOpenRequest(_ url: URL) {
    guard url.isFileURL else {
      return
    }
    let isNewWindow = model.isUntouched && appearedAt.map { Date.now.timeIntervalSince($0) < Self.newWindowInterval } != false
    Self.logger.debug("Open request \(url.path(percentEncoded: false), privacy: .private), new window: \(isNewWindow)")
    Task {
      guard let item = try? await FileSystemService().item(at: url) else {
        return
      }
      model.showRequested(item, usesCurrentTab: isNewWindow)
    }
  }

  private func restoreStateIfNeeded() async {
    guard persistsState, hasStartedRestoring == false else {
      return
    }
    hasStartedRestoring = true
    // The stored state of a restored window arrives only once AppKit restores the window.
    await LaunchRestoration.waitUntilFinished()
    // A window opened for a particular folder has no stored state; it shows that folder instead of the default.
    if storedSnapshot == nil, let location = NewWindowQueue.pop() {
      model.activeTab.replaceLocation(with: location)
    }
    defer {
      hasRestored = true
      // Stores the state at once, also when nothing was restored.
      storedSnapshot = try? JSONEncoder().encode(model.snapshot)
    }
    guard restoresWindows else {
      Self.restorationLogger.info("Not restoring: Restore windows is off")
      return
    }
    guard let storedSnapshot else {
      Self.restorationLogger.info("Not restoring: the window has no stored state")
      return
    }
    let snapshot: BrowserWindowSnapshot
    do {
      snapshot = try JSONDecoder().decode(BrowserWindowSnapshot.self, from: storedSnapshot)
    } catch {
      Self.restorationLogger.error("Not restoring: the stored state cannot be read: \(error, privacy: .public)")
      return
    }
    guard snapshot.version == BrowserWindowSnapshot.currentVersion else {
      Self.restorationLogger.info("Not restoring: the stored state has version \(snapshot.version)")
      return
    }
    let resolvedSnapshot = await LocationResolver.resolved(snapshot)
    model.restore(from: resolvedSnapshot, fallback: model.activeTab.location)
    let modes = resolvedSnapshot.primaryPane.tabs.map(\.viewSettings.viewMode.rawValue)
    Self.restorationLogger.info("Restored a window with view modes \(modes, privacy: .public)")
  }

  /// Whether this launch already opened the welcome window.
  private static var hasOfferedWelcome = false

  private static func newWindowLocation() -> Location {
    let settings = SettingsStore()
    let folder = LocationResolver.newWindowFolder(
      for: settings.value(for: SettingsKeys.newWindowLocation),
      chosenPath: settings.value(for: SettingsKeys.newWindowFolderPath),
      lastPath: settings.value(for: SettingsKeys.lastFolderPath))
    let reference = (try? FileReference(url: folder)) ?? FileReference(unresolvedURL: folder)
    return .folder(reference)
  }
}

#Preview("English") {
  BrowserWindowView(model: .preview(in: .english))
    .frame(width: 900, height: 560)
}

#Preview("German") {
  BrowserWindowView(model: .preview(in: .german))
    .frame(width: 900, height: 560)
    .environment(\.locale, Locale(identifier: "de"))
}

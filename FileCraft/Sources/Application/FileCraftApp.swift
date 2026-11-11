/*
 * FileCraftApp.swift
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

import AppKit
import SwiftUI

@main struct FileCraftApp: App {

  // MARK: - Properties

  /// Asks before quitting while file operations run (design decision D9).
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  // MARK: - Initialization

  init() {
    // Tabs live inside each pane, so system window tabs would compete with them.
    NSWindow.allowsAutomaticWindowTabbing = false
    SettingsStore().registerDefaults()
    SettingsStore().applyWindowRestoration()
    LaunchRestoration.start()
    // Started before the first window, so that its sidebar appears with volumes, tags and favorites.
    SidebarSources.shared.start()
    OperationQueueModel.shared.start()
    // Test runs launch FileCraft as their host and must not change the user's file viewer or quit Finder; their
    // settings come from the test host's own defaults suite, not from the user's.
    if AppEnvironment.isTestHost == false {
      // Another application may have taken over the file viewer, or a reset left FileCraft in it.
      DefaultFileViewer().correctDrift(usesFileCraft: SettingsStore().value(for: SettingsKeys.usesFileCraftAsFileViewer))
      Task {
        let settings = SettingsStore()
        await FinderReplacement().applyAtLaunch(
          quitsFinder: settings.value(for: SettingsKeys.quitsFinderOnLaunch),
          hidesDesktop: settings.value(for: SettingsKeys.hidesFinderDesktop))
      }
    }
    Task {
      await FavoritesStore.shared.loadIfNeeded()
    }
    Task {
      await PutBackStore.shared.loadIfNeeded()
    }
    Task {
      await ShelfStore.shared.loadIfNeeded()
    }
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-FCHelperSelfTest") {
        Task { await HelperSelfTest.run() }
      }
    #endif
  }

  // MARK: - Body

  // Each scene reads `@AppStorage` from `AppEnvironment.userDefaults`, which `SettingsStore` also uses.
  var body: some Scene {
    WindowGroup(id: "browser") {
      BrowserWindowView()
    }
    .defaultAppStorage(AppEnvironment.userDefaults)
    // AppKit saves a browser window's toolbar, split view and frame into the user's real defaults, so the test
    // host launches without one; tests create the models and views they need.
    .defaultLaunchBehavior(AppEnvironment.isTestHost ? .suppressed : .automatic)
    .handlesExternalEvents(matching: ["*"])
    .commands {
      TabCommands()
      BrowserCommands(favorites: .shared)
      GoCommands(recents: .shared)
      ToolsCommands()
      HelpCommands()
    }

    // One Get Info window per item; opening an item's window again brings the existing one forward.
    Settings {
      SettingsView()
    }
    .defaultAppStorage(AppEnvironment.userDefaults)
    Window("Welcome to FileCraft", id: WelcomeView.windowID) {
      WelcomeView()
    }
    .defaultAppStorage(AppEnvironment.userDefaults)
    .windowResizability(.contentSize)
    .commandsRemoved()
    Window("Keyboard Shortcuts", id: KeyboardShortcutsView.windowID) {
      KeyboardShortcutsView()
    }
    .defaultAppStorage(AppEnvironment.userDefaults)
    .commandsRemoved()
    WindowGroup("Info", id: InfoWindowView.windowID, for: FileReference.self) { $reference in
      InfoWindowView(reference: reference)
    }
    .defaultAppStorage(AppEnvironment.userDefaults)
    .windowResizability(.contentSize)
    .commandsRemoved()

    // The automatic command of a utility window is a generic "Show Window" without a shortcut, so
    // BrowserCommands adds View > Show View Options (⌘J) instead.
    UtilityWindow("View Options", id: ViewOptionsView.windowID) {
      ViewOptionsView()
    }
    .defaultAppStorage(AppEnvironment.userDefaults)
    .commandsRemoved()
    .windowResizability(.contentSize)

    // Window > Operations comes from TabCommands, which places it after the tab commands as the spec orders it.
    Window("Operations", id: OperationsView.windowID) {
      OperationsView(model: .shared)
    }
    .defaultAppStorage(AppEnvironment.userDefaults)
    .commandsRemoved()
    .defaultSize(width: 520, height: 320)
    .restorationBehavior(.disabled)
  }
}

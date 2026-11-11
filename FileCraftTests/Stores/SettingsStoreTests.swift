/*
 * SettingsStoreTests.swift
 * FileCraftTests
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
import Testing
@testable import FileCraft

/// Uses a private defaults suite per test, removed again in `deinit`.
internal final class SettingsStoreTests {

  // MARK: - Properties

  private let suiteName = "FileCraftTests.\(UUID().uuidString)"
  private let defaults: UserDefaults
  private let store: SettingsStore

  // MARK: - Initialization

  internal init() throws {
    defaults = try #require(UserDefaults(suiteName: suiteName))
    store = SettingsStore(defaults: defaults)
  }

  isolated deinit {
    defaults.removePersistentDomain(forName: suiteName)
  }

  // MARK: - Tests

  @Test
  internal func `Restore windows decides whether macOS keeps FileCraft's windows on quit`() {
    store.applyWindowRestoration()
    let keepsByDefault = defaults.bool(forKey: SettingsStore.quitKeepsWindowsKey)
    store.set(false, for: SettingsKeys.restoresWindows)
    store.applyWindowRestoration()
    let keepsWhenOff = defaults.object(forKey: SettingsStore.quitKeepsWindowsKey) as? Bool

    #expect(keepsByDefault)
    #expect(keepsWhenOff == false)
  }

  @Test
  internal func `Settings written in the test host stay out of the user's defaults`() {
    let key = SettingsKeys.lastFolderPath
    let usersValue = UserDefaults.standard.object(forKey: key.name)
    let path = "/FileCraftTests/\(UUID().uuidString)/"
    defer {
      // Puts the user's value back if the store wrote the user's defaults.
      if UserDefaults.standard.string(forKey: key.name) == path {
        UserDefaults.standard.set(usersValue, forKey: key.name)
      }
    }

    SettingsStore().set(path, for: key)

    #expect(SettingsStore().value(for: key) == path)
    #expect(UserDefaults.standard.string(forKey: key.name) != path)
  }

  @Test
  internal func `Unset keys return the defaults from the settings spec`() {
    #expect(store.value(for: SettingsKeys.newWindowLocation) == .home)
    #expect(store.value(for: SettingsKeys.folderOpeningBehavior) == .sameTab)
    #expect(store.value(for: SettingsKeys.defaultViewMode) == .list)
    #expect(store.value(for: SettingsKeys.showsHiddenFiles) == false)
    #expect(store.value(for: SettingsKeys.foldersFirst))
    #expect(store.value(for: SettingsKeys.textSize) == .medium)
    #expect(store.value(for: SettingsKeys.returnKeyAction) == .rename)
    #expect(store.value(for: SettingsKeys.hidesSingleTabBar))
    #expect(store.value(for: SettingsKeys.usesFunctionKeys))
    #expect(store.value(for: SettingsKeys.compressionFormat) == .zip)
    #expect(store.value(for: SettingsKeys.terminalBundleIdentifier) == "com.apple.Terminal")
    #expect(store.value(for: SettingsKeys.usesFileCraftAsFileViewer) == false)
    #expect(store.value(for: SettingsKeys.sizeUnits) == .decimal)
  }

  @Test
  internal func `Registered defaults are visible through UserDefaults`() {
    store.registerDefaults()

    #expect(defaults.bool(forKey: SettingsKeys.restoresWindows.name))
    #expect(defaults.string(forKey: SettingsKeys.dualPaneLayout.name) == PaneLayout.sideBySide.rawValue)
    #expect(defaults.double(forKey: SettingsKeys.springLoadingDelay.name) == 0.5)
  }

  @Test
  internal func `Stored values are read back with their type`() {
    store.set(.columns, for: SettingsKeys.defaultViewMode)
    store.set(true, for: SettingsKeys.showsHiddenFiles)

    #expect(store.value(for: SettingsKeys.defaultViewMode) == .columns)
    #expect(store.value(for: SettingsKeys.showsHiddenFiles))
  }

  @Test
  internal func `Restoring a pane leaves other panes unchanged`() {
    store.set(true, for: SettingsKeys.showsHiddenFiles)
    store.set(.tarXz, for: SettingsKeys.compressionFormat)

    store.restoreDefaults(of: .browser)

    #expect(store.value(for: SettingsKeys.showsHiddenFiles) == false)
    #expect(store.value(for: SettingsKeys.compressionFormat) == .tarXz)
  }

  @Test
  internal func `Reset Warnings turns all warnings back on`() {
    store.set(false, for: SettingsKeys.warnsBeforeEmptyingTrash)
    store.set(false, for: SettingsKeys.warnsBeforeChangingExtension)
    store.set(true, for: SettingsKeys.verifiesCopies)

    store.resetWarnings()

    #expect(store.value(for: SettingsKeys.warnsBeforeEmptyingTrash))
    #expect(store.value(for: SettingsKeys.warnsBeforeChangingExtension))
    #expect(store.value(for: SettingsKeys.verifiesCopies))
  }

  @Test
  internal func `Restore Defaults of each pane resets exactly the keys of that pane`() {
    for pane in SettingsPane.allCases {
      for key in SettingsKeys.all {
        defaults.set("changed", forKey: key.name)
      }

      store.restoreDefaults(of: pane)

      let stored = defaults.persistentDomain(forName: suiteName) ?? [:]
      for key in SettingsKeys.all {
        let isReset = stored[key.name] == nil
        #expect(isReset == (key.pane == pane && key.isState == false), "\(key.name) after restoring \(pane)")
      }
    }
  }

  @Test
  internal func `Reset All Settings restores every key and the view defaults`() {
    store.set(true, for: SettingsKeys.showsHiddenFiles)
    store.set(SizeUnits.binary, for: SettingsKeys.sizeUnits)
    store.set(FolderOpeningBehavior.newWindow, for: SettingsKeys.folderOpeningBehavior)
    store.saveListColumnDefaults(Data([1, 2, 3]))

    store.resetAll()

    #expect(store.value(for: SettingsKeys.showsHiddenFiles) == false)
    #expect(store.value(for: SettingsKeys.sizeUnits) == .decimal)
    #expect(store.value(for: SettingsKeys.folderOpeningBehavior) == .sameTab)
    #expect(store.listColumnDefaults() == nil)
  }

  @Test
  internal func `Every key has a unique name`() {
    let names = SettingsKeys.all.map(\.name)

    #expect(Set(names).count == names.count)
  }

  @Test
  internal func `Use as Defaults applies to new tabs in the same view mode only`() {
    let tab = TabModel(location: .tag("Test"), viewSettings: ViewSettings(settings: store))
    tab.viewSettings.usesRelativeDates.toggle()
    tab.viewSettings.iconSize = 128

    tab.saveViewOptionsAsDefaults(to: store)
    let newListSettings = ViewSettings(settings: store)
    store.set(.icons, for: SettingsKeys.defaultViewMode)
    let newIconSettings = ViewSettings(settings: store)

    #expect(tab.viewSettings.viewMode == .list)
    #expect(newListSettings.usesRelativeDates == !ViewSettings().usesRelativeDates)
    #expect(newListSettings.iconSize == 128)
    #expect(newIconSettings.viewMode == .icons)
    #expect(newIconSettings.iconSize == ViewSettings().iconSize)
    #expect(store.listColumnDefaults() != nil)
  }
}

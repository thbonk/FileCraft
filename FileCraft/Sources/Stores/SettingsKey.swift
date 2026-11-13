/*
 * SettingsKey.swift
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

/// A value that can be stored in user defaults.
nonisolated internal protocol SettingsValue: Sendable {
  /// The value as stored in user defaults.
  var propertyListValue: any Sendable { get }

  init?(propertyListValue: Any)
}

extension Bool: SettingsValue {
  nonisolated internal var propertyListValue: any Sendable {
    self
  }

  nonisolated internal init?(propertyListValue: Any) {
    guard let value = propertyListValue as? Bool else {
      return nil
    }
    self = value
  }
}

extension Double: SettingsValue {
  nonisolated internal var propertyListValue: any Sendable {
    self
  }

  nonisolated internal init?(propertyListValue: Any) {
    guard let value = propertyListValue as? Double else {
      return nil
    }
    self = value
  }
}

extension String: SettingsValue {
  nonisolated internal var propertyListValue: any Sendable {
    self
  }

  nonisolated internal init?(propertyListValue: Any) {
    guard let value = propertyListValue as? String else {
      return nil
    }
    self = value
  }
}

extension SettingsValue where Self: RawRepresentable, RawValue == String {
  nonisolated internal var propertyListValue: any Sendable {
    rawValue
  }

  nonisolated internal init?(propertyListValue: Any) {
    guard let rawValue = propertyListValue as? String else {
      return nil
    }
    self.init(rawValue: rawValue)
  }
}

/// A typed user-defaults key with its default value.
///
/// Views read keys with `@AppStorage(key.name)`; other code uses `SettingsStore`.
nonisolated internal struct SettingsKey<Value: SettingsValue>: Sendable {
  internal let name: String
  internal let defaultValue: Value
  internal let pane: SettingsPane
  /// Whether the key suppresses a warning, so that Reset Warnings restores it.
  internal let isWarning: Bool
  /// Whether the key records state rather than a setting, such as the last folder shown; Restore Defaults of its
  /// pane keeps it, Reset All Settings does not.
  internal let isState: Bool

  internal init(_ name: String, default defaultValue: Value, pane: SettingsPane, isWarning: Bool = false, isState: Bool = false) {
    self.name = name
    self.defaultValue = defaultValue
    self.pane = pane
    self.isWarning = isWarning
    self.isState = isState
  }
}

/// A type-erased settings key, used to register and reset defaults.
nonisolated internal struct AnySettingsKey: Sendable {
  internal let name: String
  internal let defaultValue: any Sendable
  internal let pane: SettingsPane
  internal let isWarning: Bool
  internal let isState: Bool

  internal init<Value>(_ key: SettingsKey<Value>) {
    name = key.name
    defaultValue = key.defaultValue.propertyListValue
    pane = key.pane
    isWarning = key.isWarning
    isState = key.isState
  }
}

/// All persisted preferences with the defaults defined by the `settings` capability.
///
/// Sparkle reads and writes its two update preferences under its own keys; they are listed here so that Restore
/// Defaults and Reset All Settings cover them too.
nonisolated internal enum SettingsKeys {

  // MARK: - General

  internal static let newWindowLocation = SettingsKey("general.newWindowLocation", default: NewWindowLocation.home, pane: .general)
  internal static let newWindowFolderPath = SettingsKey("general.newWindowFolderPath", default: "", pane: .general)
  internal static let folderOpeningBehavior = SettingsKey("general.folderOpeningBehavior", default: FolderOpeningBehavior.sameTab, pane: .general)
  internal static let restoresWindows = SettingsKey("general.restoresWindows", default: true, pane: .general)
  internal static let hasCompletedWelcome = SettingsKey("general.hasCompletedWelcome", default: false, pane: .general, isState: true)
  /// The folder shown last, used when new windows open at the last location.
  internal static let lastFolderPath = SettingsKey("general.lastFolderPath", default: "", pane: .general, isState: true)
  /// Sparkle's key for checking for updates automatically; the app's Info.plist sets the same default.
  internal static let checksForUpdates = SettingsKey("SUEnableAutomaticChecks", default: true, pane: .general)
  /// Sparkle's key for installing updates automatically.
  internal static let installsUpdates = SettingsKey("SUAutomaticallyUpdate", default: false, pane: .general)
  /// Whether updates include pre-releases, which the appcast lists on Sparkle's channel "beta".
  internal static let includesPreReleases = SettingsKey("general.includesPreReleases", default: false, pane: .general)

  // MARK: - Browser

  internal static let defaultViewMode = SettingsKey("browser.defaultViewMode", default: ViewMode.list, pane: .browser)
  internal static let showsHiddenFiles = SettingsKey("browser.showsHiddenFiles", default: false, pane: .browser)
  internal static let alwaysShowsFileExtensions = SettingsKey("browser.alwaysShowsFileExtensions", default: false, pane: .browser)
  internal static let foldersFirst = SettingsKey("browser.foldersFirst", default: true, pane: .browser)
  internal static let usesRelativeDates = SettingsKey("browser.usesRelativeDates", default: true, pane: .browser)
  internal static let calculatesFolderSizes = SettingsKey("browser.calculatesFolderSizes", default: false, pane: .browser)
  internal static let showsIconPreviews = SettingsKey("browser.showsIconPreviews", default: true, pane: .browser)
  internal static let textSize = SettingsKey("browser.textSize", default: BrowserTextSize.medium, pane: .browser)
  internal static let returnKeyAction = SettingsKey("browser.returnKeyAction", default: ReturnKeyAction.rename, pane: .browser)
  internal static let springLoadsFolders = SettingsKey("browser.springLoadsFolders", default: true, pane: .browser)
  /// The spring-loading delay in seconds.
  internal static let springLoadingDelay = SettingsKey("browser.springLoadingDelay", default: 0.5, pane: .browser)
  internal static let treatsPackagesAsFolders = SettingsKey("browser.treatsPackagesAsFolders", default: false, pane: .browser)

  // MARK: - Sidebar

  internal static let showsFavorites = SettingsKey("sidebar.showsFavorites", default: true, pane: .sidebar)
  internal static let showsLocations = SettingsKey("sidebar.showsLocations", default: true, pane: .sidebar)
  internal static let showsICloud = SettingsKey("sidebar.showsICloud", default: true, pane: .sidebar)
  internal static let showsTags = SettingsKey("sidebar.showsTags", default: true, pane: .sidebar)
  internal static let showsVolumeUsage = SettingsKey("sidebar.showsVolumeUsage", default: false, pane: .sidebar)

  // MARK: - Tabs & Panes

  internal static let newTabLocation = SettingsKey("tabs.newTabLocation", default: NewTabLocation.currentLocation, pane: .tabsAndPanes)
  internal static let hidesSingleTabBar = SettingsKey("tabs.hidesSingleTabBar", default: true, pane: .tabsAndPanes)
  internal static let dualPaneLayout = SettingsKey("tabs.dualPaneLayout", default: PaneLayout.sideBySide, pane: .tabsAndPanes)
  internal static let usesFunctionKeys = SettingsKey("tabs.usesFunctionKeys", default: true, pane: .tabsAndPanes)

  // MARK: - File Operations

  internal static let warnsBeforeEmptyingTrash = SettingsKey("fileOperations.warnsBeforeEmptyingTrash", default: true, pane: .fileOperations, isWarning: true)
  internal static let warnsBeforeChangingExtension = SettingsKey("fileOperations.warnsBeforeChangingExtension", default: true, pane: .fileOperations, isWarning: true)
  internal static let verifiesCopies = SettingsKey("fileOperations.verifiesCopies", default: false, pane: .fileOperations)
  internal static let showsOperationsAutomatically = SettingsKey("fileOperations.showsOperationsAutomatically", default: true, pane: .fileOperations)

  // MARK: - Compression

  internal static let compressionFormat = SettingsKey("compression.format", default: CompressionFormat.zip, pane: .compression)
  internal static let archiveDestination = SettingsKey("compression.destination", default: ArchiveDestination.sameFolder, pane: .compression)
  internal static let archiveDestinationPath = SettingsKey("compression.destinationPath", default: "", pane: .compression)
  internal static let selectsResult = SettingsKey("compression.selectsResult", default: true, pane: .compression)
  internal static let expandsArchivesInFileCraft = SettingsKey("compression.expandsArchivesInFileCraft", default: true, pane: .compression)
  internal static let trashesArchiveAfterExpanding = SettingsKey("compression.trashesArchiveAfterExpanding", default: false, pane: .compression)

  // MARK: - Integration

  internal static let terminalBundleIdentifier = SettingsKey("integration.terminalBundleIdentifier", default: "com.apple.Terminal", pane: .integration)
  internal static let usesFileCraftAsFileViewer = SettingsKey("integration.usesFileCraftAsFileViewer", default: false, pane: .integration)
  internal static let removesShelfItemsAfterDrag = SettingsKey("integration.removesShelfItemsAfterDrag", default: false, pane: .integration)
  internal static let quitsFinderOnLaunch = SettingsKey("integration.quitsFinderOnLaunch", default: false, pane: .integration)
  internal static let hidesFinderDesktop = SettingsKey("integration.hidesFinderDesktop", default: false, pane: .integration)

  // MARK: - Advanced

  internal static let sizeUnits = SettingsKey("advanced.sizeUnits", default: SizeUnits.decimal, pane: .advanced)

  // MARK: - All Keys

  internal static let all: [AnySettingsKey] = [
    AnySettingsKey(newWindowLocation),
    AnySettingsKey(newWindowFolderPath),
    AnySettingsKey(folderOpeningBehavior),
    AnySettingsKey(restoresWindows),
    AnySettingsKey(hasCompletedWelcome),
    AnySettingsKey(lastFolderPath),
    AnySettingsKey(checksForUpdates),
    AnySettingsKey(installsUpdates),
    AnySettingsKey(includesPreReleases),
    AnySettingsKey(defaultViewMode),
    AnySettingsKey(showsHiddenFiles),
    AnySettingsKey(alwaysShowsFileExtensions),
    AnySettingsKey(foldersFirst),
    AnySettingsKey(usesRelativeDates),
    AnySettingsKey(calculatesFolderSizes),
    AnySettingsKey(showsIconPreviews),
    AnySettingsKey(textSize),
    AnySettingsKey(returnKeyAction),
    AnySettingsKey(springLoadsFolders),
    AnySettingsKey(springLoadingDelay),
    AnySettingsKey(treatsPackagesAsFolders),
    AnySettingsKey(showsFavorites),
    AnySettingsKey(showsLocations),
    AnySettingsKey(showsICloud),
    AnySettingsKey(showsTags),
    AnySettingsKey(showsVolumeUsage),
    AnySettingsKey(newTabLocation),
    AnySettingsKey(hidesSingleTabBar),
    AnySettingsKey(dualPaneLayout),
    AnySettingsKey(usesFunctionKeys),
    AnySettingsKey(warnsBeforeEmptyingTrash),
    AnySettingsKey(warnsBeforeChangingExtension),
    AnySettingsKey(verifiesCopies),
    AnySettingsKey(showsOperationsAutomatically),
    AnySettingsKey(compressionFormat),
    AnySettingsKey(archiveDestination),
    AnySettingsKey(archiveDestinationPath),
    AnySettingsKey(selectsResult),
    AnySettingsKey(expandsArchivesInFileCraft),
    AnySettingsKey(trashesArchiveAfterExpanding),
    AnySettingsKey(terminalBundleIdentifier),
    AnySettingsKey(usesFileCraftAsFileViewer),
    AnySettingsKey(removesShelfItemsAfterDrag),
    AnySettingsKey(quitsFinderOnLaunch),
    AnySettingsKey(hidesFinderDesktop),
    AnySettingsKey(sizeUnits),
  ]
}

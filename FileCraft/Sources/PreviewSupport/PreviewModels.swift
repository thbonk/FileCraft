/*
 * PreviewModels.swift
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

extension TabModel {
  /// A tab showing the preview home folder with static items that never touch the file system.
  internal static func preview(in language: PreviewFixtures.Language) -> TabModel {
    TabModel(
      location: .folder(FileReference(unresolvedURL: PreviewFixtures.homeFolder)),
      listing: DirectoryListing(staticItems: PreviewFixtures.items(in: language), availableCapacity: 412_301_337_600))
  }
}

extension BrowserWindowModel {
  /// A single-pane window showing the preview home folder.
  internal static func preview(in language: PreviewFixtures.Language) -> BrowserWindowModel {
    BrowserWindowModel(primaryPane: PaneModel(tab: .preview(in: language)))
  }
}

extension UpdaterModel {
  /// A model with a stand-in updater that never checks for updates, keeping its settings in a preview suite.
  internal static func preview() -> UpdaterModel {
    UpdaterModel(
      updater: PreviewUpdater(),
      settings: SettingsStore(defaults: UserDefaults(suiteName: "FileCraftPreview") ?? .standard),
      isBusy: { false },
      confirmQuit: { _ in })
  }
}

/// Stands in for Sparkle's updater in previews.
private final class PreviewUpdater: SoftwareUpdater {
  var canCheckForUpdates = true
  var automaticallyChecksForUpdates = true
  var automaticallyDownloadsUpdates = false

  func checkForUpdates() {}
}

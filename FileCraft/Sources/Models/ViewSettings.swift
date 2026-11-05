/*
 * ViewSettings.swift
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

/// Where icon view places item names.
nonisolated internal enum LabelPosition: String, CaseIterable, Codable, Sendable {
  case bottom
  case right
}

/// How one tab presents its items.
nonisolated internal struct ViewSettings: Codable, Hashable, Sendable {

  // MARK: - Properties

  internal var viewMode: ViewMode = .list
  internal var sortOrder = ItemSortOrder()
  internal var grouping: GroupingKey = .none
  /// Whether packages such as apps open like folders in this tab.
  internal var treatsPackagesAsFolders = false
  internal var usesRelativeDates = true
  internal var calculatesFolderSizes = false
  /// The icon size of icon view in points.
  internal var iconSize = 64.0
  internal var labelPosition: LabelPosition = .bottom
  /// Whether icon view shows image dimensions or item counts below names.
  internal var showsItemInfo = false
  internal var showsIconPreviews = true
  internal var showsPreviewColumn = true
  internal var textSize: BrowserTextSize = .medium

  internal static let iconSizeRange = 16.0...512.0

  // MARK: - Initialization

  internal init() {}

  /// Creates view settings for a new tab: the defaults saved with "Use as Defaults" for the default
  /// view mode, otherwise the defaults chosen in the Browser settings.
  internal init(settings: SettingsStore) {
    let viewMode = settings.value(for: SettingsKeys.defaultViewMode)
    if let savedDefaults = settings.viewDefaults(for: viewMode) {
      self = savedDefaults
      self.viewMode = viewMode
      return
    }
    self.viewMode = viewMode
    sortOrder.foldersFirst = settings.value(for: SettingsKeys.foldersFirst)
    treatsPackagesAsFolders = settings.value(for: SettingsKeys.treatsPackagesAsFolders)
    usesRelativeDates = settings.value(for: SettingsKeys.usesRelativeDates)
    calculatesFolderSizes = settings.value(for: SettingsKeys.calculatesFolderSizes)
    showsIconPreviews = settings.value(for: SettingsKeys.showsIconPreviews)
    textSize = settings.value(for: SettingsKeys.textSize)
  }
}

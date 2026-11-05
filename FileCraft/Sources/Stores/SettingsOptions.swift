/*
 * SettingsOptions.swift
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

/// The panes of the Settings window.
nonisolated internal enum SettingsPane: String, CaseIterable, Sendable {
  case general
  case browser
  case sidebar
  case tabsAndPanes
  case fileOperations
  case compression
  case integration
  case helper
  case advanced
}

/// Where new browser windows open.
nonisolated internal enum NewWindowLocation: String, CaseIterable, Sendable, SettingsValue {
  case home
  case desktop
  case documents
  case lastLocation
  case chosenFolder
}

/// Where double-clicked folders open.
nonisolated internal enum FolderOpeningBehavior: String, CaseIterable, Sendable, SettingsValue {
  case sameTab
  case newTab
  case newWindow
}

/// The text size of file views, sidebar and inspector.
nonisolated internal enum BrowserTextSize: String, CaseIterable, Codable, Sendable, SettingsValue {
  case small
  case medium
  case large
}

/// What the Return key does with the selected item.
nonisolated internal enum ReturnKeyAction: String, CaseIterable, Sendable, SettingsValue {
  case rename
  case open
}

/// Where new tabs open.
nonisolated internal enum NewTabLocation: String, CaseIterable, Sendable, SettingsValue {
  case currentLocation
  case home
}

/// How the two panes of a dual-pane window are arranged.
nonisolated internal enum PaneLayout: String, CaseIterable, Codable, Sendable, SettingsValue {
  case sideBySide
  case stacked
}

/// The archive format used by Compress.
nonisolated internal enum CompressionFormat: String, CaseIterable, Sendable, SettingsValue {
  case zip
  case tarGzip
  case tarBzip2
  case tarXz
}

/// Where archives and expanded items are placed.
nonisolated internal enum ArchiveDestination: String, CaseIterable, Sendable, SettingsValue {
  case sameFolder
  case chosenFolder
}

/// How sizes are displayed.
nonisolated internal enum SizeUnits: String, CaseIterable, Sendable, SettingsValue {
  /// 1 KB is 1,000 bytes.
  case decimal
  /// 1 KiB is 1,024 bytes.
  case binary
}

extension ViewMode: SettingsValue {}

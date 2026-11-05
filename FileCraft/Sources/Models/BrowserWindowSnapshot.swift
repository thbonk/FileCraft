/*
 * BrowserWindowSnapshot.swift
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

/// The restorable state of one tab.
nonisolated internal struct TabSnapshot: Codable, Hashable, Sendable {
  internal var history: NavigationHistory
  internal var viewSettings: ViewSettings
}

/// The restorable state of one pane.
nonisolated internal struct PaneSnapshot: Codable, Hashable, Sendable {
  internal var tabs: [TabSnapshot]
  internal var currentTabIndex: Int
}

/// The restorable state of a browser window, stored in the window's scene storage.
nonisolated internal struct BrowserWindowSnapshot: Codable, Hashable, Sendable {

  /// The version of this format, increased whenever stored snapshots need migration.
  internal static let currentVersion = 4

  internal var version = BrowserWindowSnapshot.currentVersion
  internal var primaryPane: PaneSnapshot
  internal var secondaryPane: PaneSnapshot?
  internal var isDualPaneVisible: Bool
  internal var isSecondaryPaneActive: Bool
  internal var layout: WindowLayout
}

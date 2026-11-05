/*
 * WindowLayout.swift
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

/// The visibility and sizes of a browser window's areas.
nonisolated internal struct WindowLayout: Codable, Hashable, Sendable {

  // MARK: - Properties

  internal var isSidebarVisible = true
  internal var isInspectorVisible = false
  internal var isShelfVisible = false
  internal var isPathBarVisible = true
  internal var isStatusBarVisible = true
  /// View > Show Tab Bar: shows the tab bar of every pane, also of panes with a single tab.
  internal var showsTabBar = false
  internal var paneLayout: PaneLayout = .sideBySide

  /// The share of the content area taken by the first pane, between 0 and 1.
  internal var paneSplitFraction = 0.5

  /// The height of the shelf in points.
  internal var shelfHeight = 120.0

  // MARK: - Limits

  internal static let paneSplitFractionRange = 0.15...0.85
  internal static let shelfHeightRange = 70.0...400.0
}

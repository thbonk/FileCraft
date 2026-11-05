/*
 * PaneView.swift
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

import SwiftUI

/// One file pane: tab bar, path bar, file view and status bar of the pane's current tab.
///
/// The pane loads and watches its folder while it is on screen.
internal struct PaneView: View {

  // MARK: - Properties

  internal let pane: PaneModel
  internal let window: BrowserWindowModel

  @AppStorage(SettingsKeys.showsHiddenFiles.name) private var showsHiddenFiles = SettingsKeys.showsHiddenFiles.defaultValue
  @AppStorage(SettingsKeys.hidesSingleTabBar.name) private var hidesSingleTabBar = SettingsKeys.hidesSingleTabBar.defaultValue
  @AppStorage(SettingsKeys.sizeUnits.name) private var sizeUnits = SettingsKeys.sizeUnits.defaultValue

  private var isActive: Bool {
    window.isActive(pane)
  }

  /// Whether the pane marks itself as active; only dual-pane windows need the marker.
  private var showsActiveIndicator: Bool {
    window.isDualPaneVisible
  }

  private var layout: WindowLayout {
    window.layout
  }

  /// A pane with a single tab hides its tab bar, unless Settings or View > Show Tab Bar say otherwise.
  private var showsTabBar: Bool {
    pane.tabs.count > 1 || hidesSingleTabBar == false || layout.showsTabBar
  }

  // MARK: - Body

  internal var body: some View {
    let tab = pane.currentTab
    VStack(spacing: 0) {
      if showsTabBar {
        TabBarView(pane: pane, window: window)
        Divider()
      }
      if layout.isPathBarVisible {
        PathBarView(tab: tab, isHighlighted: showsActiveIndicator && isActive)
          // Path completions float over the file view below.
          .zIndex(1)
        Divider()
      }
      if tab.showsSearchBar {
        SearchBarView(tab: tab)
        Divider()
      }
      FileViewContainer(tab: tab)
        .task(id: ListingKey(tab: tab.id, location: tab.location, includesHiddenItems: showsHiddenFiles)) {
          switch tab.location {
          case .folder(let reference):
            await tab.listing.observe(reference.lastKnownURL, includingHiddenItems: showsHiddenFiles)
          case .computer:
            await tab.listing.observeVolumes()
          case .tag(let name):
            await tab.listing.loadTaggedItems(name)
          case .search(let query):
            await tab.listing.observeSearch(query, sizeUnits: sizeUnits)
          }
        }
      if layout.isStatusBarVisible {
        Divider()
        StatusBarView(tab: tab)
      }
    }
    .overlay {
      if showsActiveIndicator && isActive {
        Rectangle()
          .strokeBorder(.tint, lineWidth: 2)
          .allowsHitTesting(false)
      }
    }
    .simultaneousGesture(
      TapGesture().onEnded {
        window.activate(pane)
      })
  }
}

/// Identifies what a pane loads; a change restarts loading. The tab belongs to it because each tab has its own
/// listing: a restored window replaces its tabs with new ones that can show the same location.
nonisolated private struct ListingKey: Hashable {
  let tab: TabModel.ID
  let location: Location
  let includesHiddenItems: Bool
}

#Preview {
  let window = BrowserWindowModel.preview(in: .english)

  return PaneView(pane: window.primaryPane, window: window)
    .frame(width: 520, height: 360)
}

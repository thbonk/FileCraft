/*
 * BrowserSettingsPanes.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-05.
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

// MARK: - General

/// The General pane: where new windows open, where folders open and window restoration.
///
/// The update settings join this pane with Sparkle (task group 17).
internal struct GeneralSettingsPane: View {

  @AppStorage(SettingsKeys.newWindowLocation.name) private var newWindowLocation = SettingsKeys.newWindowLocation.defaultValue
  @AppStorage(SettingsKeys.newWindowFolderPath.name) private var newWindowFolderPath = SettingsKeys.newWindowFolderPath.defaultValue
  @AppStorage(SettingsKeys.folderOpeningBehavior.name) private var folderOpeningBehavior = SettingsKeys.folderOpeningBehavior.defaultValue
  @AppStorage(SettingsKeys.restoresWindows.name) private var restoresWindows = SettingsKeys.restoresWindows.defaultValue
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    SettingsPaneForm(pane: .general) {
      Section {
        Picker("New windows show:", selection: $newWindowLocation) {
          Text("Home").tag(NewWindowLocation.home)
          Text("Desktop").tag(NewWindowLocation.desktop)
          Text("Documents").tag(NewWindowLocation.documents)
          Text("Last Location").tag(NewWindowLocation.lastLocation)
          Text("Other Folder").tag(NewWindowLocation.chosenFolder)
        }
        if newWindowLocation == .chosenFolder {
          SettingsFolderChooser(path: $newWindowFolderPath)
        }
        Picker("Open folders in:", selection: $folderOpeningBehavior) {
          Text("Same Tab").tag(FolderOpeningBehavior.sameTab)
          Text("New Tab").tag(FolderOpeningBehavior.newTab)
          Text("New Window").tag(FolderOpeningBehavior.newWindow)
        }
      }
      Section {
        Toggle("Restore windows when FileCraft opens", isOn: $restoresWindows)
      }
      Section {
        LabeledContent("Welcome window:") {
          Button("Show Welcome Window…") {
            openWindow(id: WelcomeView.windowID)
          }
        }
      }
    }
    .onChange(of: restoresWindows) {
      SettingsStore().applyWindowRestoration()
    }
  }
}

// MARK: - Browser

/// The Browser pane: how file views show items and how they react.
internal struct BrowserSettingsPane: View {

  @AppStorage(SettingsKeys.defaultViewMode.name) private var defaultViewMode = SettingsKeys.defaultViewMode.defaultValue
  @AppStorage(SettingsKeys.showsHiddenFiles.name) private var showsHiddenFiles = SettingsKeys.showsHiddenFiles.defaultValue
  @AppStorage(SettingsKeys.alwaysShowsFileExtensions.name)
  private var alwaysShowsFileExtensions = SettingsKeys.alwaysShowsFileExtensions.defaultValue
  @AppStorage(SettingsKeys.foldersFirst.name) private var foldersFirst = SettingsKeys.foldersFirst.defaultValue
  @AppStorage(SettingsKeys.usesRelativeDates.name) private var usesRelativeDates = SettingsKeys.usesRelativeDates.defaultValue
  @AppStorage(SettingsKeys.calculatesFolderSizes.name) private var calculatesFolderSizes = SettingsKeys.calculatesFolderSizes.defaultValue
  @AppStorage(SettingsKeys.showsIconPreviews.name) private var showsIconPreviews = SettingsKeys.showsIconPreviews.defaultValue
  @AppStorage(SettingsKeys.textSize.name) private var textSize = SettingsKeys.textSize.defaultValue
  @AppStorage(SettingsKeys.returnKeyAction.name) private var returnKeyAction = SettingsKeys.returnKeyAction.defaultValue
  @AppStorage(SettingsKeys.springLoadsFolders.name) private var springLoadsFolders = SettingsKeys.springLoadsFolders.defaultValue
  @AppStorage(SettingsKeys.springLoadingDelay.name) private var springLoadingDelay = SettingsKeys.springLoadingDelay.defaultValue
  @AppStorage(SettingsKeys.treatsPackagesAsFolders.name)
  private var treatsPackagesAsFolders = SettingsKeys.treatsPackagesAsFolders.defaultValue

  var body: some View {
    SettingsPaneForm(pane: .browser) {
      Section {
        Picker("Default view:", selection: $defaultViewMode) {
          Text("as Icons").tag(ViewMode.icons)
          Text("as List").tag(ViewMode.list)
          Text("as Columns").tag(ViewMode.columns)
        }
        Picker("Text size:", selection: $textSize) {
          ForEach(BrowserTextSize.allCases, id: \.self) { size in
            Text(size.title).tag(size)
          }
        }
        Toggle("Show hidden files", isOn: $showsHiddenFiles)
        Toggle("Always show file extensions", isOn: $alwaysShowsFileExtensions)
        Toggle("Keep folders on top", isOn: $foldersFirst)
        Toggle("Use relative dates", isOn: $usesRelativeDates)
        Toggle("Calculate folder sizes", isOn: $calculatesFolderSizes)
        Toggle("Show icon previews", isOn: $showsIconPreviews)
        Toggle("Treat packages as folders", isOn: $treatsPackagesAsFolders)
      }
      Section {
        Picker("Return key:", selection: $returnKeyAction) {
          Text("Renames the item").tag(ReturnKeyAction.rename)
          Text("Opens the item").tag(ReturnKeyAction.open)
        }
        Toggle("Spring-loaded folders", isOn: $springLoadsFolders)
        LabeledContent("Delay:") {
          HStack {
            Slider(value: $springLoadingDelay, in: 0.2...2.0, step: 0.1)
            Text(Duration.milliseconds(Int(springLoadingDelay * 1_000)), format: .units(allowed: [.seconds, .milliseconds], width: .abbreviated))
              .monospacedDigit()
              .frame(minWidth: 60, alignment: .trailing)
          }
        }
        .disabled(springLoadsFolders == false)
      }
    }
  }
}

// MARK: - Sidebar

/// The Sidebar pane: which sections the sidebar shows.
internal struct SidebarSettingsPane: View {

  @AppStorage(SettingsKeys.showsFavorites.name) private var showsFavorites = SettingsKeys.showsFavorites.defaultValue
  @AppStorage(SettingsKeys.showsLocations.name) private var showsLocations = SettingsKeys.showsLocations.defaultValue
  @AppStorage(SettingsKeys.showsICloud.name) private var showsICloud = SettingsKeys.showsICloud.defaultValue
  @AppStorage(SettingsKeys.showsTags.name) private var showsTags = SettingsKeys.showsTags.defaultValue
  @AppStorage(SettingsKeys.showsVolumeUsage.name) private var showsVolumeUsage = SettingsKeys.showsVolumeUsage.defaultValue

  var body: some View {
    SettingsPaneForm(pane: .sidebar) {
      Section("Show in the sidebar:") {
        Toggle("Favorites", isOn: $showsFavorites)
        Toggle("Locations", isOn: $showsLocations)
        Toggle("iCloud", isOn: $showsICloud)
        Toggle("Tags", isOn: $showsTags)
      }
      Section {
        Toggle("Show volume usage", isOn: $showsVolumeUsage)
      }
    }
  }
}

// MARK: - Tabs & Panes

/// The Tabs & Panes pane: new tabs, the tab bar, the dual-pane layout and function keys.
internal struct TabsAndPanesSettingsPane: View {

  @AppStorage(SettingsKeys.newTabLocation.name) private var newTabLocation = SettingsKeys.newTabLocation.defaultValue
  @AppStorage(SettingsKeys.hidesSingleTabBar.name) private var hidesSingleTabBar = SettingsKeys.hidesSingleTabBar.defaultValue
  @AppStorage(SettingsKeys.dualPaneLayout.name) private var dualPaneLayout = SettingsKeys.dualPaneLayout.defaultValue
  @AppStorage(SettingsKeys.usesFunctionKeys.name) private var usesFunctionKeys = SettingsKeys.usesFunctionKeys.defaultValue

  var body: some View {
    SettingsPaneForm(pane: .tabsAndPanes) {
      Section {
        Picker("New tabs show:", selection: $newTabLocation) {
          Text("Current Location").tag(NewTabLocation.currentLocation)
          Text("Home").tag(NewTabLocation.home)
        }
        Toggle("Hide the tab bar when there is only one tab", isOn: $hidesSingleTabBar)
      }
      Section {
        Picker("Dual pane layout:", selection: $dualPaneLayout) {
          Text("Side by Side").tag(PaneLayout.sideBySide)
          Text("Stacked").tag(PaneLayout.stacked)
        }
        Toggle(isOn: $usesFunctionKeys) {
          Text("Use function keys for file commands")
          Text("F5 copies and F6 moves to the other pane, F7 creates a folder, F8 moves to the Trash.")
        }
      }
    }
  }
}

#Preview("General") {
  GeneralSettingsPane()
    .frame(width: 600)
}

#Preview("Browser") {
  BrowserSettingsPane()
    .frame(width: 600)
}

#Preview("Sidebar") {
  SidebarSettingsPane()
    .frame(width: 600)
}

#Preview("Tabs & Panes") {
  TabsAndPanesSettingsPane()
    .frame(width: 600)
}

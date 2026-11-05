/*
 * ViewOptionsView.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-10-31.
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

/// The View Options panel (⌘J). It shows the options of the key browser window's active tab that matter for
/// the tab's view mode; the utility window receives the focused values of the main window.
internal struct ViewOptionsView: View {

  // MARK: - Properties

  /// The identifier of the panel's scene, used to open it.
  nonisolated internal static let windowID = "viewOptions"

  @FocusedValue(\.browserWindow) private var window

  // MARK: - Body

  internal var body: some View {
    Group {
      if let tab = window?.activeTab {
        ViewOptionsForm(tab: tab)
      } else {
        ContentUnavailableView("No Window", systemImage: "macwindow")
          .padding()
      }
    }
    .frame(width: 320)
  }
}

/// The view options of one tab. Changes apply to the tab immediately.
internal struct ViewOptionsForm: View {

  // MARK: - Properties

  @Bindable internal var tab: TabModel

  // MARK: - Body

  internal var body: some View {
    let mode = tab.viewSettings.viewMode
    Form {
      Section {
        Picker("Text Size", selection: $tab.viewSettings.textSize) {
          ForEach(BrowserTextSize.allCases, id: \.self) { size in
            Text(size.title).tag(size)
          }
        }
      }
      switch mode {
      case .icons:
        iconOptions
      case .list:
        listOptions
      case .columns:
        Section {
          Toggle("Show Preview Column", isOn: $tab.viewSettings.showsPreviewColumn)
        }
      }
      Section {
        if mode != .columns {
          Picker("Group By", selection: $tab.viewSettings.grouping) {
            ForEach(GroupingKey.allCases, id: \.self) { key in
              Text(key.title).tag(key)
            }
          }
        }
        Picker("Sort By", selection: $tab.viewSettings.sortOrder.key) {
          ForEach(SortKey.allCases, id: \.self) { key in
            Text(key.title).tag(key)
          }
        }
        Toggle("Folders First", isOn: $tab.viewSettings.sortOrder.foldersFirst)
      }
      Section {
        Button("Use as Defaults") {
          tab.saveViewOptionsAsDefaults()
        }
      } footer: {
        Text("New tabs use these options.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .fixedSize(horizontal: false, vertical: true)
  }

  // MARK: - Sections

  @ViewBuilder
  private var iconOptions: some View {
    let iconSize = Int(tab.viewSettings.iconSize)
    Section {
      LabeledContent {
        Slider(value: $tab.viewSettings.iconSize, in: ViewSettings.iconSizeRange, step: 8)
          .accessibilityLabel(Text("Icon Size"))
      } label: {
        Text("Icon Size")
        Text(verbatim: "\(iconSize) × \(iconSize)")
      }
      Picker("Label Position", selection: $tab.viewSettings.labelPosition) {
        ForEach(LabelPosition.allCases, id: \.self) { position in
          Text(position.title).tag(position)
        }
      }
      .pickerStyle(.segmented)
      Toggle("Show Item Info", isOn: $tab.viewSettings.showsItemInfo)
      Toggle("Show Icon Previews", isOn: $tab.viewSettings.showsIconPreviews)
    }
  }

  @ViewBuilder
  private var listOptions: some View {
    Section {
      Toggle("Use Relative Dates", isOn: $tab.viewSettings.usesRelativeDates)
      Toggle("Calculate Folder Sizes", isOn: $tab.viewSettings.calculatesFolderSizes)
    }
    Section("Show Columns") {
      ForEach(ListColumn.allCases) { column in
        Toggle(isOn: visibility(of: column)) {
          Text(column.title)
        }
      }
    }
  }

  // MARK: - Private

  private func visibility(of column: ListColumn) -> Binding<Bool> {
    Binding {
      column.isVisible(in: tab.columnCustomization)
    } set: { isVisible in
      tab.columnCustomization[visibility: column.customizationID] = isVisible ? .visible : .hidden
    }
  }
}

#Preview("Icons") {
  let tab = TabModel.preview(in: .english)
  tab.viewSettings.viewMode = .icons

  return ViewOptionsForm(tab: tab)
    .frame(width: 320)
}

#Preview("List, German") {
  ViewOptionsForm(tab: .preview(in: .german))
    .frame(width: 320)
    .environment(\.locale, Locale(identifier: "de"))
}

#Preview("No Window") {
  ViewOptionsView()
}

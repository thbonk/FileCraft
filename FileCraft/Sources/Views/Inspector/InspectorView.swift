/*
 * InspectorView.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-03.
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
import UniformTypeIdentifiers

/// The inspector of a browser window (⌥⌘I). It shows the active pane's selection, or the current folder when
/// nothing is selected, and follows the selection.
internal struct InspectorView: View {

  // MARK: - Properties

  internal let window: BrowserWindowModel

  // MARK: - Body

  internal var body: some View {
    let tab = window.activeTab
    let selected = tab.selectedItems.map(\.url)
    let urls = selected.isEmpty ? (tab.folderURL.map { [$0] } ?? []) : selected
    InspectorContent(urls: urls) { url in
      tab.reveal(url)
    } didRename: { newURL in
      tab.select(newURL.path(percentEncoded: false))
    }
  }
}

/// The sections for `urls`, shared by the inspector and Get Info windows.
internal struct InspectorContent: View {

  // MARK: - Properties

  internal let urls: [URL]
  /// Shows an item in a browser window, as clicking its location does.
  internal let reveal: (URL) -> Void
  /// Receives the new location after the name was changed.
  internal var didRename: ((URL) -> Void)?
  /// The tags offered as suggestions in the Tags section.
  internal var knownTags: [String] = SidebarSources.shared.tags

  @AppStorage(SettingsKeys.textSize.name) private var textSize = SettingsKeys.textSize.defaultValue
  @State private var model = InspectorModel()

  // MARK: - Body

  internal var body: some View {
    Group {
      if urls.isEmpty {
        ContentUnavailableView("No Selection", systemImage: "info.circle")
      } else if let loadFailure = model.loadFailure {
        ContentUnavailableView {
          Label("Cannot Show Info", systemImage: "exclamationmark.triangle")
        } description: {
          Text(verbatim: loadFailure)
        }
      } else if urls.count == 1, let details = model.details {
        ScrollView {
          VStack(alignment: .leading, spacing: 4) {
            editFailure
            InspectorSection("Preview", id: "preview") {
              QuickLookPreview(url: details.item.url)
                .frame(height: 200)
                .clipShape(.rect(cornerRadius: 6))
            }
            GeneralSection(details: details, model: model, reveal: reveal)
            TagsSection(model: model, knownTags: knownTags)
            PermissionsSection(details: details, model: model)
            if Self.hasOpenWith(details.item) {
              OpenWithSection(details: details, model: model)
            }
            AttributesSection(model: model)
            ExtendedAttributesSection(attributes: details.extendedAttributes)
          }
          .padding(12)
        }
      } else if urls.count > 1 {
        ScrollView {
          VStack(alignment: .leading, spacing: 4) {
            editFailure
            SummarySection(model: model)
            TagsSection(model: model, knownTags: knownTags)
            AttributesSection(model: model)
          }
          .padding(12)
        }
      } else {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .font(textSize.font)
    .task(id: urls) {
      model.didRename = didRename
      await model.show(urls)
    }
  }

  /// An edit that failed for another reason than an invalid name.
  @ViewBuilder
  private var editFailure: some View {
    if case .failed(let description) = model.editError {
      Label {
        Text(verbatim: description)
          .fixedSize(horizontal: false, vertical: true)
      } icon: {
        Image(systemName: "exclamationmark.triangle.fill")
      }
      .font(.callout)
      .foregroundStyle(.red)
      .padding(.bottom, 6)
    } else if case .needsAuthorization(let description) = model.editError {
      VStack(alignment: .leading, spacing: 6) {
        Label {
          Text(verbatim: description)
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
          Image(systemName: "lock.fill")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        Button("Authenticate and Retry") {
          model.retryWithAuthorization()
        }
      }
      .padding(.bottom, 6)
    }
  }

  /// Open With applies to documents and document packages, not to folders and applications.
  private static func hasOpenWith(_ item: FileItem) -> Bool {
    let isFolder = item.isDirectory && item.isPackage == false
    let isApplication = item.contentType?.conforms(to: .application) == true
    return isFolder == false && isApplication == false
  }
}

/// A collapsible inspector section whose expanded state is kept for all inspectors and info windows.
internal struct InspectorSection<Content: View>: View {

  // MARK: - Properties

  private let title: LocalizedStringKey
  private let content: Content

  @AppStorage private var isExpanded: Bool

  // MARK: - Initialization

  /// - Parameter id: A stable identifier for storing the expanded state.
  internal init(_ title: LocalizedStringKey, id: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
    _isExpanded = AppStorage(wrappedValue: true, "inspector.\(id).isExpanded")
  }

  // MARK: - Body

  internal var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      content
        .padding(.top, 4)
        .padding(.bottom, 8)
    } label: {
      Text(title)
        .font(.headline)
    }
  }
}

/// The summary of several selected items: their number, total size and kinds.
internal struct SummarySection: View {

  // MARK: - Properties

  internal let model: InspectorModel

  @AppStorage(SettingsKeys.sizeUnits.name) private var sizeUnits = SettingsKeys.sizeUnits.defaultValue
  @Environment(\.locale) private var locale

  // MARK: - Body

  internal var body: some View {
    let formatter = ByteSizeFormatter(units: sizeUnits, locale: locale)
    InspectorSection("General", id: "summary") {
      Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 4) {
        InspectorRow("Selected") {
          Text("\(model.urls.count) items")
        }
        InspectorRow("Size") {
          if let totalSize = model.totalSize {
            Text(formatter.string(for: totalSize.logicalBytes))
          } else if model.isCalculatingSize {
            ProgressView()
              .controlSize(.small)
          }
        }
        ForEach(kindCounts, id: \.kind) { entry in
          InspectorRow(verbatim: entry.kind) {
            Text("\(entry.count) items")
          }
        }
      }
    }
  }

  /// The number of selected items of each kind, most frequent first.
  private var kindCounts: [(kind: String, count: Int)] {
    Dictionary(grouping: model.items, by: \.kind)
      .map { (kind: $0.key, count: $0.value.count) }
      .sorted { $0.count > $1.count || ($0.count == $1.count && $0.kind < $1.kind) }
  }
}

/// One label and value row of an inspector grid.
internal struct InspectorRow<Value: View>: View {

  private let label: Text
  private let value: Value

  internal init(_ label: LocalizedStringKey, @ViewBuilder value: () -> Value) {
    self.label = Text(label)
    self.value = value()
  }

  /// A row whose label is already localized, such as a kind name from the system.
  internal init(verbatim label: String, @ViewBuilder value: () -> Value) {
    self.label = Text(verbatim: label)
    self.value = value()
  }

  internal var body: some View {
    GridRow {
      label
        .foregroundStyle(.secondary)
        .gridColumnAlignment(.trailing)
      value
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

#Preview("Folder, English") {
  InspectorContent(urls: [PreviewFixtures.homeFolder]) { _ in }
    .frame(width: 280, height: 520)
}

#Preview("Nothing selected, German") {
  InspectorContent(urls: []) { _ in }
    .frame(width: 280, height: 300)
    .environment(\.locale, Locale(identifier: "de"))
}

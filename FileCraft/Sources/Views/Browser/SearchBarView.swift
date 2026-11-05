/*
 * SearchBarView.swift
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

/// The bar above a pane's search results: scope, options, the running count with Stop, and the criteria rows.
internal struct SearchBarView: View {

  // MARK: - Properties

  @Bindable internal var tab: TabModel

  private var isShowingResults: Bool {
    tab.location.searchQuery != nil
  }

  // MARK: - Body

  internal var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Picker("Search In", selection: scope) {
          ForEach(SearchScope.allCases, id: \.self) { scope in
            Text(scope.title)
              .tag(scope)
              .disabled(scope == .subfolders && tab.canSearchSubfolders == false)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        Button("Add Criterion", systemImage: "plus") {
          tab.searchParameters.criteria.append(SearchCriterion(attribute: .name))
        }
        .labelStyle(.iconOnly)
        .help(Text("Add Criterion"))
        .disabled(tab.searchParameters.scope == .thisFolder)
        Menu("Options") {
          Toggle("Include Hidden Items", isOn: $tab.searchParameters.includesHiddenItems)
          Toggle("Include Package Contents", isOn: $tab.searchParameters.includesPackageContents)
        }
        .fixedSize()
        .disabled(tab.searchParameters.scope == .thisFolder)
        Spacer(minLength: 8)
        status
      }
      ForEach($tab.searchParameters.criteria) { $criterion in
        SearchCriterionRow(criterion: $criterion, scope: tab.searchParameters.scope) {
          tab.searchParameters.criteria.removeAll { $0.id == criterion.id }
        }
      }
    }
    .font(.callout)
    .controlSize(.small)
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .onChange(of: tab.searchParameters.criteria) {
      tab.searchParametersDidChange()
    }
    .onChange(of: tab.searchParameters.includesHiddenItems) {
      tab.searchParametersDidChange()
    }
    .onChange(of: tab.searchParameters.includesPackageContents) {
      tab.searchParametersDidChange()
    }
  }

  @ViewBuilder
  private var status: some View {
    let count = tab.listing.items.count
    if tab.listing.isSearching {
      ProgressView()
        .controlSize(.mini)
        .accessibilityHidden(true)
      Text("Searching… \(count) found")
        .monospacedDigit()
        .foregroundStyle(.secondary)
      Button("Stop") {
        tab.stopSearch()
      }
    } else if isShowingResults {
      Text("\(count) found")
        .monospacedDigit()
        .foregroundStyle(.secondary)
    }
  }

  private var scope: Binding<SearchScope> {
    Binding {
      tab.searchParameters.scope
    } set: { scope in
      tab.setSearchScope(scope)
    }
  }
}

/// One criterion: attribute, operator and value, and a button that removes the row.
private struct SearchCriterionRow: View {

  @Binding var criterion: SearchCriterion
  let scope: SearchScope
  let remove: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      Picker("Attribute", selection: $criterion.attribute) {
        ForEach(SearchCriterion.Attribute.allCases, id: \.self) { attribute in
          Text(attribute.title)
            .tag(attribute)
            .disabled(attribute == .contents && scope != .thisMac)
        }
      }
      .labelsHidden()
      .fixedSize()
      value
      if criterion.attribute == .contents, scope != .thisMac {
        Text("Only for This Mac")
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
      Button("Remove Criterion", systemImage: "minus", action: remove)
        .labelStyle(.iconOnly)
        .help(Text("Remove Criterion"))
    }
  }

  @ViewBuilder
  private var value: some View {
    switch criterion.attribute {
    case .name:
      Picker("Operator", selection: $criterion.nameOperator) {
        ForEach(SearchCriterion.NameOperator.allCases, id: \.self) { nameOperator in
          Text(nameOperator.title).tag(nameOperator)
        }
      }
      .labelsHidden()
      .fixedSize()
      textField("Name")
    case .kind:
      Picker("Kind", selection: $criterion.kind) {
        ForEach(SearchCriterion.ItemKind.allCases, id: \.self) { kind in
          Text(kind.title).tag(kind)
        }
      }
      .labelsHidden()
      .fixedSize()
    case .pathExtension:
      textField("Extension")
    case .dateModified, .dateCreated:
      dateValue
    case .size:
      Picker("Comparison", selection: $criterion.sizeComparison) {
        Text("is greater than").tag(SearchCriterion.SizeComparison.greaterThan)
        Text("is less than").tag(SearchCriterion.SizeComparison.lessThan)
      }
      .labelsHidden()
      .fixedSize()
      TextField("Size", value: $criterion.sizeValue, format: .number)
        .labelsHidden()
        .frame(width: 70)
      Picker("Unit", selection: $criterion.sizeUnit) {
        Text(verbatim: "KB").tag(SearchCriterion.SizeUnit.kilobytes)
        Text(verbatim: "MB").tag(SearchCriterion.SizeUnit.megabytes)
        Text(verbatim: "GB").tag(SearchCriterion.SizeUnit.gigabytes)
      }
      .labelsHidden()
      .fixedSize()
    case .tags:
      textField("Tag")
    case .contents:
      textField("Text")
    }
  }

  @ViewBuilder
  private var dateValue: some View {
    Picker("Condition", selection: $criterion.dateCondition) {
      Text("is today").tag(SearchCriterion.DateCondition.today)
      Text("is within the last").tag(SearchCriterion.DateCondition.withinLast)
      Text("is before").tag(SearchCriterion.DateCondition.before)
      Text("is after").tag(SearchCriterion.DateCondition.after)
    }
    .labelsHidden()
    .fixedSize()
    switch criterion.dateCondition {
    case .today:
      EmptyView()
    case .withinLast:
      TextField("Amount", value: $criterion.dateAmount, format: .number)
        .labelsHidden()
        .frame(width: 50)
      Picker("Unit", selection: $criterion.dateUnit) {
        Text("days").tag(SearchCriterion.DateUnit.days)
        Text("weeks").tag(SearchCriterion.DateUnit.weeks)
        Text("months").tag(SearchCriterion.DateUnit.months)
      }
      .labelsHidden()
      .fixedSize()
    case .before, .after:
      DatePicker("Date", selection: $criterion.date, displayedComponents: .date)
        .labelsHidden()
        .fixedSize()
    }
  }

  private func textField(_ title: LocalizedStringKey) -> some View {
    TextField(title, text: $criterion.text)
      .labelsHidden()
      .frame(minWidth: 100, maxWidth: 240)
  }
}

// MARK: - Titles

extension SearchScope {

  /// The localized name shown in the search field's menu and the search bar.
  internal var title: LocalizedStringResource {
    switch self {
    case .thisFolder:
      "This Folder"
    case .subfolders:
      "Subfolders"
    case .thisMac:
      "This Mac"
    }
  }
}

extension SearchCriterion.Attribute {

  internal var title: LocalizedStringResource {
    switch self {
    case .name:
      "Name"
    case .kind:
      "Kind"
    case .pathExtension:
      "Extension"
    case .dateModified:
      "Date Modified"
    case .dateCreated:
      "Date Created"
    case .size:
      "Size"
    case .tags:
      "Tags"
    case .contents:
      "Contents"
    }
  }
}

extension SearchCriterion.NameOperator {

  internal var title: LocalizedStringResource {
    switch self {
    case .contains:
      "contains"
    case .beginsWith:
      "begins with"
    case .endsWith:
      "ends with"
    case .isEqual:
      "is"
    case .matchesRegularExpression:
      "matches regular expression"
    }
  }
}

extension SearchCriterion.ItemKind {

  internal var title: LocalizedStringResource {
    switch self {
    case .folder:
      "Folder"
    case .application:
      "Application"
    case .document:
      "Document"
    case .image:
      "Image"
    case .movie:
      "Movie"
    case .audio:
      "Audio"
    case .pdf:
      "PDF"
    case .text:
      "Text"
    case .archive:
      "Archive"
    }
  }
}

#Preview {
  let tab = BrowserWindowModel.preview(in: .english).activeTab
  tab.searchParameters = SearchParameters(
    scope: .subfolders,
    text: "report",
    criteria: [
      SearchCriterion(attribute: .kind, kind: .image),
      SearchCriterion(attribute: .size, sizeComparison: .greaterThan, sizeValue: 5),
      SearchCriterion(attribute: .dateModified),
    ])
  return SearchBarView(tab: tab)
    .frame(width: 640)
}

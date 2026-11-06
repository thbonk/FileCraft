/*
 * BatchRenameSheet.swift
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

/// Tools > Batch Rename…: the rule list, a live preview of the new names with their problems, the item order and
/// the presets.
internal struct BatchRenameSheet: View {

  // MARK: - Properties

  @Bindable internal var model: BatchRenameModel
  internal let commands: FileCommandModel?
  internal var presets: RenamePresetsStore = .shared

  @Environment(\.dismiss) private var dismiss
  @State private var isNamingPreset = false
  @State private var presetName = ""
  @State private var isRenaming = false

  // MARK: - Body

  internal var body: some View {
    let rows = model.rows
    let errorCount = rows.count { $0.status.isError }
    let moves = model.moves(in: rows)
    VStack(alignment: .leading, spacing: 12) {
      Text("Batch Rename \(model.items.count) Items")
        .font(.headline)
      HSplitView {
        ruleList
          .frame(minWidth: 340, idealWidth: 360, maxWidth: 480)
        BatchRenamePreview(rows: rows)
          .frame(minWidth: 480)
      }
      footer(errorCount: errorCount, moves: moves)
    }
    .padding(20)
    // A sheet takes its minimum size, so the size is fixed: wide enough for the rules and a preview without scrolling.
    .frame(width: 940, height: 580)
    .task {
      await model.loadFolderNames()
      await presets.loadIfNeeded()
    }
    .alert("Save Preset", isPresented: $isNamingPreset) {
      TextField("Preset Name", text: $presetName)
      Button("Save") {
        presets.save(model.rules, as: presetName)
      }
      .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("A preset with the same name is replaced.")
    }
  }

  // MARK: - Rules

  private var ruleList: some View {
    VStack(alignment: .leading, spacing: 8) {
      if model.rules.isEmpty {
        ContentUnavailableView("No Rules", systemImage: "list.bullet", description: Text("Add a rule to change the names."))
          .frame(maxHeight: .infinity)
      } else {
        let invalidRuleIDs = model.invalidRuleIDs
        List {
          ForEach($model.rules) { $rule in
            RenameRuleEditor(rule: $rule, isInvalid: invalidRuleIDs.contains(rule.id)) {
              model.removeRule(rule.id)
            }
          }
          .onMove { source, destination in
            model.moveRules(from: source, to: destination)
          }
        }
        .listStyle(.bordered)
      }
      HStack {
        Menu("Add Rule", systemImage: "plus") {
          ForEach(RenameRule.Kind.allCases, id: \.self) { kind in
            Button(kind.title) {
              model.addRule(kind)
            }
          }
        }
        .fixedSize()
        Spacer()
        presetsMenu
      }
    }
  }

  private var presetsMenu: some View {
    Menu("Presets") {
      if presets.presets.isEmpty {
        Text("No Presets")
      } else {
        Section("Apply Preset") {
          ForEach(presets.presets) { preset in
            Button(preset.name) {
              model.apply(preset)
            }
          }
        }
      }
      Divider()
      Button("Save as Preset…") {
        presetName = ""
        isNamingPreset = true
      }
      .disabled(model.rules.isEmpty)
      Menu("Delete Preset") {
        ForEach(presets.presets) { preset in
          Button(preset.name, role: .destructive) {
            presets.delete(preset)
          }
        }
      }
      .disabled(presets.presets.isEmpty)
    }
    .fixedSize()
  }

  // MARK: - Footer

  private func footer(errorCount: Int, moves: [ItemMove]?) -> some View {
    HStack(spacing: 12) {
      Picker("Order:", selection: $model.order) {
        Text("As Shown").tag(BatchRenameModel.Order.asShown)
        Text("Name").tag(BatchRenameModel.Order.name)
        Text("Date Modified").tag(BatchRenameModel.Order.dateModified)
        Text("Date Created").tag(BatchRenameModel.Order.dateCreated)
      }
      .fixedSize()
      .help(Text("The order in which sequence numbers count the items."))
      Spacer()
      if errorCount > 0 {
        Label("\(errorCount) errors", systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.red)
      }
      Button("Cancel", role: .cancel) {
        dismiss()
      }
      .keyboardShortcut(.cancelAction)
      Button("Rename") {
        guard let moves, let commands else {
          return
        }
        isRenaming = true
        Task {
          await commands.batchRename(moves)
          dismiss()
        }
      }
      .keyboardShortcut(.defaultAction)
      .disabled(moves == nil || model.isLoaded == false || isRenaming)
    }
  }
}

// MARK: - Preview Table

/// The current and new names with the status of each row.
private struct BatchRenamePreview: View {

  let rows: [BatchRenameModel.Row]

  var body: some View {
    Table(rows) {
      TableColumn("Current Name") { row in
        Text(verbatim: row.item.name)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .width(min: 100, ideal: 140)
      TableColumn("New Name") { row in
        Text(verbatim: row.newName)
          .lineLimit(1)
          .truncationMode(.middle)
          .foregroundStyle(row.status == .unchanged ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
      }
      .width(min: 100, ideal: 140)
      TableColumn("Status") { row in
        status(row.status)
      }
      .width(min: 90, ideal: 110)
    }
  }

  @ViewBuilder
  private func status(_ status: BatchRenameStatus) -> some View {
    switch status {
    case .unchanged:
      Text("Unchanged")
        .foregroundStyle(.secondary)
    case .renamed:
      Label("OK", systemImage: "checkmark")
        .labelStyle(.iconOnly)
        .foregroundStyle(.green)
    case .invalid(let issue):
      Label(issue.title, systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.red)
    }
  }
}

// MARK: - Rule Editor

/// One rule: on/off, type, target, its settings and a button that removes it.
private struct RenameRuleEditor: View {

  @Binding var rule: RenameRule
  let isInvalid: Bool
  let remove: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Toggle("Enabled", isOn: $rule.isEnabled)
          .labelsHidden()
          .toggleStyle(.checkbox)
          .help(Text("Turns the rule on or off."))
        Picker("Rule", selection: $rule.kind) {
          ForEach(RenameRule.Kind.allCases, id: \.self) { kind in
            Text(kind.title).tag(kind)
          }
        }
        .labelsHidden()
        .fixedSize()
        if rule.kind != .changeExtension {
          Picker("Applies To", selection: $rule.target) {
            Text("Name").tag(RenameRule.Target.nameWithoutExtension)
            Text("Extension").tag(RenameRule.Target.extensionOnly)
            Text("Full Name").tag(RenameRule.Target.fullName)
          }
          .labelsHidden()
          .fixedSize()
          .help(Text("The part of the name the rule changes."))
        }
        Spacer(minLength: 0)
        Button("Remove Rule", systemImage: "minus.circle", action: remove)
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
          .help(Text("Remove Rule"))
      }
      settings
        .disabled(rule.isEnabled == false)
      if isInvalid {
        Text("The regular expression is not valid.")
          .font(.callout)
          .foregroundStyle(.red)
      }
    }
    .controlSize(.small)
    .padding(.vertical, 4)
  }

  @ViewBuilder
  private var settings: some View {
    switch rule.kind {
    case .replaceText, .regularExpression:
      findAndReplace
    case .insertText:
      HStack {
        TextField("Text", text: $rule.insertText)
        positionPicker(selection: $rule.insertPosition, cases: RenameRule.InsertPosition.allCases) { $0.title }
        if rule.insertPosition == .atPosition {
          numberField("Position", value: $rule.position)
        }
      }
    case .removeCharacters:
      HStack {
        numberField("Count", value: $rule.removalCount)
        positionPicker(selection: $rule.removalPosition, cases: RenameRule.RemovalPosition.allCases) { $0.title }
        if rule.removalPosition == .atPosition {
          numberField("Position", value: $rule.position)
        }
      }
    case .changeCase:
      positionPicker(selection: $rule.caseStyle, cases: RenameRule.CaseStyle.allCases) { $0.title }
    case .sequenceNumber:
      HStack {
        numberField("Start", value: $rule.sequenceStart)
        numberField("Step", value: $rule.sequenceStep)
        numberField("Digits", value: $rule.sequenceDigits)
      }
      endPlacement
    case .date:
      HStack {
        Picker("Date", selection: $rule.dateSource) {
          Text("Date Created").tag(RenameRule.DateSource.created)
          Text("Date Modified").tag(RenameRule.DateSource.modified)
          Text("Current Date").tag(RenameRule.DateSource.current)
        }
        .labelsHidden()
        .fixedSize()
        TextField("Format", text: $rule.dateFormat)
          .help(Text("A Unicode date pattern, for example yyyy-MM-dd."))
        Menu("Formats") {
          ForEach(RenameRule.dateFormatPresets, id: \.self) { format in
            Button(format) {
              rule.dateFormat = format
            }
          }
        }
        .fixedSize()
      }
      endPlacement
    case .changeExtension:
      HStack {
        positionPicker(selection: $rule.extensionChange, cases: RenameRule.ExtensionChange.allCases) { $0.title }
        if rule.extensionChange == .replace {
          TextField("New Extension", text: $rule.newExtension)
        }
      }
    }
  }

  private var findAndReplace: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        TextField(rule.kind == .regularExpression ? "Pattern" : "Find", text: $rule.findText)
        TextField(rule.kind == .regularExpression ? "Replacement, for example $1" : "Replace With", text: $rule.replacementText)
      }
      HStack {
        positionPicker(selection: $rule.occurrence, cases: RenameRule.Occurrence.allCases) { $0.title }
        Toggle("Match case", isOn: $rule.isCaseSensitive)
      }
    }
  }

  private var endPlacement: some View {
    HStack {
      positionPicker(selection: $rule.endPosition, cases: RenameRule.EndPosition.allCases) { $0.title }
      TextField("Separator", text: $rule.separator)
        .frame(width: 80)
    }
  }

  private func positionPicker<Value: Hashable>(
    selection: Binding<Value>,
    cases: [Value],
    title: @escaping (Value) -> LocalizedStringResource
  ) -> some View {
    Picker("Option", selection: selection) {
      ForEach(cases, id: \.self) { value in
        Text(title(value)).tag(value)
      }
    }
    .labelsHidden()
    .fixedSize()
  }

  private func numberField(_ title: LocalizedStringKey, value: Binding<Int>) -> some View {
    LabeledContent(title) {
      TextField(title, value: value, format: .number)
        .labelsHidden()
        .frame(width: 50)
    }
  }
}

// MARK: - Titles

extension RenameRule.Kind {

  internal var title: LocalizedStringResource {
    switch self {
    case .replaceText:
      "Replace Text"
    case .regularExpression:
      "Regular Expression"
    case .insertText:
      "Insert Text"
    case .removeCharacters:
      "Remove Characters"
    case .changeCase:
      "Change Case"
    case .sequenceNumber:
      "Sequence Number"
    case .date:
      "Date"
    case .changeExtension:
      "Change Extension"
    }
  }
}

extension RenameRule.Occurrence {

  internal var title: LocalizedStringResource {
    switch self {
    case .first:
      "First Occurrence"
    case .last:
      "Last Occurrence"
    case .all:
      "All Occurrences"
    }
  }
}

extension RenameRule.InsertPosition {

  internal var title: LocalizedStringResource {
    switch self {
    case .prefix:
      "As Prefix"
    case .suffix:
      "As Suffix"
    case .atPosition:
      "At Position"
    }
  }
}

extension RenameRule.RemovalPosition {

  internal var title: LocalizedStringResource {
    switch self {
    case .fromStart:
      "From Start"
    case .fromEnd:
      "From End"
    case .atPosition:
      "At Position"
    }
  }
}

extension RenameRule.CaseStyle {

  internal var title: LocalizedStringResource {
    switch self {
    case .lowercase:
      "lowercase"
    case .uppercase:
      "UPPERCASE"
    case .titleCase:
      "Title Case"
    case .sentenceCase:
      "Sentence case"
    }
  }
}

extension RenameRule.EndPosition {

  internal var title: LocalizedStringResource {
    switch self {
    case .prefix:
      "As Prefix"
    case .suffix:
      "As Suffix"
    }
  }
}

extension RenameRule.ExtensionChange {

  internal var title: LocalizedStringResource {
    switch self {
    case .replace:
      "Replace With"
    case .remove:
      "Remove"
    case .lowercase:
      "Make Lowercase"
    }
  }
}

extension BatchRenameStatus.Issue {

  internal var title: LocalizedStringResource {
    switch self {
    case .empty:
      "Empty name"
    case .invalidCharacter:
      "Invalid character"
    case .tooLong:
      "Name too long"
    case .duplicate:
      "Duplicate name"
    case .alreadyExists:
      "Name already exists"
    }
  }
}

#Preview {
  let items = PreviewFixtures.items(in: .english).filter { $0.isDirectory == false }
  let model = BatchRenameModel(items: items, folderNames: BatchRenameModel.FolderNames())
  var prefix = RenameRule(kind: .insertText)
  prefix.insertText = "Trip_"
  prefix.insertPosition = .prefix
  model.rules = [prefix, RenameRule(kind: .sequenceNumber)]
  return BatchRenameSheet(model: model, commands: nil, presets: RenamePresetsStore(storage: JSONFileStorage(fileName: "PreviewPresets.json")))
}

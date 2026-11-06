/*
 * SelectByPatternSheet.swift
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

/// Edit > Select by Pattern…: selects the items of the active tab whose names match a wildcard pattern or a regular
/// expression, replacing the selection or adding to it.
internal struct SelectByPatternSheet: View {

  // MARK: - Properties

  internal let tab: TabModel

  @Environment(\.dismiss) private var dismiss
  @State private var text = ""
  @State private var syntax: NamePattern.Syntax = .wildcard
  @State private var isCaseSensitive = false

  private var pattern: Result<NamePattern, NamePattern.PatternError> {
    Result { () throws(NamePattern.PatternError) in
      try NamePattern(text, syntax: syntax, isCaseSensitive: isCaseSensitive)
    }
  }

  // MARK: - Body

  internal var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Select by Pattern")
        .font(.headline)
      Form {
        TextField("Pattern:", text: $text, prompt: Text(verbatim: syntax == .wildcard ? "*.jpg" : "^IMG_\\d+"))
        // Segments while they fit, a pop-up menu for long translations.
        ViewThatFits(in: .horizontal) {
          syntaxPicker
            .pickerStyle(.segmented)
            .fixedSize()
          syntaxPicker
            .pickerStyle(.menu)
        }
        Toggle("Match case", isOn: $isCaseSensitive)
      }
      result
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
      // The buttons stand side by side when they fit and are stacked when long translations need more room.
      ViewThatFits(in: .horizontal) {
        HStack {
          Spacer()
          buttons
        }
        VStack(alignment: .trailing) {
          buttons
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .padding(20)
    .frame(width: 480)
  }

  private var syntaxPicker: some View {
    Picker("Syntax:", selection: $syntax) {
      Text("Wildcards").tag(NamePattern.Syntax.wildcard)
      Text("Regular Expression").tag(NamePattern.Syntax.regularExpression)
    }
  }

  @ViewBuilder
  private var buttons: some View {
    Button("Cancel", role: .cancel) {
      dismiss()
    }
    .keyboardShortcut(.cancelAction)
    Button("Add to Selection") {
      apply(addingToSelection: true)
    }
    .disabled(isValid == false)
    Button("Replace Selection") {
      apply(addingToSelection: false)
    }
    .keyboardShortcut(.defaultAction)
    .disabled(isValid == false)
  }

  @ViewBuilder
  private var result: some View {
    switch pattern {
    case .success(let pattern):
      Text("\(tab.countMatches(of: pattern)) items match")
        .foregroundStyle(.secondary)
    case .failure(.invalid):
      Label("The regular expression is not valid.", systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.red)
    case .failure(.empty):
      Text("Wildcards: * matches any text, ? one character, [abc] one of the characters.")
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - Private

  private var isValid: Bool {
    if case .success = pattern {
      return true
    }
    return false
  }

  private func apply(addingToSelection: Bool) {
    guard case .success(let pattern) = pattern else {
      return
    }
    tab.select(matching: pattern, addingToSelection: addingToSelection)
    dismiss()
  }
}

#Preview {
  SelectByPatternSheet(tab: BrowserWindowModel.preview(in: .english).activeTab)
}

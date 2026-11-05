/*
 * PathField.swift
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

/// A text field for paths that suggests completions while typing, shared by Go to Folder and the path bar.
///
/// ↑ and ↓ highlight a suggestion, Tab accepts the highlighted suggestion or the first one, and clicking
/// accepts a suggestion. Return submits the highlighted suggestion when there is one, otherwise the text.
internal struct PathField: View {

  // MARK: - Types

  internal enum SuggestionPlacement {
    /// The suggestions take space below the field, as in a sheet.
    case below
    /// The suggestions float over the views below the field, as in the path bar.
    case overlay
  }

  // MARK: - Properties

  @Binding internal var text: String
  /// The folder that relative paths start from.
  internal let base: URL?
  internal let isFocused: FocusState<Bool>.Binding
  internal var placement: SuggestionPlacement = .below
  /// The suggestions while the field is empty, such as recent entries.
  internal var emptySuggestions: [String] = []
  internal let onSubmit: () -> Void

  @State private var completions: [String] = []
  @State private var highlightedIndex: Int?

  private static let rowHeight: CGFloat = 22
  private static let visibleRows = 8

  private var suggestions: [String] {
    text.isEmpty ? emptySuggestions : completions
  }

  // MARK: - Body

  internal var body: some View {
    switch placement {
    case .below:
      VStack(alignment: .leading, spacing: 6) {
        field
        if suggestions.isEmpty == false {
          suggestionList
            .background(.background.secondary, in: .rect(cornerRadius: 6))
        }
      }
    case .overlay:
      field
        .overlay(alignment: .bottomLeading) {
          if suggestions.isEmpty == false, isFocused.wrappedValue {
            suggestionList
              .frame(maxWidth: 520)
              .background(.regularMaterial, in: .rect(cornerRadius: 6))
              .shadow(radius: 6, y: 2)
              .alignmentGuide(.bottom) { dimensions in dimensions[.top] - 3 }
          }
        }
    }
  }

  // MARK: - Field

  private var field: some View {
    TextField("Path", text: $text)
      .textFieldStyle(.roundedBorder)
      .focused(isFocused)
      .autocorrectionDisabled()
      .onSubmit(submit)
      .onKeyPress(keys: [.tab, .downArrow, .upArrow], phases: [.down, .repeat]) { press in
        handle(press)
      }
      .task(id: text) {
        highlightedIndex = nil
        // Wait for a pause in typing, so that a folder is not read for every keystroke.
        try? await Task.sleep(for: .milliseconds(60))
        guard Task.isCancelled == false else {
          return
        }
        let results = await PathCompletion.completions(for: text, relativeTo: base)
        guard Task.isCancelled == false else {
          return
        }
        completions = results
      }
  }

  private func handle(_ press: KeyPress) -> KeyPress.Result {
    let suggestions = suggestions
    switch press.key {
    case .tab where press.modifiers.isEmpty:
      guard let suggestion = highlightedIndex.map({ suggestions[$0] }) ?? suggestions.first else {
        return .ignored
      }
      text = suggestion
      return .handled
    case .downArrow where suggestions.isEmpty == false:
      highlightedIndex = min((highlightedIndex ?? -1) + 1, suggestions.count - 1)
      return .handled
    case .upArrow where highlightedIndex != nil:
      highlightedIndex = highlightedIndex.flatMap { $0 > 0 ? $0 - 1 : nil }
      return .handled
    default:
      return .ignored
    }
  }

  private func submit() {
    if let highlightedIndex, suggestions.indices.contains(highlightedIndex) {
      text = suggestions[highlightedIndex]
    }
    onSubmit()
  }

  // MARK: - Suggestions

  private var suggestionList: some View {
    let suggestions = suggestions
    let highlighted = highlightedIndex.flatMap { suggestions.indices.contains($0) ? suggestions[$0] : nil }
    return ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(suggestions, id: \.self) { suggestion in
            SuggestionRow(suggestion: suggestion, isHighlighted: suggestion == highlighted) {
              text = suggestion
              isFocused.wrappedValue = true
            }
            .frame(height: Self.rowHeight)
            .id(suggestion)
          }
        }
        .padding(4)
      }
      .frame(height: min(CGFloat(suggestions.count), CGFloat(Self.visibleRows)) * Self.rowHeight + 8)
      .onChange(of: highlighted) {
        if let highlighted {
          proxy.scrollTo(highlighted)
        }
      }
    }
  }
}

/// One suggestion: its last path component with a folder or document symbol.
private struct SuggestionRow: View {

  let suggestion: String
  let isHighlighted: Bool
  let accept: () -> Void

  private var isFolder: Bool {
    suggestion.hasSuffix("/")
  }

  private var name: String {
    let trimmed = isFolder ? String(suggestion.dropLast()) : suggestion
    return trimmed.split(separator: "/").last.map(String.init) ?? suggestion
  }

  var body: some View {
    Button(action: accept) {
      Label(name, systemImage: isFolder ? "folder" : "doc")
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .foregroundStyle(isHighlighted ? Color.white : Color.primary)
        .background {
          RoundedRectangle(cornerRadius: 4)
            .fill(isHighlighted ? Color.accentColor : Color.clear)
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(Text(verbatim: suggestion))
    .accessibilityAddTraits(isHighlighted ? .isSelected : [])
  }
}

#Preview("Below") {
  @Previewable @State var text = "~/Doc"
  @Previewable @FocusState var isFocused: Bool

  PathField(text: $text, base: nil, isFocused: $isFocused, emptySuggestions: ["~/Documents/", "/Library/Fonts/"]) {}
    .padding()
    .frame(width: 420, height: 260, alignment: .top)
}

#Preview("Empty, German") {
  @Previewable @State var text = ""
  @Previewable @FocusState var isFocused: Bool

  PathField(text: $text, base: nil, isFocused: $isFocused, emptySuggestions: ["~/Dokumente/", "/Library/Fonts/"]) {}
    .padding()
    .frame(width: 420, height: 260, alignment: .top)
    .environment(\.locale, Locale(identifier: "de"))
}

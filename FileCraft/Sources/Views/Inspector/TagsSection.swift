/*
 * TagsSection.swift
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

/// The Tags section: the item's tags with a remove button each, and a field that adds tags with suggestions from
/// the known tags. For several items, tags that only some carry are dimmed.
internal struct TagsSection: View {

  // MARK: - Properties

  internal let model: InspectorModel
  /// The tags offered as suggestions, such as the sidebar's tags.
  internal let knownTags: [String]

  @Environment(\.undoManager) private var undoManager
  @State private var newTag = ""

  private static let suggestionLimit = 6

  // MARK: - Body

  internal var body: some View {
    let tags = model.tags
    let partialTags = model.partialTags
    InspectorSection("Tags", id: "tags") {
      VStack(alignment: .leading, spacing: 8) {
        if tags.isEmpty == false {
          FlowLayout {
            ForEach(tags, id: \.self) { tag in
              TagChip(name: tag, isPartial: partialTags.contains(tag)) {
                model.removeTag(tag, undoManager: undoManager)
              }
            }
          }
        }
        TextField("Add Tag", text: $newTag)
          .textFieldStyle(.roundedBorder)
          .onSubmit(addTypedTag)
        let suggestions = suggestions(excluding: Set(tags).subtracting(partialTags))
        if suggestions.isEmpty == false {
          FlowLayout {
            ForEach(suggestions, id: \.self) { suggestion in
              Button {
                add(suggestion)
              } label: {
                Label {
                  Text(verbatim: suggestion)
                } icon: {
                  TagColorDot(name: suggestion)
                }
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
            }
          }
        }
      }
    }
  }

  // MARK: - Private

  /// The known tags starting with the typed text, ignoring case and diacritics, without those all items carry.
  private func suggestions(excluding presentTags: Set<String>) -> [String] {
    let typed = newTag.trimmingCharacters(in: .whitespaces)
    guard typed.isEmpty == false else {
      return []
    }
    return knownTags
      .filter { presentTags.contains($0) == false }
      .filter { $0.range(of: typed, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil }
      .prefix(Self.suggestionLimit)
      .map(\.self)
  }

  /// Return adds the first suggestion when there is one, otherwise the typed text as a new tag.
  private func addTypedTag() {
    let typed = newTag.trimmingCharacters(in: .whitespaces)
    guard typed.isEmpty == false else {
      return
    }
    let presentTags = Set(model.tags).subtracting(model.partialTags)
    add(suggestions(excluding: presentTags).first ?? typed)
  }

  private func add(_ tag: String) {
    model.addTag(tag, undoManager: undoManager)
    newTag = ""
  }
}

/// One tag with its color and a remove button.
private struct TagChip: View {

  let name: String
  /// Whether only some of several items carry the tag.
  let isPartial: Bool
  let remove: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      TagColorDot(name: name)
      Text(verbatim: name)
        .lineLimit(1)
      Button(action: remove) {
        Image(systemName: "xmark")
          .font(.caption2.weight(.semibold))
      }
      .buttonStyle(.borderless)
      .help(Text("Remove Tag"))
      .accessibilityLabel(Text("Remove “\(name)”"))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(.quaternary, in: .capsule)
    .opacity(isPartial ? 0.55 : 1)
    .help(isPartial ? Text("Only some of the selected items have this tag.") : Text(verbatim: name))
  }
}

/// The color of a tag as a small dot.
private struct TagColorDot: View {

  let name: String

  var body: some View {
    Circle()
      .fill(TagColors.color(for: name))
      .frame(width: 8, height: 8)
      .accessibilityHidden(true)
  }
}

#Preview("English") {
  TagsSection(model: InspectorModel(), knownTags: PreviewFixtures.tagNames(in: .english))
    .padding()
    .frame(width: 300)
}

#Preview("German") {
  TagsSection(model: InspectorModel(), knownTags: PreviewFixtures.tagNames(in: .german))
    .padding()
    .frame(width: 300)
    .environment(\.locale, Locale(identifier: "de"))
}

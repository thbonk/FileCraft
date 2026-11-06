/*
 * TagsSheet.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-06.
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

/// File > Tags…: turns tags on and off for the selected items, or the current folder without a selection. Changes
/// apply at once.
internal struct TagsSheet: View {

  // MARK: - Properties

  internal let urls: [URL]

  @Environment(\.dismiss) private var dismiss
  @State private var assignment = TagAssignment(tags: [:])
  @State private var knownTags: [String] = []
  @State private var newTag = ""
  @State private var failure: String?

  // MARK: - Body

  internal var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Tags of \(urls.count) Items")
        .font(.headline)
      List(allTags, id: \.self) { tag in
        Button {
          toggle(tag)
        } label: {
          HStack {
            Image(systemName: symbol(for: assignment.state(of: tag)))
              .foregroundStyle(.tint)
            TagDots(tagNames: [tag])
            Text(verbatim: tag)
          }
        }
        .buttonStyle(.plain)
        .accessibilityValue(Text(accessibilityValue(for: assignment.state(of: tag))))
      }
      .frame(minHeight: 220)
      HStack {
        TextField("New Tag", text: $newTag)
          .onSubmit(addNewTag)
        Button("Add", action: addNewTag)
          .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
      }
      if let failure {
        Label {
          Text(verbatim: failure)
        } icon: {
          Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.callout)
        .foregroundStyle(.red)
      }
      HStack {
        Spacer()
        Button("Done") {
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 360)
    .task {
      await load()
    }
  }

  // MARK: - Private

  /// The known tags followed by tags of the items that are not known yet.
  private var allTags: [String] {
    let itemTags = Set(assignment.tags.values.flatMap { $0 })
    return knownTags + itemTags.subtracting(knownTags).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
  }

  private func load() async {
    var tags: [URL: [String]] = [:]
    for url in urls {
      tags[url] = (try? url.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []
    }
    assignment = TagAssignment(tags: tags)
    knownTags = await TagLibrary.userTags()
  }

  private func toggle(_ tag: String) {
    let changed = assignment.toggle(tag)
    Task {
      for (url, tags) in changed {
        do {
          try await ItemEditor.setTags(tags, of: url)
        } catch {
          failure = error.localizedDescription
        }
      }
    }
  }

  private func addNewTag() {
    let tag = newTag.trimmingCharacters(in: .whitespaces)
    guard tag.isEmpty == false else {
      return
    }
    newTag = ""
    if assignment.state(of: tag) != .on {
      toggle(tag)
    }
  }

  private func symbol(for state: TagAssignment.State) -> String {
    switch state {
    case .on:
      "checkmark.square.fill"
    case .off:
      "square"
    case .mixed:
      "minus.square.fill"
    }
  }

  private func accessibilityValue(for state: TagAssignment.State) -> LocalizedStringResource {
    switch state {
    case .on:
      "On"
    case .off:
      "Off"
    case .mixed:
      "Some Items"
    }
  }
}

#Preview {
  TagsSheet(urls: [URL(filePath: "/tmp/Preview.txt")])
}

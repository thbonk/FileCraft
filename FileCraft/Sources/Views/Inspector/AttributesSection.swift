/*
 * AttributesSection.swift
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

/// The Attributes section: Locked, Hide Extension and Hidden. For several items the toggles show a mixed state
/// when the items differ, and a change applies to all of them as one undoable edit.
internal struct AttributesSection: View {

  // MARK: - Properties

  internal let model: InspectorModel

  @Environment(\.undoManager) private var undoManager

  // MARK: - Body

  internal var body: some View {
    InspectorSection("Attributes", id: "attributes") {
      VStack(alignment: .leading, spacing: 4) {
        toggle("Locked", .locked)
        toggle("Hide Extension", .hiddenExtension)
        if model.details != nil {
          toggle("Hidden", .hidden)
        }
      }
    }
  }

  // MARK: - Private

  private func toggle(_ title: LocalizedStringKey, _ attribute: ItemAttribute) -> some View {
    Toggle(title, sources: bindings(for: attribute), isOn: \.self)
      .toggleStyle(.checkbox)
  }

  /// One binding per item; their setters are collected into one edit, see `InspectorModel.queueAttribute`.
  private func bindings(for attribute: ItemAttribute) -> [Binding<Bool>] {
    let items = model.details.map { [$0.item] } ?? model.items
    return items.map { item in
      Binding {
        model.value(of: attribute, for: item)
      } set: { isOn in
        model.queueAttribute(attribute, of: item, to: isOn, undoManager: undoManager)
      }
    }
  }
}

/// The Extended Attributes section: the names and sizes of the item's extended attributes, read-only.
internal struct ExtendedAttributesSection: View {

  // MARK: - Properties

  internal let attributes: [ExtendedAttribute]

  // MARK: - Body

  internal var body: some View {
    InspectorSection("Extended Attributes", id: "extendedAttributes") {
      if attributes.isEmpty {
        Text("None")
          .foregroundStyle(.secondary)
      } else {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 4) {
          ForEach(attributes, id: \.name) { attribute in
            GridRow {
              Text(verbatim: attribute.name)
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .help(Text(verbatim: attribute.name))
              Text("\(attribute.size) bytes")
                .font(.caption)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            }
          }
        }
        .textSelection(.enabled)
      }
    }
  }
}

#Preview {
  VStack(alignment: .leading) {
    AttributesSection(model: InspectorModel())
    ExtendedAttributesSection(attributes: [
      ExtendedAttribute(name: "com.apple.quarantine", size: 57),
      ExtendedAttribute(name: "com.apple.metadata:kMDItemWhereFroms", size: 120),
    ])
  }
  .padding()
  .frame(width: 300)
}

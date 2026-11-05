/*
 * PermissionsSection.swift
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

/// The Permissions section: owner and group, read, write and execute for owner, group and everyone, the octal
/// mode, the access control entries and, for folders, Apply to Enclosed Items.
///
/// Owner and group are read-only until changes go through the privileged helper (task 10.9).
internal struct PermissionsSection: View {

  // MARK: - Types

  /// Who a permission applies to, with the shift of its bits in the mode.
  private enum Audience: Int, CaseIterable {
    case owner = 6
    case group = 3
    case everyone = 0
  }

  private enum Right: UInt16, CaseIterable {
    case read = 4
    case write = 2
    case execute = 1
  }

  // MARK: - Properties

  internal let details: ItemDetails
  internal let model: InspectorModel

  @Environment(\.undoManager) private var undoManager
  @State private var isConfirmingEnclosedItems = false

  // MARK: - Body

  internal var body: some View {
    let item = details.item
    let mode = item.permissions ?? 0
    InspectorSection("Permissions", id: "permissions") {
      VStack(alignment: .leading, spacing: 10) {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 4) {
          InspectorRow("Owner") {
            Text(verbatim: details.ownerName ?? "–")
          }
          InspectorRow("Group") {
            Text(verbatim: details.groupName ?? "–")
          }
          InspectorRow("Octal") {
            Text(verbatim: String(format: "%04o", mode))
              .monospacedDigit()
          }
        }
        Grid(alignment: .center, horizontalSpacing: 12, verticalSpacing: 4) {
          GridRow {
            Color.clear
              .frame(width: 1, height: 1)
            Text("Read")
            Text("Write")
            Text("Execute")
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          ForEach(Audience.allCases, id: \.self) { audience in
            GridRow {
              Text(title(of: audience))
                .gridColumnAlignment(.leading)
              ForEach(Right.allCases, id: \.self) { right in
                permissionToggle(audience: audience, right: right, mode: mode)
              }
            }
          }
        }
        .disabled(item.permissions == nil)
        if details.accessControlEntries.isEmpty == false {
          VStack(alignment: .leading, spacing: 2) {
            Text("Access Control")
              .font(.caption)
              .foregroundStyle(.secondary)
            ForEach(details.accessControlEntries, id: \.self) { entry in
              Text(verbatim: entry)
                .font(.caption)
                .textSelection(.enabled)
            }
          }
        }
        if item.isDirectory && item.isPackage == false {
          Button("Apply to Enclosed Items…") {
            isConfirmingEnclosedItems = true
          }
          .disabled(item.permissions == nil)
        }
      }
    }
    .alert(
      Text("Apply the permissions of “\(item.localizedName)” to all items it contains?"),
      isPresented: $isConfirmingEnclosedItems
    ) {
      Button("Apply") {
        model.applyPermissionsToEnclosedItems(undoManager: undoManager)
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Folders and executable files keep their execute permission; other files get none.")
    }
  }

  // MARK: - Private

  private func permissionToggle(audience: Audience, right: Right, mode: UInt16) -> some View {
    let bit = right.rawValue << UInt16(audience.rawValue)
    return Toggle(isOn: Binding {
      mode & bit != 0
    } set: { isOn in
      model.setPermission(bit, to: isOn, undoManager: undoManager)
    }) {
      Text(accessibilityLabel(audience: audience, right: right))
    }
    .toggleStyle(.checkbox)
    .labelsHidden()
  }

  private func title(of audience: Audience) -> LocalizedStringKey {
    switch audience {
    case .owner:
      "Owner"
    case .group:
      "Group"
    case .everyone:
      "Everyone"
    }
  }

  private func accessibilityLabel(audience: Audience, right: Right) -> LocalizedStringKey {
    switch (audience, right) {
    case (.owner, .read):
      "Owner can read"
    case (.owner, .write):
      "Owner can write"
    case (.owner, .execute):
      "Owner can execute"
    case (.group, .read):
      "Group can read"
    case (.group, .write):
      "Group can write"
    case (.group, .execute):
      "Group can execute"
    case (.everyone, .read):
      "Everyone can read"
    case (.everyone, .write):
      "Everyone can write"
    case (.everyone, .execute):
      "Everyone can execute"
    }
  }
}

#Preview("English") {
  PermissionsSection(
    details: ItemDetails(
      item: PreviewFixtures.items(in: .english)[0],
      isLocked: false,
      ownerName: "anna",
      groupName: "staff",
      accessControlEntries: ["everyone (group): deny delete"],
      extendedAttributes: []),
    model: InspectorModel())
    .padding()
    .frame(width: 300)
}

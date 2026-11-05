/*
 * ListColumns.swift
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

/// The optional columns of list view, shared by the table and the View Options panel.
internal enum ListColumn: String, CaseIterable, Identifiable {
  case dateModified
  case dateCreated
  case dateLastOpened
  case dateAdded
  case size
  case kind
  case pathExtension = "extension"
  case tags
  case version
  case permissions
  case owner
  case group

  // MARK: - Properties

  internal var id: String {
    rawValue
  }

  /// The column's customization identifier in the table.
  internal var customizationID: String {
    rawValue
  }

  internal var isVisibleByDefault: Bool {
    switch self {
    case .dateModified, .size, .kind:
      true
    default:
      false
    }
  }

  internal var title: LocalizedStringResource {
    switch self {
    case .dateModified:
      "Date Modified"
    case .dateCreated:
      "Date Created"
    case .dateLastOpened:
      "Date Last Opened"
    case .dateAdded:
      "Date Added"
    case .size:
      "Size"
    case .kind:
      "Kind"
    case .pathExtension:
      "Extension"
    case .tags:
      "Tags"
    case .version:
      "Version"
    case .permissions:
      "Permissions"
    case .owner:
      "Owner"
    case .group:
      "Group"
    }
  }

  // MARK: - Visibility

  /// Whether the column is shown with `customization`.
  internal func isVisible(in customization: TableColumnCustomization<FileRow>) -> Bool {
    switch customization[visibility: customizationID] {
    case .visible:
      true
    case .hidden:
      false
    default:
      isVisibleByDefault
    }
  }
}

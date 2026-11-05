/*
 * KeyTitles.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-10-30.
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

import Foundation

extension SortKey {
  /// The localized name shown in menus and column headers.
  nonisolated internal var title: LocalizedStringResource {
    switch self {
    case .name:
      "Name"
    case .kind:
      "Kind"
    case .size:
      "Size"
    case .dateModified:
      "Date Modified"
    case .dateCreated:
      "Date Created"
    case .dateLastOpened:
      "Date Last Opened"
    case .dateAdded:
      "Date Added"
    case .pathExtension:
      "Extension"
    case .tags:
      "Tags"
    }
  }
}

extension GroupingKey {
  /// The localized name shown in the Group By menu.
  nonisolated internal var title: LocalizedStringResource {
    switch self {
    case .none:
      "None"
    case .kind:
      "Kind"
    case .dateModified:
      "Date Modified"
    case .dateCreated:
      "Date Created"
    case .size:
      "Size"
    case .pathExtension:
      "Extension"
    case .tags:
      "Tags"
    }
  }
}

extension BrowserTextSize {
  /// The localized name shown in the View Options panel and in Settings.
  nonisolated internal var title: LocalizedStringResource {
    switch self {
    case .small:
      "Small"
    case .medium:
      "Medium"
    case .large:
      "Large"
    }
  }
}

extension LabelPosition {
  /// The localized name shown in the View Options panel.
  nonisolated internal var title: LocalizedStringResource {
    switch self {
    case .bottom:
      "Bottom"
    case .right:
      "Right"
    }
  }
}

extension StandardLocation {
  /// The localized name shown in the Go menu.
  nonisolated internal var title: LocalizedStringResource {
    switch self {
    case .computer:
      "Computer"
    case .home:
      "Home"
    case .desktop:
      "Desktop"
    case .documents:
      "Documents"
    case .downloads:
      "Downloads"
    case .applications:
      "Applications"
    case .utilities:
      "Utilities"
    case .iCloudDrive:
      "iCloud Drive"
    case .library:
      "Library"
    }
  }
}

extension PathFormat {
  /// The localized name shown in Edit > Copy Path As.
  nonisolated internal var title: LocalizedStringResource {
    switch self {
    case .posix:
      "POSIX Path"
    case .homeRelative:
      "Path Relative to Home"
    case .fileURL:
      "File URL"
    case .name:
      "Name Only"
    case .shellEscaped:
      "Shell-Escaped Path"
    }
  }
}

extension CompressionFormat {

  /// The name of the format as menus show it, the same in every language.
  internal var title: String {
    switch self {
    case .zip:
      "ZIP"
    case .tarGzip:
      "tar.gz"
    case .tarBzip2:
      "tar.bz2"
    case .tarXz:
      "tar.xz"
    }
  }
}

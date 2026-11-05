/*
 * TransferDestinationSheet.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-04.
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
import UniformTypeIdentifiers

/// The destination chooser of Copy To… and Move To… (file operations spec, "Copy to and move to"): the other
/// pane's folder and the recent folders as shortcuts, and any folder through Choose….
internal struct TransferDestinationSheet: View {

  // MARK: - Properties

  internal let kind: FileOperationKind
  internal let itemCount: Int
  internal let otherPaneFolder: URL?
  internal let recentFolders: [URL]
  /// Receives the chosen folder, or nil when the user cancels.
  internal let onChoose: (URL?) -> Void

  @State private var isChoosingFolder = false

  // MARK: - Body

  internal var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      title
        .font(.headline)
      List {
        if let otherPaneFolder {
          Section("Other Pane") {
            destinationRow(otherPaneFolder)
          }
        }
        if recentFolders.isEmpty == false {
          Section("Recent Folders") {
            ForEach(recentFolders, id: \.self) { folder in
              destinationRow(folder)
            }
          }
        }
      }
      .frame(minHeight: 200)
      HStack {
        Button("Choose…") {
          isChoosingFolder = true
        }
        Spacer()
        Button("Cancel", role: .cancel) {
          onChoose(nil)
        }
        .keyboardShortcut(.cancelAction)
      }
    }
    .padding(20)
    .frame(width: 420, height: 360)
    .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
      if case .success(let folder) = result {
        onChoose(folder)
      }
    }
  }

  // MARK: - Parts

  private var title: Text {
    switch kind {
    case .move:
      Text("Move \(itemCount) items to:")
    case .copy, .delete, .compress, .expand:
      Text("Copy \(itemCount) items to:")
    }
  }

  private func destinationRow(_ folder: URL) -> some View {
    Button {
      onChoose(folder)
    } label: {
      HStack(spacing: 8) {
        FileIcon(url: folder, size: 20)
        VStack(alignment: .leading, spacing: 1) {
          Text(verbatim: FileManager.default.displayName(atPath: folder.path(percentEncoded: false)))
          Text(verbatim: folder.path(percentEncoded: false))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Previews

#Preview("Move, English") {
  TransferDestinationSheet(
    kind: .move,
    itemCount: 3,
    otherPaneFolder: URL(filePath: "/Volumes/Backup", directoryHint: .isDirectory),
    recentFolders: [URL(filePath: "/Users/anna/Archive"), URL(filePath: "/Users/anna/Projects")]
  ) { _ in }
}

#Preview("Copy, German") {
  TransferDestinationSheet(
    kind: .copy, itemCount: 1, otherPaneFolder: nil, recentFolders: [URL(filePath: "/Users/anna/Archive")]
  ) { _ in }
  .environment(\.locale, Locale(identifier: "de"))
}

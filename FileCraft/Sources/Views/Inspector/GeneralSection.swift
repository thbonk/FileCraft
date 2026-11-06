/*
 * GeneralSection.swift
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

/// The General section: icon, editable name, kind, sizes, folder contents, location, dates and the extra facts an
/// item has, such as its version, pixel size, duration or original.
internal struct GeneralSection: View {

  // MARK: - Properties

  internal let details: ItemDetails
  internal let model: InspectorModel
  internal let reveal: (URL) -> Void

  @AppStorage(SettingsKeys.sizeUnits.name) private var sizeUnits = SettingsKeys.sizeUnits.defaultValue
  @Environment(\.locale) private var locale
  @Environment(\.undoManager) private var undoManager
  @State private var name = ""
  @FocusState private var isNameFocused: Bool

  // MARK: - Body

  internal var body: some View {
    let item = details.item
    InspectorSection("General", id: "general") {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .top, spacing: 10) {
          FileIcon(url: item.url, size: 48)
          VStack(alignment: .leading, spacing: 4) {
            TextField("Name", text: $name)
              .textFieldStyle(.roundedBorder)
              .focused($isNameFocused)
              .onSubmit(commitName)
              .onChange(of: isNameFocused) { _, isFocused in
                if isFocused == false {
                  commitName()
                }
              }
            if case .invalidName(let validationError) = model.editError {
              Label {
                NameValidationMessage.text(for: validationError)
                  .fixedSize(horizontal: false, vertical: true)
              } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
              }
              .font(.callout)
              .foregroundStyle(.red)
            }
          }
        }
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 4) {
          facts(for: item)
        }
      }
    }
    .onChange(of: item.name, initial: true) {
      name = item.name
    }
  }

  // MARK: - Facts

  @ViewBuilder
  private func facts(for item: FileItem) -> some View {
    let formatter = ByteSizeFormatter(units: sizeUnits, locale: locale)
    InspectorRow("Kind") {
      Text(verbatim: item.kind)
    }
    if item.isDirectory {
      if let size = model.totalSize {
        InspectorRow("Contents") {
          Text("\(size.itemCount) items")
        }
        sizeRows(logicalBytes: size.logicalBytes, physicalBytes: size.physicalBytes, formatter: formatter)
      } else if model.isCalculatingSize {
        InspectorRow("Contents") {
          ProgressView()
            .controlSize(.small)
        }
      }
    } else if let size = item.size {
      sizeRows(logicalBytes: size, physicalBytes: item.allocatedSize, formatter: formatter)
    }
    InspectorRow("Where") {
      Button(Self.abbreviatedPath(of: item.url.deletingLastPathComponent())) {
        reveal(item.url)
      }
      .buttonStyle(.link)
      .help(Text("Show in Browser"))
    }
    dateRow("Created", item.creationDate)
    dateRow("Modified", item.modificationDate)
    dateRow("Last Opened", details.lastOpenedDate)
    dateRow("Added", item.addedDate)
    if let version = details.version {
      InspectorRow("Version") {
        Text(verbatim: version)
      }
    }
    if let pixelSize = details.pixelSize {
      InspectorRow("Dimensions") {
        Text(verbatim: "\(pixelSize.width) × \(pixelSize.height)")
      }
    }
    if let duration = details.duration {
      InspectorRow("Duration") {
        Text(Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond)))
      }
    }
    if let original = details.original {
      InspectorRow("Original") {
        switch original {
        case .original(let url):
          Button(Self.abbreviatedPath(of: url)) {
            reveal(url)
          }
          .buttonStyle(.link)
        case .broken:
          Label("Not found", systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
        }
      }
    }
  }

  @ViewBuilder
  private func sizeRows(logicalBytes: Int64, physicalBytes: Int64?, formatter: ByteSizeFormatter) -> some View {
    InspectorRow("Size") {
      VStack(alignment: .leading, spacing: 1) {
        Text(formatter.string(for: logicalBytes))
        Text("\(logicalBytes) bytes")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    if let physicalBytes {
      InspectorRow("On Disk") {
        Text(formatter.string(for: physicalBytes))
      }
    }
  }

  @ViewBuilder
  private func dateRow(_ label: LocalizedStringKey, _ date: Date?) -> some View {
    if let date {
      InspectorRow(label) {
        Text(date.formatted(date: .abbreviated, time: .shortened))
      }
    }
  }

  // MARK: - Private

  private func commitName() {
    let newName = name
    guard newName != details.item.name else {
      return
    }
    model.rename(to: newName, undoManager: undoManager)
  }

  /// The path with the home folder written as "~".
  private static func abbreviatedPath(of url: URL) -> String {
    PathFormatter.string(for: url, format: .homeRelative)
  }
}

#Preview("English") {
  GeneralSection(
    details: ItemDetails(
      item: PreviewFixtures.items(in: .english)[0],
      isLocked: false,
      version: "1.2",
      accessControlEntries: [],
      extendedAttributes: []),
    model: InspectorModel()
  ) { _ in }
  .padding()
  .frame(width: 300)
}

#Preview("German") {
  GeneralSection(
    details: ItemDetails(
      item: PreviewFixtures.items(in: .german)[1],
      isLocked: false,
      accessControlEntries: [],
      extendedAttributes: []),
    model: InspectorModel()
  ) { _ in }
  .padding()
  .frame(width: 300)
  .environment(\.locale, Locale(identifier: "de"))
}

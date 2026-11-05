/*
 * OpenWithSection.swift
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
import UniformTypeIdentifiers

/// The Open With section: the application that opens the file, the choice of another one for this file, and
/// Change All for every file of the same type.
internal struct OpenWithSection: View {

  // MARK: - Types

  private enum Choice: Hashable {
    case application(URL)
    case other
  }

  // MARK: - Properties

  internal let details: ItemDetails
  internal let model: InspectorModel

  @Environment(\.undoManager) private var undoManager
  @State private var isChoosingOther = false
  @State private var isConfirmingChangeAll = false

  // MARK: - Body

  internal var body: some View {
    InspectorSection("Open With", id: "openWith") {
      VStack(alignment: .leading, spacing: 8) {
        Picker("Application", selection: choice) {
          ForEach(model.applications) { application in
            Text(verbatim: application.name)
              .tag(Choice.application(application.url))
          }
          Divider()
          Text("Other…")
            .tag(Choice.other)
        }
        .labelsHidden()
        .disabled(model.applications.isEmpty)
        HStack(alignment: .firstTextBaseline) {
          Text("Use this application to open all documents like this one.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 8)
          Button("Change All…") {
            isConfirmingChangeAll = true
          }
          .disabled(model.canChangeAll == false)
        }
      }
    }
    .fileImporter(isPresented: $isChoosingOther, allowedContentTypes: [.application]) { result in
      if case .success(let application) = result {
        model.setApplication(application, undoManager: undoManager)
      }
    }
    .fileDialogDefaultDirectory(URL(filePath: "/Applications", directoryHint: .isDirectory))
    .alert(Text("Change all similar documents to open with “\(currentApplicationName)”?"), isPresented: $isConfirmingChangeAll) {
      Button("Change All") {
        model.changeAllToCurrentApplication(undoManager: undoManager)
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This applies to all documents of the kind “\(details.item.kind)”.")
    }
  }

  // MARK: - Private

  private var choice: Binding<Choice> {
    Binding {
      model.currentApplication.map(Choice.application) ?? .other
    } set: { newChoice in
      switch newChoice {
      case .application(let url):
        model.setApplication(url, undoManager: undoManager)
      case .other:
        isChoosingOther = true
      }
    }
  }

  private var currentApplicationName: String {
    model.applications.first { $0.url == model.currentApplication }?.name
      ?? model.currentApplication.map { FileManager.default.displayName(atPath: $0.path(percentEncoded: false)) }
      ?? ""
  }
}

#Preview {
  OpenWithSection(
    details: ItemDetails(item: PreviewFixtures.items(in: .english)[3], isLocked: false, accessControlEntries: [], extendedAttributes: []),
    model: InspectorModel())
    .padding()
    .frame(width: 300)
}

/*
 * RenameField.swift
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

import SwiftUI

/// The inline name editor of all file views. It selects the name without its extension and stays open
/// while the name is invalid.
internal struct RenameField: View {

  // MARK: - Properties

  internal let item: FileItem
  internal let tab: TabModel
  internal var alignment: TextAlignment = .leading

  @State private var text: String
  @State private var selection: TextSelection?
  @State private var message: Text?
  @State private var extensionChange: ExtensionChange?
  @FocusState private var isFocused: Bool

  // MARK: - Initialization

  internal init(item: FileItem, tab: TabModel, alignment: TextAlignment = .leading) {
    self.item = item
    self.tab = tab
    self.alignment = alignment
    let name = item.name
    let baseName = item.isDirectory && item.isPackage == false ? name : (name as NSString).deletingPathExtension
    let baseEnd = name.index(name.startIndex, offsetBy: baseName.count, limitedBy: name.endIndex) ?? name.endIndex
    _text = State(initialValue: name)
    _selection = State(initialValue: TextSelection(range: name.startIndex..<baseEnd))
  }

  // MARK: - Body

  internal var body: some View {
    TextField("Name", text: $text, selection: $selection)
      .textFieldStyle(.squareBorder)
      .multilineTextAlignment(alignment)
      .labelsHidden()
      .focused($isFocused)
      .onAppear {
        isFocused = true
      }
      .onSubmit(commit)
      .onExitCommand {
        tab.cancelRename()
      }
      .onChange(of: text) {
        message = nil
      }
      .popover(isPresented: isShowingMessage, arrowEdge: .bottom) {
        message?
          .padding(10)
          .frame(maxWidth: 280)
          .fixedSize(horizontal: false, vertical: true)
      }
      .alert(extensionChangeTitle, isPresented: isConfirmingExtensionChange, presenting: extensionChange) { change in
        // Keeping the old extension appends it, as Finder does: "notes.md" becomes "notes.md.txt".
        Button("Keep .\(change.oldExtension)") {
          commit(change.newName + "." + change.oldExtension, confirmsExtensionChange: true)
        }
        Button("Use .\(change.newExtension)") {
          commit(change.newName, confirmsExtensionChange: true)
        }
      } message: { _ in
        Text("If you make this change, your document may open in a different application.")
      }
  }

  // MARK: - Types

  /// A rename that changes the extension and waits for the user's choice.
  private struct ExtensionChange {
    let newName: String
    let oldExtension: String
    let newExtension: String
  }

  // MARK: - Private

  private var isShowingMessage: Binding<Bool> {
    Binding {
      message != nil
    } set: { isShown in
      if isShown == false {
        message = nil
      }
    }
  }

  private var isConfirmingExtensionChange: Binding<Bool> {
    Binding {
      extensionChange != nil
    } set: { isShown in
      if isShown == false {
        extensionChange = nil
      }
    }
  }

  private var extensionChangeTitle: Text {
    guard let extensionChange else {
      return Text(verbatim: "")
    }
    return Text("Are you sure you want to change the extension from “.\(extensionChange.oldExtension)” to “.\(extensionChange.newExtension)”?")
  }

  private func commit() {
    commit(text, confirmsExtensionChange: false)
  }

  private func commit(_ newName: String, confirmsExtensionChange: Bool) {
    Task {
      switch await tab.commitRename(of: item, to: newName, confirmsExtensionChange: confirmsExtensionChange) {
      case .renamed:
        break
      case .invalid(let error):
        message = NameValidationMessage.text(for: error)
      case .failed(let description):
        message = Text(description)
      case .needsExtensionConfirmation(let oldExtension, let newExtension):
        extensionChange = ExtensionChange(newName: newName, oldExtension: oldExtension, newExtension: newExtension)
      }
    }
  }
}

/// Localized explanations of invalid names.
internal enum NameValidationMessage {

  internal static func text(for error: NameValidationError) -> Text {
    switch error {
    case .empty:
      Text("A name can’t be empty.")
    case .invalidCharacter:
      Text("A name can’t contain “:” or “/”.")
    case .tooLong:
      Text("The name is too long.")
    case .alreadyExists(let name):
      Text("The name “\(name)” is already taken. Please choose a different name.")
    }
  }
}

#Preview {
  let tab = TabModel.preview(in: .english)
  let item = tab.visibleItems[2]

  return RenameField(item: item, tab: tab)
    .frame(width: 240)
    .padding()
}

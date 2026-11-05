/*
 * GoToFolderSheet.swift
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

/// Go > Go to Folder… (⇧⌘G): a path field with completions and the recent entries. A folder opens in the tab,
/// a file is revealed, and a path that does not exist shows an error below the field.
internal struct GoToFolderSheet: View {

  // MARK: - Properties

  internal let tab: TabModel
  internal let recents: RecentsStore?

  @Environment(\.dismiss) private var dismiss
  @State private var path = ""
  @State private var errorMessage: LocalizedStringResource?
  @State private var isChecking = false
  @FocusState private var isFieldFocused: Bool

  // MARK: - Body

  internal var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Go to Folder")
        .font(.headline)
      PathField(
        text: $path,
        base: tab.folderURL,
        isFocused: $isFieldFocused,
        emptySuggestions: recents?.goToFolderEntries ?? [],
        onSubmit: go)
      if let errorMessage {
        Text(errorMessage)
          .font(.callout)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
      }
      HStack {
        Spacer()
        Button("Cancel", role: .cancel) {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)
        // Return reaches the field first, which knows the highlighted suggestion, so Go is no default button.
        Button("Go", action: go)
          .buttonStyle(.borderedProminent)
          .disabled(path.isEmpty || isChecking)
      }
    }
    .padding(20)
    .frame(width: 460)
    .onAppear {
      isFieldFocused = true
    }
    .onChange(of: path) {
      errorMessage = nil
    }
  }

  // MARK: - Private

  private func go() {
    guard isChecking == false else {
      return
    }
    let enteredPath = path
    guard let url = PathInputParser.url(for: enteredPath, relativeTo: tab.folderURL) else {
      errorMessage = "Enter the path of a folder or file."
      return
    }
    isChecking = true
    Task {
      defer {
        isChecking = false
      }
      guard let item = try? await FileSystemService().item(at: url) else {
        errorMessage = "There is no folder or file at “\(enteredPath)”."
        return
      }
      recents?.recordGoToFolderEntry(enteredPath)
      if item.isDirectory && item.isPackage == false {
        tab.navigate(toFolder: item.url)
      } else {
        tab.reveal(item.url)
      }
      dismiss()
    }
  }
}

#Preview("English") {
  GoToFolderSheet(tab: .preview(in: .english), recents: nil)
}

#Preview("German") {
  GoToFolderSheet(tab: .preview(in: .german), recents: nil)
    .environment(\.locale, Locale(identifier: "de"))
}

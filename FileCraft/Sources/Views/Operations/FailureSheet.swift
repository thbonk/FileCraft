/*
 * FailureSheet.swift
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

/// The error dialog of an operation (file operations spec, "Error handling"): Skip, Retry and Stop, plus applying
/// Skip to all later errors, and Authenticate and Retry through the privileged helper for permission errors.
internal struct FailureSheet: View {

  // MARK: - Properties

  internal let kind: FileOperationKind
  internal let item: URL
  internal let reason: String
  /// Whether Authenticate and Retry is offered.
  internal var canAuthenticate = false
  internal let onAnswer: (FailureChoice, Bool) -> Void

  @State private var appliesToAll = false

  // MARK: - Body

  internal var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.largeTitle)
          .foregroundStyle(.yellow)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
          title
            .font(.headline)
          Text(verbatim: reason)
            .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
      }
      Toggle("Apply to all errors", isOn: $appliesToAll)
      HStack {
        Button("Stop") {
          onAnswer(.stop, false)
        }
        .keyboardShortcut(.cancelAction)
        Spacer()
        Button("Skip") {
          onAnswer(.skip, appliesToAll)
        }
        if canAuthenticate {
          Button("Authenticate and Retry") {
            onAnswer(.authenticateAndRetry, false)
          }
        }
        Button("Retry") {
          onAnswer(.retry, false)
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 460)
    .interactiveDismissDisabled()
  }

  private var title: Text {
    switch kind {
    case .copy:
      Text("“\(item.lastPathComponent)” couldn’t be copied.")
    case .move:
      Text("“\(item.lastPathComponent)” couldn’t be moved.")
    case .delete:
      Text("“\(item.lastPathComponent)” couldn’t be deleted.")
    case .compress:
      Text("“\(item.lastPathComponent)” couldn’t be compressed.")
    case .expand:
      Text("“\(item.lastPathComponent)” couldn’t be expanded.")
    }
  }
}

// MARK: - Previews

#Preview("English") {
  FailureSheet(
    kind: .copy,
    item: URL(filePath: "/Users/anna/Projects/secret.key"),
    reason: "The file “secret.key” couldn’t be opened because you don’t have permission to view it."
  ) { _, _ in }
}

#Preview("German") {
  FailureSheet(
    kind: .move,
    item: URL(filePath: "/Users/anna/Projects/secret.key"),
    reason: "Die Datei „secret.key“ konnte nicht geöffnet werden, da Sie nicht die Zugriffsrechte haben, sie anzuzeigen.",
    canAuthenticate: true
  ) { _, _ in }
  .environment(\.locale, Locale(identifier: "de"))
}

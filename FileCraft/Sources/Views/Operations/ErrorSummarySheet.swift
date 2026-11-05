/*
 * ErrorSummarySheet.swift
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

/// The summary of an operation that finished with errors: the failed items and the reasons.
internal struct ErrorSummarySheet: View {

  // MARK: - Properties

  internal let operation: FileOperationProgress
  internal let onDismiss: () -> Void

  // MARK: - Body

  internal var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      title
        .font(.headline)
      List(operation.errors) { error in
        VStack(alignment: .leading, spacing: 2) {
          Text(verbatim: error.url.lastPathComponent)
          Text(verbatim: error.reason)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
      }
      .frame(minHeight: 160)
      HStack {
        Spacer()
        Button("OK") {
          onDismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 500, height: 340)
  }

  private var title: Text {
    switch operation.kind {
    case .copy:
      Text("Some items couldn’t be copied.")
    case .move:
      Text("Some items couldn’t be moved.")
    case .delete:
      Text("Some items couldn’t be deleted.")
    case .compress:
      Text("Some items couldn’t be compressed.")
    case .expand:
      Text("Some items couldn’t be expanded.")
    }
  }
}

// MARK: - Previews

#Preview("English") {
  ErrorSummarySheet(operation: OperationPreviewData.failed) {}
}

#Preview("German") {
  ErrorSummarySheet(operation: OperationPreviewData.failed) {}
    .environment(\.locale, Locale(identifier: "de"))
}

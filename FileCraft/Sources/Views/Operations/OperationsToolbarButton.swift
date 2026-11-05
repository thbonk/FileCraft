/*
 * OperationsToolbarButton.swift
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

/// The Operations toolbar item: the overall progress while operations run; it opens the Operations window.
internal struct OperationsToolbarButton: View {

  // MARK: - Properties

  internal let model: OperationQueueModel

  @Environment(\.openWindow) private var openWindow

  // MARK: - Body

  internal var body: some View {
    Button {
      openWindow(id: OperationsView.windowID)
    } label: {
      Label {
        Text("Operations")
      } icon: {
        if let fraction = model.overallFraction {
          ProgressView(value: fraction)
            .progressViewStyle(.circular)
            .controlSize(.small)
        } else {
          Image(systemName: "list.bullet.rectangle")
        }
      }
    }
    .help("Operations")
    .accessibilityValue(Text(verbatim: progressDescription))
  }

  private var progressDescription: String {
    model.overallFraction.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? ""
  }
}

// MARK: - Previews

#Preview("Running, English") {
  OperationsToolbarButton(
    model: OperationQueueModel(engine: FileOperationEngine(), operations: [OperationPreviewData.running]))
    .padding()
}

#Preview("Idle, German") {
  OperationsToolbarButton(model: OperationQueueModel(engine: FileOperationEngine()))
    .labelStyle(.titleAndIcon)
    .padding()
    .environment(\.locale, Locale(identifier: "de"))
}

/*
 * OperationsView.swift
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

/// The Operations window (design decision D4): the running and finished copy and move operations. It hosts the
/// conflict, error and summary sheets of all operations and the confirmation for quitting while they run.
internal struct OperationsView: View {

  // MARK: - Properties

  internal static let windowID = "operations"

  internal let model: OperationQueueModel

  // MARK: - Body

  internal var body: some View {
    content
      .frame(minWidth: 460, idealWidth: 520, minHeight: 220, idealHeight: 320)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("Clear Finished", systemImage: "checklist.checked") {
            Task { await model.clearFinished() }
          }
          .help("Clear Finished")
          .disabled(model.hasFinishedOperations == false)
        }
      }
      .sheet(item: presentation) { presentation in
        sheet(for: presentation)
      }
      .alert("Stop the operations and quit?", isPresented: isConfirmingQuit) {
        Button("Stop Operations and Quit", role: .destructive) {
          model.resolveQuitConfirmation(quits: true)
        }
        Button("Don’t Quit", role: .cancel) {
          model.resolveQuitConfirmation(quits: false)
        }
      } message: {
        Text("Partially copied items are removed.")
      }
      .onAppear {
        model.isWindowVisible = true
      }
      .onDisappear {
        model.isWindowVisible = false
      }
  }

  // MARK: - Parts

  @ViewBuilder private var content: some View {
    if model.operations.isEmpty {
      ContentUnavailableView(
        "No Operations",
        systemImage: "list.bullet.rectangle",
        description: Text("Copies and moves appear here while they run."))
    } else {
      List(model.operations) { operation in
        OperationRow(operation: operation, model: model)
      }
    }
  }

  @ViewBuilder private func sheet(for presentation: OperationQueueModel.Presentation) -> some View {
    switch presentation {
    case .question(let operation, let question):
      switch question.topic {
      case .conflict(let source, let existing):
        ConflictSheet(kind: operation.kind, source: source, existing: existing) { choice, appliesToAll in
          answer(.conflict(choice, appliesToAll: appliesToAll), to: question, of: operation)
        }
      case .failure(let item, let reason, let canAuthenticate):
        FailureSheet(kind: operation.kind, item: item, reason: reason, canAuthenticate: canAuthenticate) { choice, appliesToAll in
          answer(.failure(choice, appliesToAll: appliesToAll), to: question, of: operation)
        }
      }
    case .summary(let operation):
      ErrorSummarySheet(operation: operation) {
        model.dismissSummary(of: operation.id)
      }
    }
  }

  // MARK: - Bindings

  private var presentation: Binding<OperationQueueModel.Presentation?> {
    Binding {
      model.presentation
    } set: { newValue in
      if newValue == nil, case .summary(let operation)? = model.presentation {
        model.dismissSummary(of: operation.id)
      }
    }
  }

  private var isConfirmingQuit: Binding<Bool> {
    Binding {
      model.isConfirmingQuit
    } set: { isPresented in
      guard isPresented == false else {
        return
      }
      // The buttons resolve the confirmation first; this covers the alert closing in any other way.
      Task { model.resolveQuitConfirmation(quits: false) }
    }
  }

  // MARK: - Actions

  private func answer(_ answer: OperationAnswer, to question: OperationQuestion, of operation: FileOperationProgress) {
    Task { await model.answer(answer, to: question, of: operation.id) }
  }
}

// MARK: - Previews

#Preview("English") {
  OperationsView(
    model: OperationQueueModel(
      engine: FileOperationEngine(),
      operations: [OperationPreviewData.running, OperationPreviewData.paused, OperationPreviewData.failed]))
}

#Preview("Empty, German") {
  OperationsView(model: OperationQueueModel(engine: FileOperationEngine()))
    .environment(\.locale, Locale(identifier: "de"))
}

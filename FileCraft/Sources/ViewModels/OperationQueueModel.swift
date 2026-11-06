/*
 * OperationQueueModel.swift
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

import Foundation
import Observation
import SwiftUI

/// The file operations of the app for the UI: the Operations window with its questions and summaries, the toolbar
/// progress and the quit confirmation. It mirrors the engine, which does the work.
@Observable
internal final class OperationQueueModel {

  // MARK: - Types

  /// What the Operations window shows as a sheet: questions first, then error summaries.
  internal enum Presentation: Identifiable, Hashable {
    case question(FileOperationProgress, OperationQuestion)
    case summary(FileOperationProgress)

    internal var id: String {
      switch self {
      case .question(_, let question):
        "question-\(question.id)"
      case .summary(let operation):
        "summary-\(operation.id)"
      }
    }
  }

  // MARK: - Properties

  /// The operations of the app.
  internal static let shared = OperationQueueModel(engine: .shared)

  /// All operations, oldest first.
  internal private(set) var operations: [FileOperationProgress]
  /// Whether the Operations window is on screen; the window reports it.
  internal var isWindowVisible = false
  /// Whether the Operations window asks if the operations should stop so that FileCraft can quit.
  internal private(set) var isConfirmingQuit = false
  /// The operations whose error summary waits to be shown, oldest first.
  internal private(set) var pendingSummaries: [UUID] = []

  /// Opens the Operations window or brings it to the front. Browser windows provide it, so that the window also
  /// opens when no view is at hand, for example when the user quits.
  @ObservationIgnored internal var presentWindow: (@MainActor () -> Void)?

  @ObservationIgnored private let engine: FileOperationEngine
  @ObservationIgnored private let settings: SettingsStore
  @ObservationIgnored private var triggers = OperationsWindowTriggers()
  @ObservationIgnored private var announcements = OperationAnnouncements()
  /// Posts a VoiceOver announcement; tests replace it to check which messages would be announced.
  @ObservationIgnored internal var announce: (String) -> Void = { message in
    AccessibilityNotification.Announcement(message).post()
  }
  @ObservationIgnored private var observation: Task<Void, Never>?
  @ObservationIgnored private var quitReply: (@MainActor (Bool) -> Void)?

  /// The operations that have not finished, including queued and paused ones.
  internal var activeOperations: [FileOperationProgress] {
    operations.filter { $0.state.isFinished == false }
  }

  internal var isBusy: Bool {
    activeOperations.isEmpty == false
  }

  internal var hasFinishedOperations: Bool {
    operations.contains { $0.state.isFinished }
  }

  /// The share of the work done across all active operations, or nil without any.
  internal var overallFraction: Double? {
    let active = activeOperations
    guard active.isEmpty == false else {
      return nil
    }
    let totalBytes = active.reduce(Int64(0)) { $0 + $1.totalBytes }
    guard totalBytes > 0 else {
      return active.reduce(0) { $0 + $1.fractionCompleted } / Double(active.count)
    }
    return Double(active.reduce(Int64(0)) { $0 + $1.processedBytes }) / Double(totalBytes)
  }

  /// The sheet the Operations window shows; nothing while the quit confirmation is up.
  internal var presentation: Presentation? {
    guard isConfirmingQuit == false else {
      return nil
    }
    if let operation = operations.first(where: { $0.question != nil }), let question = operation.question {
      return .question(operation, question)
    }
    let summarized = pendingSummaries.lazy.compactMap { id in self.operations.first { $0.id == id } }
    return summarized.first.map(Presentation.summary)
  }

  // MARK: - Initialization

  /// - Parameter operations: Operations to show right away, for previews.
  internal init(engine: FileOperationEngine, settings: SettingsStore = SettingsStore(), operations: [FileOperationProgress] = []) {
    self.engine = engine
    self.settings = settings
    self.operations = operations
  }

  // MARK: - Operations

  /// Starts following the engine; later calls do nothing.
  internal func start() {
    guard observation == nil else {
      return
    }
    let engine = engine
    observation = Task { [weak self] in
      for await snapshot in await engine.updates() {
        self?.receive(snapshot)
      }
    }
  }

  /// Adds an operation to the engine.
  @discardableResult
  internal func enqueue(_ request: FileOperationRequest) async -> UUID {
    await engine.enqueue(request)
  }

  internal func pause(_ id: UUID) async {
    await engine.pause(id)
  }

  internal func resume(_ id: UUID) async {
    await engine.resume(id)
  }

  internal func cancel(_ id: UUID) async {
    await engine.cancel(id)
  }

  /// Waits until the operation has finished, for example to select what it created.
  internal func waitUntilFinished(_ id: UUID) async -> FileOperationProgress? {
    await engine.waitUntilFinished(id)
  }

  /// Passes the user's answer to `question`, which the operation `operationID` waits on.
  internal func answer(_ answer: OperationAnswer, to question: OperationQuestion, of operationID: UUID) async {
    await engine.answer(answer, to: question.id, of: operationID)
  }

  /// Removes the finished operations from the list.
  internal func clearFinished() async {
    await engine.removeFinished()
  }

  // MARK: - Summaries

  /// Shows the error summary of the operation `id` again.
  internal func showSummary(of id: UUID) {
    pendingSummaries.removeAll { $0 == id }
    pendingSummaries.insert(id, at: 0)
    presentWindow?()
  }

  internal func dismissSummary(of id: UUID) {
    pendingSummaries.removeAll { $0 == id }
  }

  // MARK: - Quitting

  /// Asks in the Operations window whether to stop the operations and quit; `reply` receives the decision.
  internal func confirmQuit(reply: @escaping @MainActor (Bool) -> Void) {
    quitReply = reply
    guard let presentWindow else {
      // Without any window there is nobody to ask, so the operations stop as for Stop Operations and Quit.
      resolveQuitConfirmation(quits: true)
      return
    }
    isConfirmingQuit = true
    presentWindow()
  }

  /// Ends the quit confirmation. Quitting waits until all operations stopped and partial copies are removed.
  internal func resolveQuitConfirmation(quits: Bool) {
    isConfirmingQuit = false
    guard let reply = quitReply else {
      return
    }
    quitReply = nil
    guard quits else {
      reply(false)
      return
    }
    let engine = engine
    Task {
      await engine.cancelAllAndWait()
      reply(true)
    }
  }

  // MARK: - Private

  private func receive(_ snapshot: [FileOperationProgress]) {
    operations = snapshot
    pendingSummaries.removeAll { id in snapshot.contains { $0.id == id } == false }
    let outcome = triggers.evaluate(
      snapshot,
      now: .now,
      opensAutomatically: settings.value(for: SettingsKeys.showsOperationsAutomatically),
      isWindowVisible: isWindowVisible)
    pendingSummaries.append(contentsOf: outcome.summaries)
    if outcome.presentsWindow {
      presentWindow?()
    }
    for message in announcements.evaluate(snapshot) {
      announce(message)
    }
  }
}

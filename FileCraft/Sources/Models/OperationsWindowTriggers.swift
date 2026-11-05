/*
 * OperationsWindowTriggers.swift
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

/// Decides when the Operations window opens by itself: for each question of an operation, for the error summary of
/// an operation that finished with errors, and, when the setting is on, for an operation running longer than five
/// seconds. Each reason opens the window once.
nonisolated internal struct OperationsWindowTriggers: Sendable {

  // MARK: - Types

  internal struct Outcome: Equatable, Sendable {
    /// Whether the window should open or come to the front.
    internal var presentsWindow = false
    /// The operations whose error summary should be shown, oldest first.
    internal var summaries: [UUID] = []
  }

  // MARK: - Properties

  /// How long an operation runs before the window opens automatically.
  internal static let automaticOpeningDelay: TimeInterval = 5

  private var presentedQuestions: Set<UUID> = []
  private var summarizedOperations: Set<UUID> = []
  private var automaticallyShownOperations: Set<UUID> = []

  // MARK: - Evaluating

  /// What to show after the operations changed.
  ///
  /// - Parameters:
  ///   - opensAutomatically: The setting for opening the window when an operation runs longer than five seconds.
  ///   - isWindowVisible: Whether the window is on screen; an operation it already shows does not open it again.
  internal mutating func evaluate(
    _ operations: [FileOperationProgress],
    now: Date,
    opensAutomatically: Bool,
    isWindowVisible: Bool
  ) -> Outcome {
    var outcome = Outcome()
    for operation in operations {
      if let question = operation.question, presentedQuestions.insert(question.id).inserted {
        outcome.presentsWindow = true
      }
      if operation.state == .failed, summarizedOperations.insert(operation.id).inserted {
        outcome.summaries.append(operation.id)
        outcome.presentsWindow = true
      }
      if opensAutomatically, operation.state == .running, let startDate = operation.startDate,
        now.timeIntervalSince(startDate) >= Self.automaticOpeningDelay,
        automaticallyShownOperations.insert(operation.id).inserted, isWindowVisible == false
      {
        outcome.presentsWindow = true
      }
    }
    return outcome
  }
}

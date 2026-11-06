/*
 * OperationAnnouncements.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-06.
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

/// Decides what VoiceOver should announce as operations finish: once per operation, the first time it reaches
/// `.completed`, `.failed` or `.cancelled`.
nonisolated internal struct OperationAnnouncements: Sendable {

  // MARK: - Properties

  private var announcedOperations: Set<UUID> = []

  // MARK: - Evaluating

  /// The announcements for operations that just finished, oldest first; already-announced operations are skipped.
  internal mutating func evaluate(_ operations: [FileOperationProgress]) -> [String] {
    var messages: [String] = []
    for operation in operations where operation.state.isFinished {
      guard announcedOperations.insert(operation.id).inserted else {
        continue
      }
      messages.append(Self.message(for: operation))
    }
    return messages
  }

  // MARK: - Private

  private static func message(for operation: FileOperationProgress) -> String {
    switch operation.state {
    case .cancelled:
      return String(localized: "File operation cancelled.", comment: "VoiceOver announcement when a file operation is cancelled.")
    case .failed:
      let count = operation.errors.count
      return String(
        localized: "File operation finished with \(count) errors.",
        comment: "VoiceOver announcement when a file operation finishes with failed items; the number counts them.")
    default:
      return String(
        localized: "File operation finished.", comment: "VoiceOver announcement when a file operation finishes successfully.")
    }
  }
}

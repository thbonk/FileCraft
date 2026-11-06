/*
 * OperationAnnouncementsTests.swift
 * FileCraftTests
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
import Testing
@testable import FileCraft

internal struct OperationAnnouncementsTests {

  // MARK: - Tests

  @Test
  internal func `A completed operation is announced once`() {
    var announcements = OperationAnnouncements()
    let operation = progress(.completed)

    let first = announcements.evaluate([operation])
    let second = announcements.evaluate([operation])

    #expect(first == [String(localized: "File operation finished.")])
    #expect(second.isEmpty)
  }

  @Test
  internal func `A failed operation names the number of errors`() {
    var announcements = OperationAnnouncements()
    var operation = progress(.failed)
    operation.errors = [
      FileOperationError(url: URL(filePath: "/a"), reason: "locked"),
      FileOperationError(url: URL(filePath: "/b"), reason: "locked"),
    ]

    let messages = announcements.evaluate([operation])

    #expect(messages == [String(localized: "File operation finished with \(2) errors.")])
  }

  @Test
  internal func `A cancelled operation is announced`() {
    var announcements = OperationAnnouncements()

    let messages = announcements.evaluate([progress(.cancelled)])

    #expect(messages == [String(localized: "File operation cancelled.")])
  }

  @Test
  internal func `Running and paused operations are not announced`() {
    var announcements = OperationAnnouncements()

    let messages = announcements.evaluate([progress(.running), progress(.paused), progress(.queued), progress(.preparing)])

    #expect(messages.isEmpty)
  }

  @Test
  internal func `Several operations that finish together are announced in order`() {
    var announcements = OperationAnnouncements()
    let first = progress(.completed)
    let second = progress(.cancelled)

    let messages = announcements.evaluate([first, second])

    #expect(messages == [String(localized: "File operation finished."), String(localized: "File operation cancelled.")])
  }

  // MARK: - Helpers

  private func progress(_ state: FileOperationState) -> FileOperationProgress {
    var progress = FileOperationProgress(
      id: UUID(), kind: .copy, sources: [URL(filePath: "/a")], destination: URL(filePath: "/b"))
    progress.state = state
    return progress
  }
}

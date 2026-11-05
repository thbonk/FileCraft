/*
 * OperationsWindowTriggersTests.swift
 * FileCraftTests
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
import Testing
@testable import FileCraft

internal struct OperationsWindowTriggersTests {

  // MARK: - Tests

  @Test
  internal func `A question opens the window once`() {
    var triggers = OperationsWindowTriggers()
    var operation = progress(.running)
    operation.question = OperationQuestion(topic: .failure(item: URL(filePath: "/a"), reason: "r", isPermissionError: false))

    let first = triggers.evaluate([operation], now: .now, opensAutomatically: false, isWindowVisible: true)
    let second = triggers.evaluate([operation], now: .now, opensAutomatically: false, isWindowVisible: true)

    #expect(first.presentsWindow)
    #expect(second.presentsWindow == false)
  }

  @Test
  internal func `An operation that finished with errors asks for its summary once`() {
    var triggers = OperationsWindowTriggers()
    let operation = progress(.failed)

    let first = triggers.evaluate([operation], now: .now, opensAutomatically: false, isWindowVisible: false)
    let second = triggers.evaluate([operation], now: .now, opensAutomatically: false, isWindowVisible: false)

    #expect(first == OperationsWindowTriggers.Outcome(presentsWindow: true, summaries: [operation.id]))
    #expect(second == OperationsWindowTriggers.Outcome())
  }

  @Test
  internal func `A long operation opens the window after five seconds when the setting is on`() {
    var triggers = OperationsWindowTriggers()
    let start = Date(timeIntervalSince1970: 1_000)
    var operation = progress(.running)
    operation.startDate = start

    let early = triggers.evaluate([operation], now: start + 4, opensAutomatically: true, isWindowVisible: false)
    let late = triggers.evaluate([operation], now: start + 6, opensAutomatically: true, isWindowVisible: false)
    let again = triggers.evaluate([operation], now: start + 7, opensAutomatically: true, isWindowVisible: false)

    #expect(early.presentsWindow == false)
    #expect(late.presentsWindow)
    #expect(again.presentsWindow == false)
  }

  @Test
  internal func `A long operation does not open the window when the setting is off or the window shows it`() {
    var settingOff = OperationsWindowTriggers()
    var windowVisible = OperationsWindowTriggers()
    let start = Date(timeIntervalSince1970: 1_000)
    var operation = progress(.running)
    operation.startDate = start

    let off = settingOff.evaluate([operation], now: start + 6, opensAutomatically: false, isWindowVisible: false)
    let visible = windowVisible.evaluate([operation], now: start + 6, opensAutomatically: true, isWindowVisible: true)
    // The visible window already showed the operation, so closing it does not bring it back.
    let afterClosing = windowVisible.evaluate([operation], now: start + 8, opensAutomatically: true, isWindowVisible: false)

    #expect(off.presentsWindow == false)
    #expect(visible.presentsWindow == false)
    #expect(afterClosing.presentsWindow == false)
  }

  // MARK: - Helpers

  private func progress(_ state: FileOperationState) -> FileOperationProgress {
    var progress = FileOperationProgress(
      id: UUID(), kind: .copy, sources: [URL(filePath: "/a")], destination: URL(filePath: "/b"))
    progress.state = state
    return progress
  }
}

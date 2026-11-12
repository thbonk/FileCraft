/*
 * DirectoryWatcherTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-10-30.
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

internal struct DirectoryWatcherTests {

  // MARK: - Tests

  @Test
  internal func `New file is reported within one second`() async throws {
    let directory = try TemporaryDirectory()
    let changes = DirectoryWatcher.changes(in: directory.url)
    let clock = ContinuousClock()
    let start = clock.now

    try directory.createFile("report.pdf", contents: "%PDF")
    let change = await firstChange(in: changes, timeout: .seconds(10)) { $0.changedNames.contains("report.pdf") }

    #expect(change != nil)
    // Shared CI machines deliver file system events late, so the spec's one second is checked on a Mac in use only.
    if TestEnvironment.isCI == false {
      #expect(clock.now - start < .seconds(1))
    }
  }

  @Test
  internal func `Changes deeper inside the folder are ignored`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("Nested")
    let changes = DirectoryWatcher.changes(in: directory.url)

    try directory.createFile("Nested/deep.txt")
    try directory.createFile("top.txt")
    let change = await firstChange(in: changes, timeout: .seconds(3)) { $0.changedNames.isEmpty == false }

    #expect(change?.changedNames.contains("deep.txt") == false)
  }

  // MARK: - Helpers

  /// Returns the first change matching `predicate`, or nil when none arrives within `timeout`.
  private func firstChange(
    in changes: AsyncStream<DirectoryChange>,
    timeout: Duration,
    where predicate: @escaping @Sendable (DirectoryChange) -> Bool
  ) async -> DirectoryChange? {
    await withTaskGroup(of: DirectoryChange?.self) { group in
      group.addTask {
        for await change in changes where predicate(change) {
          return change
        }
        return nil
      }
      group.addTask {
        try? await Task.sleep(for: timeout)
        return nil
      }
      let first = await group.next() ?? nil
      group.cancelAll()
      return first
    }
  }
}

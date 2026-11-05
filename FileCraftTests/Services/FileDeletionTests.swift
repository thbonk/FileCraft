/*
 * FileDeletionTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-11-04.
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

import Darwin
import Foundation
import Testing
@testable import FileCraft

/// Deletions without the Trash, as Delete Immediately and Empty Trash run them, on temporary folders.
@Suite(.timeLimit(.minutes(1)))
internal struct FileDeletionTests {

  // MARK: - Tests

  @Test
  internal func `Deleting a folder removes its contents but never what a link inside points to`() async throws {
    let directory = try TemporaryDirectory()
    let outside = try directory.createFile("outside.txt", contents: "o")
    let folder = try directory.createFolder("Folder")
    try directory.createFolder("Folder/Sub")
    try directory.createFile("Folder/Sub/a.txt", contents: "a")
    try FileManager.default.createSymbolicLink(
      atPath: folder.appending(path: "link").path(percentEncoded: false), withDestinationPath: outside.path(percentEncoded: false))
    let engine = FileOperationEngine()

    let id = await engine.enqueue(FileOperationRequest(kind: .delete, sources: [folder], destination: directory.url))
    let result = try #require(await engine.waitUntilFinished(id))

    #expect(result.state == .completed)
    #expect(FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) == false)
    #expect(try String(contentsOf: outside, encoding: .utf8) == "o")
    // Folder, Sub, a.txt and the link.
    #expect(result.totalItems == 4)
    #expect(result.processedItems == 4)
  }

  @Test
  internal func `A locked item that is skipped keeps its folder and is listed`() throws {
    let directory = try TemporaryDirectory()
    let folder = try directory.createFolder("Folder")
    try directory.createFile("Folder/open.txt")
    let locked = try directory.createFile("Folder/locked.txt")
    let lockedPath = locked.path(percentEncoded: false)
    #expect(chflags(lockedPath, UInt32(UF_IMMUTABLE)) == 0)
    defer {
      // Unlocked again, so that the temporary folder can go.
      chflags(lockedPath, 0)
    }
    let control = OperationControl()
    let request = FileOperationRequest(kind: .delete, sources: [folder], destination: directory.url)

    FileOperationWorker.perform(request, totals: [], control: control, ask: { _ in .failure(.skip, appliesToAll: false) })

    #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)) == ["locked.txt"])
    #expect(control.snapshot.errors.map(\.url.comparablePath) == [locked.comparablePath])
  }
}

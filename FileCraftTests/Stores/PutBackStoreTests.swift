/*
 * PutBackStoreTests.swift
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

import Foundation
import Testing
@testable import FileCraft

/// Each test writes its store into a temporary folder.
internal struct PutBackStoreTests {

  // MARK: - Tests

  @Test
  internal func `Records survive a relaunch and are forgotten after Put Back`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("Trash")
    let trashed = try directory.createFile("Trash/a.txt")
    let original = directory.url.appending(path: "Documents/a.txt")
    let fileURL = directory.url.appending(path: "PutBack.json")
    let store = PutBackStore(storage: JSONFileStorage(fileURL: fileURL))
    await store.loadIfNeeded()

    store.record([ItemMove(from: original, to: trashed)])
    await store.waitForPendingWrites()
    let relaunched = PutBackStore(storage: JSONFileStorage(fileURL: fileURL))
    await relaunched.loadIfNeeded()
    let restored = relaunched.originalLocation(of: trashed)
    relaunched.remove(trashed: [trashed])

    #expect(restored?.comparablePath == original.comparablePath)
    #expect(relaunched.originalLocation(of: trashed) == nil)
  }

  @Test
  internal func `Records of items that left the Trash are dropped`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("Trash")
    let kept = try directory.createFile("Trash/kept.txt")
    let emptied = try directory.createFile("Trash/emptied.txt")
    let store = PutBackStore(storage: JSONFileStorage(fileURL: directory.url.appending(path: "PutBack.json")))
    await store.loadIfNeeded()
    store.record([
      ItemMove(from: directory.url.appending(path: "kept.txt"), to: kept),
      ItemMove(from: directory.url.appending(path: "emptied.txt"), to: emptied),
    ])

    try FileManager.default.removeItem(at: emptied)
    await store.removeMissingItems()

    #expect(store.originalLocation(of: kept) != nil)
    #expect(store.originalLocation(of: emptied) == nil)
  }
}

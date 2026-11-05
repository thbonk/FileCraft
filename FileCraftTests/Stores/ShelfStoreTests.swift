/*
 * ShelfStoreTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-11-05.
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

/// Each test uses its own shelf file in a temporary directory.
internal struct ShelfStoreTests {

  // MARK: - Tests

  @Test
  internal func `Adding stores references, skips items on the shelf and survives a relaunch`() async throws {
    let directory = try TemporaryDirectory()
    let report = try directory.createFile("Report.pdf")
    let photos = try directory.createFolder("Photos")
    let missing = directory.url.appending(path: "Missing.txt")
    let store = try await loadedStore(in: directory)

    await store.add([report, photos, missing])
    await store.add([URL(filePath: report.comparablePath)])
    await store.waitForPendingWrites()
    let relaunched = try await loadedStore(in: directory)

    #expect(store.items.map(\.url.lastPathComponent) == ["Report.pdf", "Photos"])
    #expect(relaunched.items.map(\.url.lastPathComponent) == ["Report.pdf", "Photos"])
    #expect(FileManager.default.fileExists(atPath: report.path(percentEncoded: false)))
  }

  @Test
  internal func `A renamed item gets its new path and a deleted one becomes unavailable`() async throws {
    let directory = try TemporaryDirectory()
    let draft = try directory.createFile("Draft.txt")
    let old = try directory.createFile("Old.txt")
    let store = try await loadedStore(in: directory)
    await store.add([draft, old])

    try FileManager.default.moveItem(at: draft, to: directory.url.appending(path: "Final.txt"))
    try FileManager.default.removeItem(at: old)
    await store.refresh()

    let renamed = try #require(store.items.first)
    let deleted = try #require(store.items.last)
    #expect(renamed.url.lastPathComponent == "Final.txt")
    #expect(store.unavailableIDs == [deleted.id])
  }

  @Test
  internal func `Remove from Shelf, removing dragged items and Clear Shelf are stored`() async throws {
    let directory = try TemporaryDirectory()
    let files = try ["a.txt", "b.txt", "c.txt"].map { try directory.createFile($0) }
    let store = try await loadedStore(in: directory)
    await store.add(files)

    store.remove([try #require(store.items.first).id])
    store.remove(itemsAt: [URL(filePath: files[1].path(percentEncoded: false))])
    let remaining = store.items.map(\.url.lastPathComponent)
    await store.waitForPendingWrites()
    let relaunched = try await loadedStore(in: directory)
    relaunched.clear()
    await relaunched.waitForPendingWrites()
    let cleared = try await loadedStore(in: directory)

    #expect(remaining == ["c.txt"])
    #expect(relaunched.items.isEmpty)
    #expect(cleared.items.isEmpty)
  }

  @Test
  internal func `Relocating points items to places their bookmarks cannot find`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("Source")
    let original = try directory.createFile("Source/Notes.txt", contents: "notes")
    let store = try await loadedStore(in: directory)
    await store.add([original])

    // A move to another volume copies the item and deletes the original, so its bookmark finds nothing.
    try directory.createFolder("Other")
    let copy = directory.url.appending(path: "Other/Notes.txt")
    try FileManager.default.copyItem(at: original, to: copy)
    try FileManager.default.removeItem(at: original)
    await store.relocate([ItemMove(from: original, to: copy)])
    await store.refresh()

    #expect(store.items.map(\.url.comparablePath) == [copy.comparablePath])
    #expect(store.unavailableIDs.isEmpty)
  }

  // MARK: - Helpers

  private func loadedStore(in directory: TemporaryDirectory) async throws -> ShelfStore {
    let store = ShelfStore(storage: JSONFileStorage(fileURL: directory.url.appending(path: "Shelf.json")))
    await store.loadIfNeeded()
    return store
  }
}

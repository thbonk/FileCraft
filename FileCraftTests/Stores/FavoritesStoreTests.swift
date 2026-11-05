/*
 * FavoritesStoreTests.swift
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

/// Each test uses its own store file and default folders in a temporary directory.
internal struct FavoritesStoreTests {

  // MARK: - Tests

  @Test
  internal func `A new store starts with the default folders that exist`() async throws {
    let directory = try TemporaryDirectory()
    let home = try directory.createFolder("Home")
    let documents = try directory.createFolder("Documents")
    let missing = directory.url.appending(path: "Missing", directoryHint: .isDirectory)

    let store = try await loadedStore(in: directory, defaults: [home, documents, missing])
    await store.waitForPendingWrites()

    #expect(store.favorites.map(\.url.lastPathComponent) == ["Home", "Documents"])
    #expect(FileManager.default.fileExists(atPath: storeURL(in: directory).path(percentEncoded: false)))
  }

  @Test
  internal func `Adding appends new items, skips favorites and inserts at a drop position`() async throws {
    let directory = try TemporaryDirectory()
    let home = try directory.createFolder("Home")
    let projects = try directory.createFolder("Projects")
    let notes = try directory.createFile("Notes.txt")
    let store = try await loadedStore(in: directory, defaults: [home])

    await store.add([projects, home])
    await store.add([URL(filePath: projects.comparablePath)])
    await store.add([notes], at: 0)

    #expect(store.favorites.map(\.url.lastPathComponent) == ["Notes.txt", "Home", "Projects"])
  }

  @Test
  internal func `Favorites can be reordered and removed, and the order survives a restart`() async throws {
    let directory = try TemporaryDirectory()
    let folders = try ["A", "B", "C"].map { try directory.createFolder($0) }
    let store = try await loadedStore(in: directory, defaults: folders)

    store.move(fromOffsets: [2], toOffset: 0)
    let reordered = store.favorites.map(\.url.lastPathComponent)
    store.remove(try #require(store.favorites.last).id)
    await store.waitForPendingWrites()
    let restored = try await loadedStore(in: directory, defaults: [])

    #expect(reordered == ["C", "A", "B"])
    #expect(restored.favorites.map(\.url.lastPathComponent) == ["C", "A"])
  }

  @Test
  internal func `A renamed favorite shows its new name and a deleted one becomes unavailable`() async throws {
    let directory = try TemporaryDirectory()
    let projects = try directory.createFolder("Projects")
    let archive = try directory.createFolder("Archive")
    let store = try await loadedStore(in: directory, defaults: [projects, archive])

    try FileManager.default.moveItem(at: projects, to: directory.url.appending(path: "Work"))
    try FileManager.default.removeItem(at: archive)
    await store.refresh()
    await store.waitForPendingWrites()

    let work = try #require(store.favorites.first)
    let removed = try #require(store.favorites.last)
    #expect(work.url.lastPathComponent == "Work")
    #expect(store.unavailableIDs == [removed.id])
  }

  @Test
  internal func `Opening a favorite resolves it to a folder, a file or unavailable`() async throws {
    let directory = try TemporaryDirectory()
    let folder = try directory.createFolder("Folder")
    let file = try directory.createFile("File.txt")
    let gone = try directory.createFolder("Gone")
    let store = try await loadedStore(in: directory, defaults: [folder, file, gone])
    try FileManager.default.removeItem(at: gone)
    let ids = store.favorites.map(\.id)

    let folderTarget = await store.target(of: ids[0])
    let fileTarget = await store.target(of: ids[1])
    let goneTarget = await store.target(of: ids[2])
    await store.waitForPendingWrites()

    guard case .folder(let reference) = folderTarget else {
      Issue.record("Expected a folder, got \(folderTarget)")
      return
    }
    #expect(reference.lastKnownURL.lastPathComponent == "Folder")
    #expect(fileTarget == .file(store.favorites[1].url))
    #expect(goneTarget == .unavailable)
    #expect(store.unavailableIDs == [ids[2]])
  }

  // MARK: - Helpers

  private func storeURL(in directory: TemporaryDirectory) -> URL {
    directory.url.appending(path: "Favorites.json")
  }

  private func loadedStore(in directory: TemporaryDirectory, defaults: [URL]) async throws -> FavoritesStore {
    let store = FavoritesStore(storage: JSONFileStorage(fileURL: storeURL(in: directory)), defaultFolders: defaults)
    await store.loadIfNeeded()
    return store
  }
}

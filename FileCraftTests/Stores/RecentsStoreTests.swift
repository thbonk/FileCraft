/*
 * RecentsStoreTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-10-31.
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

/// Each test uses its own store file in a temporary folder and waits for pending writes before the folder goes away.
internal struct RecentsStoreTests {

  // MARK: - Tests

  @Test
  internal func `Recording keeps the 15 most recent folders, newest first, without duplicates`() async throws {
    let directory = try TemporaryDirectory()
    let store = try await loadedStore(in: directory)

    for index in 1...20 {
      store.recordVisit(to: folder("/tmp/f\(index)"))
    }
    store.recordVisit(to: folder("/tmp/f10"))
    await store.waitForPendingWrites()

    let paths = store.folders.map(\.lastKnownPath)
    #expect(paths.count == RecentsStore.folderLimit)
    #expect(paths.prefix(3) == ["/tmp/f10", "/tmp/f20", "/tmp/f19"])
    #expect(paths.filter { $0 == "/tmp/f10" }.count == 1)
  }

  @Test
  internal func `Recent folders survive a restart and Clear Menu removes them`() async throws {
    let directory = try TemporaryDirectory()
    let first = try await loadedStore(in: directory)
    first.recordVisit(to: folder("/tmp/a"))
    first.recordVisit(to: folder("/tmp/b"))
    await first.waitForPendingWrites()

    let second = try await loadedStore(in: directory)
    let restoredPaths = second.folders.map(\.lastKnownPath)
    second.clear()
    await second.waitForPendingWrites()
    let third = try await loadedStore(in: directory)

    #expect(restoredPaths == ["/tmp/b", "/tmp/a"])
    #expect(second.folders.isEmpty)
    #expect(third.folders.isEmpty)
  }

  @Test
  internal func `Folders recorded before loading come first and are saved`() async throws {
    let directory = try TemporaryDirectory()
    let first = try await loadedStore(in: directory)
    first.recordVisit(to: folder("/tmp/old"))
    await first.waitForPendingWrites()

    let second = RecentsStore(storage: storage(in: directory))
    second.recordVisit(to: folder("/tmp/new"))
    await second.loadIfNeeded()
    await second.waitForPendingWrites()
    let third = try await loadedStore(in: directory)

    #expect(second.folders.map(\.lastKnownPath) == ["/tmp/new", "/tmp/old"])
    #expect(third.folders.map(\.lastKnownPath) == ["/tmp/new", "/tmp/old"])
  }

  @Test
  internal func `A folder with and without trailing slash is one entry`() async throws {
    let directory = try TemporaryDirectory()
    let store = try await loadedStore(in: directory)

    store.recordVisit(to: folder("/tmp/a"))
    store.recordVisit(to: FileReference(unresolvedURL: URL(filePath: "/tmp/a", directoryHint: .isDirectory)))
    await store.waitForPendingWrites()

    #expect(store.folders.count == 1)
  }

  @Test
  internal func `Go to Folder keeps its 10 latest entries exactly as typed`() async throws {
    let directory = try TemporaryDirectory()
    let store = try await loadedStore(in: directory)

    for index in 1...12 {
      store.recordGoToFolderEntry("~/Folder \(index)")
    }
    store.recordGoToFolderEntry("~/Folder 5")
    await store.waitForPendingWrites()
    let restored = try await loadedStore(in: directory)

    #expect(store.goToFolderEntries.count == RecentsStore.goToFolderEntryLimit)
    #expect(store.goToFolderEntries.prefix(2) == ["~/Folder 5", "~/Folder 12"])
    #expect(restored.goToFolderEntries == store.goToFolderEntries)
  }

  @Test
  internal func `A store file without Go to Folder entries still loads its folders`() async throws {
    let directory = try TemporaryDirectory()
    let contents = #"{"version": 1, "folders": [{"bookmarkData": "", "lastKnownPath": "/tmp/a"}]}"#
    try directory.createFile("Recents.json", contents: contents)

    let store = try await loadedStore(in: directory)

    #expect(store.folders.map(\.lastKnownPath) == ["/tmp/a"])
    #expect(store.goToFolderEntries.isEmpty)
  }

  @Test
  internal func `A store file of another version is ignored`() async throws {
    let directory = try TemporaryDirectory()
    let contents = #"{"version": 2, "folders": [{"bookmarkData": "", "lastKnownPath": "/tmp/a"}]}"#
    try directory.createFile("Recents.json", contents: contents)

    let store = try await loadedStore(in: directory)

    #expect(store.folders.isEmpty)
  }

  // MARK: - Recent Searches

  @Test
  internal func `Recent searches are kept without duplicates, newest first, and persist`() async throws {
    let directory = try TemporaryDirectory()
    let store = try await loadedStore(in: directory)
    let pdfs = SearchCriterion(attribute: .kind, kind: .pdf)

    store.recordSearch(SearchParameters(scope: .subfolders, text: "README"))
    store.recordSearch(SearchParameters(scope: .thisMac, text: "Invoice", criteria: [pdfs]))
    // The same search with a new criterion row counts as a duplicate.
    store.recordSearch(SearchParameters(scope: .subfolders, text: "README"))
    store.recordSearch(SearchParameters(scope: .thisMac, text: "Invoice", criteria: [SearchCriterion(attribute: .kind, kind: .pdf)]))
    await store.waitForPendingWrites()

    #expect(store.searches.map(\.text) == ["Invoice", "README"])
    let reloaded = try await loadedStore(in: directory)
    #expect(reloaded.searches.map(\.text) == ["Invoice", "README"])
    #expect(reloaded.searches.first?.criteria.first?.kind == .pdf)
  }

  @Test
  internal func `At most ten recent searches are kept and they can be cleared`() async throws {
    let store = try await loadedStore(in: try TemporaryDirectory())

    for index in 0..<12 {
      store.recordSearch(SearchParameters(scope: .thisMac, text: "search \(index)"))
    }
    #expect(store.searches.count == RecentsStore.searchLimit)
    #expect(store.searches.first?.text == "search 11")

    store.clearSearches()
    #expect(store.searches.isEmpty)
  }

  // MARK: - Helpers

  private func storage(in directory: TemporaryDirectory) -> JSONFileStorage {
    JSONFileStorage(fileURL: directory.url.appending(path: "Recents.json"))
  }

  private func loadedStore(in directory: TemporaryDirectory) async throws -> RecentsStore {
    let store = RecentsStore(storage: storage(in: directory))
    await store.loadIfNeeded()
    return store
  }

  private func folder(_ path: String) -> FileReference {
    FileReference(unresolvedURL: URL(filePath: path))
  }
}

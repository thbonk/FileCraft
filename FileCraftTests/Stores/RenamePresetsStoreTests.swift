/*
 * RenamePresetsStoreTests.swift
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

internal struct RenamePresetsStoreTests {

  @Test
  internal func `Presets persist, replace presets of the same name and can be deleted`() async throws {
    let directory = try TemporaryDirectory()
    let store = try await loadedStore(in: directory)
    var prefix = RenameRule(kind: .insertText)
    prefix.insertText = "Trip_"

    store.save([prefix], as: "Photo export")
    store.save([RenameRule(kind: .changeCase)], as: "Lowercase")
    store.save([prefix, RenameRule(kind: .sequenceNumber)], as: "photo EXPORT")
    await store.waitForPendingWrites()

    let reloaded = try await loadedStore(in: directory)
    #expect(reloaded.presets.map(\.name) == ["Lowercase", "photo EXPORT"])
    #expect(reloaded.presets.last?.rules.first?.insertText == "Trip_")

    reloaded.delete(reloaded.presets[0])
    await reloaded.waitForPendingWrites()
    #expect(try await loadedStore(in: directory).presets.map(\.name) == ["photo EXPORT"])
  }

  @Test
  internal func `Presets without a name are not saved`() async throws {
    let store = try await loadedStore(in: try TemporaryDirectory())

    store.save([RenameRule(kind: .changeCase)], as: "  ")

    #expect(store.presets.isEmpty)
  }

  private func loadedStore(in directory: TemporaryDirectory) async throws -> RenamePresetsStore {
    let store = RenamePresetsStore(storage: JSONFileStorage(fileURL: directory.url.appending(path: "RenamePresets.json")))
    await store.loadIfNeeded()
    return store
  }
}

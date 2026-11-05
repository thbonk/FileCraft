/*
 * FileSystemServiceTests.swift
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

internal struct FileSystemServiceTests {

  // MARK: - Properties

  private let directory: TemporaryDirectory
  private let service = FileSystemService()

  // MARK: - Initialization

  internal init() throws {
    directory = try TemporaryDirectory()
    try directory.createFile("notes.txt", contents: "hello")
    try directory.createFile(".secret")
    try directory.createFolder("Projects")
    try directory.createFolder("Plugin.bundle")
  }

  // MARK: - Tests

  @Test
  internal func `Listing skips hidden items unless requested`() async throws {
    let visible = try await service.contentsOfDirectory(at: directory.url, includingHiddenItems: false)
    let all = try await service.contentsOfDirectory(at: directory.url, includingHiddenItems: true)

    #expect(Set(visible.map(\.name)) == ["notes.txt", "Projects", "Plugin.bundle"])
    #expect(Set(all.map(\.name)) == ["notes.txt", "Projects", "Plugin.bundle", ".secret"])
  }

  @Test
  internal func `Items carry kind, size and flags`() async throws {
    let items = try await service.contentsOfDirectory(at: directory.url, includingHiddenItems: true)
    let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0) })

    let notes = try #require(byName["notes.txt"])
    #expect(notes.size == 5)
    #expect(notes.isDirectory == false)
    #expect(notes.kind.isEmpty == false)
    #expect(notes.modificationDate != nil)
    #expect(notes.permissions != nil)

    let projects = try #require(byName["Projects"])
    #expect(projects.isDirectory)
    #expect(projects.isPackage == false)
    #expect(projects.size == nil)

    #expect(byName["Plugin.bundle"]?.isPackage == true)
    #expect(byName[".secret"]?.isHidden == true)
  }

  @Test
  internal func `Items report their tags`() async throws {
    let tagged = try directory.createFile("tagged.txt")
    try (tagged as NSURL).setResourceValue(["Work"], forKey: .tagNamesKey)

    let item = try await service.item(at: tagged)

    #expect(item.tagNames == ["Work"])
  }

  @Test
  internal func `Listing a missing folder throws`() async {
    let missing = directory.url.appending(path: "missing", directoryHint: .isDirectory)

    await #expect(throws: (any Error).self) {
      try await service.contentsOfDirectory(at: missing, includingHiddenItems: false)
    }
  }
}

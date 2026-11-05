/*
 * FileReferenceTests.swift
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

internal struct FileReferenceTests {

  // MARK: - Properties

  private let directory: TemporaryDirectory

  // MARK: - Initialization

  internal init() throws {
    directory = try TemporaryDirectory()
  }

  // MARK: - Tests

  @Test
  internal func `Reference follows a renamed file`() throws {
    let original = try directory.createFile("draft.txt")
    var reference = try FileReference(url: original)
    let renamed = directory.url.appending(path: "final.txt")
    try FileManager.default.moveItem(at: original, to: renamed)

    let url = try reference.refresh()

    #expect(url.lastPathComponent == "final.txt")
    #expect(reference.lastKnownPath == renamed.path(percentEncoded: false))
  }

  @Test
  internal func `Reference follows a folder moved into another folder`() throws {
    let projects = try directory.createFolder("Projects")
    let archive = try directory.createFolder("Archive")
    var reference = try FileReference(url: projects)
    try FileManager.default.moveItem(at: projects, to: archive.appending(path: "Projects"))

    let url = try reference.refresh()

    #expect(url.deletingLastPathComponent().lastPathComponent == "Archive")
  }

  @Test
  internal func `Reference survives encoding and decoding`() throws {
    let file = try directory.createFile("notes.txt")
    let reference = try FileReference(url: file)

    let decoded = try JSONDecoder().decode(FileReference.self, from: JSONEncoder().encode(reference))

    #expect(decoded == reference)
    #expect(try decoded.resolve().url.lastPathComponent == "notes.txt")
  }
}

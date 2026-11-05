/*
 * ItemCreatorTests.swift
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

/// Names come from `UniqueNameGenerator` in the app's language, which is the host app's language in tests.
internal struct ItemCreatorTests {

  // MARK: - Tests

  @Test
  internal func `New folders get the localized default name and then the next free number`() async throws {
    let directory = try TemporaryDirectory()
    let names = UniqueNameGenerator()
    let creator = ItemCreator()

    let first = try await creator.makeFolder(in: directory.url)
    let second = try await creator.makeFolder(in: directory.url)

    #expect(first.lastPathComponent == names.untitledFolderName(existingNames: []))
    #expect(second.lastPathComponent == names.untitledFolderName(existingNames: [first.lastPathComponent]))
    #expect(FileCopier.isDirectory(first) && FileCopier.isDirectory(second))
  }

  @Test
  internal func `A new text file is empty and never replaces an existing file`() async throws {
    let directory = try TemporaryDirectory()
    let names = UniqueNameGenerator()
    let existingName = names.untitledTextFileName(existingNames: [])
    try directory.createFile(existingName, contents: "keep")

    let file = try await ItemCreator().makeTextFile(in: directory.url)

    #expect(file.lastPathComponent == names.untitledTextFileName(existingNames: [existingName]))
    #expect(try Data(contentsOf: file).isEmpty)
    #expect(try String(contentsOf: directory.url.appending(path: existingName), encoding: .utf8) == "keep")
  }

  @Test
  internal func `An alias is a Finder alias of its original, next to it`() async throws {
    let directory = try TemporaryDirectory()
    let original = try directory.createFolder("Projects")

    let alias = try await ItemCreator().makeAlias(of: original)

    #expect(alias.lastPathComponent == UniqueNameGenerator().aliasName(of: "Projects", existingNames: []))
    #expect(try alias.resourceValues(forKeys: [.isAliasFileKey]).isAliasFile == true)
    #expect(try URL(resolvingAliasFileAt: alias).comparablePath == original.comparablePath)
  }

  @Test
  internal func `A symbolic link holds the absolute path of its original`() async throws {
    let directory = try TemporaryDirectory()
    let original = try directory.createFolder("Projects")

    let link = try await ItemCreator().makeSymbolicLink(to: original)

    let destination = try FileManager.default.destinationOfSymbolicLink(atPath: link.path(percentEncoded: false))
    #expect(link.lastPathComponent == UniqueNameGenerator().aliasName(of: "Projects", existingNames: []))
    #expect(destination == directory.url.appending(path: "Projects").path(percentEncoded: false))
  }
}

/*
 * SearchServiceTests.swift
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

internal struct SearchServiceTests {

  @Test
  internal func `A Subfolders search finds matches in all folders below`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("a/b")
    try directory.createFile("README.md")
    try directory.createFile("a/readme.txt")
    try directory.createFile("a/b/Readme")
    try directory.createFile("a/b/other.txt")

    let names = await search(in: directory, SearchParameters(scope: .subfolders, text: "readme"))

    #expect(names == ["README.md", "Readme", "readme.txt"])
  }

  @Test
  internal func `Hidden items and package contents are found only when included`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFile(".env")
    try directory.createFolder("Tool.app/Contents")
    try directory.createFile("Tool.app/Contents/env.plist")

    let defaults = await search(in: directory, SearchParameters(scope: .subfolders, text: "env"))
    let everything = await search(
      in: directory,
      SearchParameters(scope: .subfolders, text: "env", includesHiddenItems: true, includesPackageContents: true))

    #expect(defaults.isEmpty)
    #expect(everything == [".env", "env.plist"])
  }

  @Test
  internal func `A cancelled search stops`() async throws {
    let directory = try TemporaryDirectory()
    for index in 0..<50 {
      try directory.createFile("file \(index).txt")
    }
    let collector = BatchCollector()
    let task = Task {
      await SearchService().searchSubfolders(
        of: directory.url,
        parameters: SearchParameters(scope: .subfolders, text: "file"),
        matcher: SearchMatcher(parameters: SearchParameters(scope: .subfolders, text: "file"))
      ) { batch in
        collector.append(batch)
      }
    }
    task.cancel()
    await task.value

    #expect(collector.names.count < 50)
  }

  // MARK: - Helpers

  private func search(in directory: TemporaryDirectory, _ parameters: SearchParameters) async -> [String] {
    let collector = BatchCollector()
    await SearchService().searchSubfolders(of: directory.url, parameters: parameters, matcher: SearchMatcher(parameters: parameters)) {
      batch in
      collector.append(batch)
    }
    return collector.names.sorted()
  }
}

/// Collects the batches a search hands over on the main actor.
private final class BatchCollector {
  private(set) var names: [String] = []

  func append(_ batch: [FileItem]) {
    names += batch.map(\.name)
  }
}

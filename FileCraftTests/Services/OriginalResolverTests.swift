/*
 * OriginalResolverTests.swift
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

internal struct OriginalResolverTests {

  // MARK: - Tests

  @Test
  internal func `Symbolic links resolve to their target, relative ones from the link's folder`() async throws {
    let directory = try TemporaryDirectory()
    let target = try directory.createFile("bin/tool-target", inNewFolder: "bin")
    let absoluteLink = directory.url.appending(path: "absolute")
    let relativeLink = directory.url.appending(path: "bin/relative")
    try FileManager.default.createSymbolicLink(at: absoluteLink, withDestinationURL: target)
    try FileManager.default.createSymbolicLink(atPath: relativeLink.path(percentEncoded: false), withDestinationPath: "tool-target")

    let absolute = await OriginalResolver.original(of: try await item(at: absoluteLink))
    let relative = await OriginalResolver.original(of: try await item(at: relativeLink))

    #expect(path(of: absolute) == target.path(percentEncoded: false))
    #expect(path(of: relative) == target.path(percentEncoded: false))
  }

  @Test
  internal func `Aliases resolve to their original`() async throws {
    let directory = try TemporaryDirectory()
    let target = try directory.createFile("Report.txt", contents: "x")
    let alias = directory.url.appending(path: "Report alias")
    let bookmark = try target.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
    try URL.writeBookmarkData(bookmark, to: alias)

    let aliasItem = try await item(at: alias)
    let resolution = await OriginalResolver.original(of: aliasItem)

    #expect(aliasItem.isAliasFile)
    #expect(path(of: resolution) == target.path(percentEncoded: false))
  }

  @Test
  internal func `Links to missing items are broken and other items have no original`() async throws {
    let directory = try TemporaryDirectory()
    let link = directory.url.appending(path: "dangling")
    try FileManager.default.createSymbolicLink(atPath: link.path(percentEncoded: false), withDestinationPath: "missing")
    let plainFile = try directory.createFile("plain.txt")

    let broken = await OriginalResolver.original(of: try await item(at: link))
    let none = await OriginalResolver.original(of: try await item(at: plainFile))

    #expect(broken == .broken)
    #expect(none == nil)
  }

  // MARK: - Helpers

  private func item(at url: URL) async throws -> FileItem {
    try await FileSystemService().item(at: url)
  }

  private func path(of resolution: OriginalResolution?) -> String? {
    guard case .original(let url) = resolution else {
      return nil
    }
    return url.path(percentEncoded: false)
  }
}

extension TemporaryDirectory {
  /// Creates `folder` and then the file at `relativePath` inside the temporary directory.
  fileprivate func createFile(_ relativePath: String, inNewFolder folder: String) throws -> URL {
    try createFolder(folder)
    return try createFile(relativePath)
  }
}

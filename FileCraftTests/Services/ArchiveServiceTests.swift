/*
 * ArchiveServiceTests.swift
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

/// Compress and Expand through the Operations engine, with the archive tools of macOS, on temporary folders.
@Suite(.timeLimit(.minutes(1)))
internal struct ArchiveServiceTests {

  // MARK: - Tests

  @Test(arguments: CompressionFormat.allCases)
  internal func `A compressed folder expands to the same contents`(format: CompressionFormat) async throws {
    let directory = try TemporaryDirectory()
    let folder = try directory.createFolder("Photos")
    try directory.createFile("Photos/a.txt", contents: "a")
    try directory.createFolder("Photos/Sub")
    try directory.createFile("Photos/Sub/b.txt", contents: "bb")
    let target = try directory.createFolder("Target")

    let archive = try #require(try await run(.compress, [folder], into: directory.url, format: format).results.first)
    let expanded = try await run(.expand, [archive], into: target).results

    #expect(archive.lastPathComponent == "Photos." + ArchiveService.pathExtension(of: format))
    #expect(expanded.map(\.lastPathComponent) == ["Photos"])
    #expect(try String(contentsOf: target.appending(path: "Photos/Sub/b.txt"), encoding: .utf8) == "bb")
    #expect(try String(contentsOf: target.appending(path: "Photos/a.txt"), encoding: .utf8) == "a")
  }

  @Test(arguments: [CompressionFormat.zip, .tarGzip])
  internal func `Several items go into an archive named Archive, at its top level`(format: CompressionFormat) async throws {
    let directory = try TemporaryDirectory()
    let first = try directory.createFile("Desktop/a.txt", contents: "a", inNewFolder: true)
    let second = try directory.createFile("Desktop/b.txt", contents: "b")
    let target = try directory.createFolder("Target")
    let expectedName = UniqueNameGenerator().archiveName(
      forItemNamed: nil, pathExtension: ArchiveService.pathExtension(of: format), existingNames: [])

    let archive = try #require(try await run(.compress, [first, second], into: first.deletingLastPathComponent(), format: format).results.first)
    let expanded = try await run(.expand, [archive], into: target).results

    #expect(archive.lastPathComponent == expectedName)
    #expect(expanded.map(\.lastPathComponent).sorted() == ["a.txt", "b.txt"])
    #expect(try FileManager.default.contentsOfDirectory(atPath: target.path(percentEncoded: false)).sorted() == ["a.txt", "b.txt"])
  }

  @Test
  internal func `An expanded item takes a free name when its name exists`() async throws {
    let directory = try TemporaryDirectory()
    let folder = try directory.createFolder("photos")
    try directory.createFile("photos/a.jpg", contents: "jpg")
    let archive = try #require(try await run(.compress, [folder], into: directory.url, format: .zip).results.first)

    let expanded = try await run(.expand, [archive], into: directory.url).results

    #expect(expanded.map(\.lastPathComponent) == ["photos 2"])
    #expect(try String(contentsOf: directory.url.appending(path: "photos 2/a.jpg"), encoding: .utf8) == "jpg")
  }

  @Test
  internal func `A gzip file expands to the file it holds`() async throws {
    let directory = try TemporaryDirectory()
    let file = try directory.createFile("notes.txt", contents: "hello")
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/gzip")
    process.arguments = ["-k", file.path(percentEncoded: false)]
    try process.run()
    process.waitUntilExit()
    try FileManager.default.removeItem(at: file)
    let target = try directory.createFolder("Target")

    let expanded = try await run(.expand, [directory.url.appending(path: "notes.txt.gz")], into: target).results

    #expect(expanded.map(\.lastPathComponent) == ["notes.txt"])
    #expect(try String(contentsOf: target.appending(path: "notes.txt"), encoding: .utf8) == "hello")
  }

  @Test
  internal func `Archives are recognized by their names`() {
    #expect(ArchiveService.kind(of: URL(filePath: "/a/b.zip")) == .zip)
    #expect(ArchiveService.kind(of: URL(filePath: "/a/b.tar.gz")) == .tarGzip)
    #expect(ArchiveService.kind(of: URL(filePath: "/a/b.tgz")) == .tarGzip)
    #expect(ArchiveService.kind(of: URL(filePath: "/a/b.TAR.XZ")) == .tarXz)
    #expect(ArchiveService.kind(of: URL(filePath: "/a/b.tar.bz2")) == .tarBzip2)
    #expect(ArchiveService.kind(of: URL(filePath: "/a/b.tar")) == .tar)
    #expect(ArchiveService.kind(of: URL(filePath: "/a/b.gz")) == .gzip)
    #expect(ArchiveService.kind(of: URL(filePath: "/a/b.pdf")) == nil)
    #expect(ArchiveService.kind(of: URL(filePath: "/a/.zip")) == nil)
  }

  // MARK: - Helpers

  private func run(
    _ kind: FileOperationKind, _ sources: [URL], into destination: URL, format: CompressionFormat = .zip
  ) async throws -> FileOperationProgress {
    let engine = FileOperationEngine()
    let request = FileOperationRequest(kind: kind, sources: sources, destination: destination, archiveFormat: format)
    let id = await engine.enqueue(request)
    let result = try #require(await engine.waitUntilFinished(id))
    #expect(result.state == .completed, "\(result.errors)")
    return result
  }
}

extension TemporaryDirectory {

  /// Creates a file, and with `inNewFolder` its folder first.
  @discardableResult
  fileprivate func createFile(_ relativePath: String, contents: String, inNewFolder: Bool) throws -> URL {
    if inNewFolder {
      try createFolder((relativePath as NSString).deletingLastPathComponent)
    }
    return try createFile(relativePath, contents: contents)
  }
}

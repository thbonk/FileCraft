/*
 * HelperFileSystemTests.swift
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

import Darwin
import Foundation
import Testing
@testable import FileCraft

/// The helper's operations, run through its request handler in this process as the current user on temporary
/// folders. The helper itself is never started.
@Suite(.timeLimit(.minutes(1)))
internal struct HelperFileSystemTests {

  // MARK: - Properties

  private let handler = HelperRequestHandler(isAuthorized: { $0 != nil })
  private let authorization = Data(repeating: 1, count: 32)

  // MARK: - Commands

  @Test
  internal func `Folders are created, renamed without replacing anything, and listed`() throws {
    let directory = try TemporaryDirectory()
    try directory.createFile("taken", contents: "t")
    let folder = path(directory, "New")

    let created = send(.createFolder(path: folder))
    let refused = send(.rename(path: folder, newName: "taken"))
    let renamed = send(.rename(path: folder, newName: "Renamed"))
    let listing = send(.list(path: directory.url.path(percentEncoded: false)))

    #expect(created == .done)
    #expect(refused == .failure(.posix(EEXIST)))
    #expect(renamed == .done)
    guard case .listing(let items) = listing else {
      Issue.record("Expected a listing, got \(listing)")
      return
    }
    #expect(items.map(\.name).sorted() == ["Renamed", "taken"])
    #expect(items.first { $0.name == "Renamed" }?.isDirectory == true)
    #expect(items.first { $0.name == "taken" }?.size == 1)
  }

  @Test
  internal func `Mode, flags and owner change the item itself, never what a link points to`() throws {
    let directory = try TemporaryDirectory()
    let file = try directory.createFile("file.txt", contents: "f")
    try FileManager.default.createSymbolicLink(atPath: path(directory, "link"), withDestinationPath: file.path(percentEncoded: false))
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path(percentEncoded: false))

    let mode = send(.setMode(path: path(directory, "file.txt"), mode: 0o600))
    let linkMode = send(.setMode(path: path(directory, "link"), mode: 0o700))
    let locked = send(.setFlags(path: path(directory, "file.txt"), flags: UInt32(UF_IMMUTABLE)))
    let isLocked = try flags(of: file) & UInt32(UF_IMMUTABLE) != 0
    let unlocked = send(.setFlags(path: path(directory, "file.txt"), flags: 0))
    let owner = send(.setOwner(path: path(directory, "file.txt"), owner: getuid(), group: getgid()))

    #expect([mode, linkMode, locked, unlocked, owner] == [.done, .done, .done, .done, .done])
    #expect(try permissions(of: file) == 0o600)
    #expect(isLocked)
    #expect(try flags(of: file) & UInt32(UF_IMMUTABLE) == 0)
  }

  @Test
  internal func `Paths that are relative, contain dot-dot or lie in protected locations are refused`() {
    #expect(send(.createFolder(path: "relative/New")) == .failure(.invalidPath))
    #expect(send(.createFolder(path: "/tmp/../tmp/New")) == .failure(.invalidPath))
    #expect(send(.createFolder(path: "/tmp/./New")) == .failure(.invalidPath))
    #expect(send(.createFolder(path: "/System/Library/New")) == .failure(.protectedLocation))
    #expect(send(.createFolder(path: "/usr/bin/New")) == .failure(.protectedLocation))
    #expect(HelperFileSystem.isProtected("/usr/local/bin/tool") == false)
  }

  @Test
  internal func `Requests without a valid authorization change nothing`() throws {
    let directory = try TemporaryDirectory()
    let folder = path(directory, "New")

    let response = handler.handle(HelperRequest(command: .createFolder(path: folder)))

    #expect(response.result == .failure(.notAuthorized))
    #expect(FileManager.default.fileExists(atPath: folder) == false)
  }

  // MARK: - Jobs

  @Test
  internal func `A copy job copies a folder with its contents and keeps links as links`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("Source/Sub")
    try directory.createFile("Source/a.txt", contents: "a")
    try directory.createFile("Source/Sub/b.txt", contents: "bb")
    try FileManager.default.createSymbolicLink(atPath: path(directory, "Source/link"), withDestinationPath: "/etc/hosts")

    let status = try await runJob(.copy(source: path(directory, "Source"), destination: path(directory, "Copy")))

    #expect(status.failure == nil)
    #expect(status.processedItems == 5)
    #expect(status.processedBytes == 3)
    #expect(try String(contentsOfFile: path(directory, "Copy/Sub/b.txt"), encoding: .utf8) == "bb")
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: path(directory, "Copy/link")) == "/etc/hosts")
  }

  @Test
  internal func `A move job renames within the volume and a delete job never follows links`() async throws {
    let directory = try TemporaryDirectory()
    let outside = try directory.createFile("outside.txt", contents: "o")
    try directory.createFolder("Folder")
    try FileManager.default.createSymbolicLink(atPath: path(directory, "Folder/link"), withDestinationPath: outside.path(percentEncoded: false))

    let moved = try await runJob(.move(source: path(directory, "Folder"), destination: path(directory, "Moved")))
    let deleted = try await runJob(.delete(path: path(directory, "Moved")))

    #expect(moved.failure == nil && deleted.failure == nil)
    #expect(FileManager.default.fileExists(atPath: path(directory, "Folder")) == false)
    #expect(FileManager.default.fileExists(atPath: path(directory, "Moved")) == false)
    #expect(try String(contentsOf: outside, encoding: .utf8) == "o")
  }

  @Test
  internal func `A cancelled copy leaves nothing behind`() throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("Source")
    try directory.createFile("Source/a.txt", contents: "a")
    let context = HelperJobContext()
    context.cancel()

    var failure: HelperFailure?
    do throws(HelperFailure) {
      try HelperFileSystem.run(.copy(source: path(directory, "Source"), destination: path(directory, "Copy")), context: context)
    } catch {
      failure = error
    }

    #expect(failure == .posix(ECANCELED))
    #expect(FileManager.default.fileExists(atPath: path(directory, "Copy")) == false)
  }

  @Test
  internal func `Unknown jobs are reported`() {
    #expect(send(.jobStatus(id: UUID())) == .failure(.unknownJob))
    #expect(send(.cancelJob(id: UUID())) == .failure(.unknownJob))
  }

  // MARK: - Helpers

  private func send(_ command: HelperCommand) -> HelperResult {
    handler.handle(HelperRequest(command: command, authorization: authorization)).result
  }

  /// Starts `job` and waits until it finished.
  private func runJob(_ job: HelperJob) async throws -> HelperJobStatus {
    guard case .jobStarted(let id) = send(.startJob(job)) else {
      throw HelperFailure.invalidRequest
    }
    while true {
      guard case .jobStatus(let status) = send(.jobStatus(id: id)) else {
        throw HelperFailure.unknownJob
      }
      if status.isFinished {
        return status
      }
      try await Task.sleep(for: .milliseconds(20))
    }
  }

  private func path(_ directory: TemporaryDirectory, _ relativePath: String) -> String {
    directory.url.appending(path: relativePath).path(percentEncoded: false)
  }

  private func permissions(of url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
    return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
  }

  private func flags(of url: URL) throws -> UInt32 {
    var status = stat()
    guard lstat(url.path(percentEncoded: false), &status) == 0 else {
      throw POSIXError(.ENOENT)
    }
    return status.st_flags
  }
}

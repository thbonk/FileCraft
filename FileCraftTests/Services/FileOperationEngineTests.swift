/*
 * FileOperationEngineTests.swift
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

import Darwin
import Foundation
import Synchronization
import Testing
@testable import FileCraft

/// Integration tests on temporary folders. Each test uses its own engine; moves across volumes and Replace are
/// exercised with injected functions, so the tests need no second volume and never touch the Trash.
@Suite(.timeLimit(.minutes(1)))
internal struct FileOperationEngineTests {

  // MARK: - Copying

  @Test(arguments: [true, false])
  internal func `Copying a file keeps its data, extended attributes, tags, permissions and dates`(cloning: Bool) async throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFile("report.txt", contents: "hello")
    let target = try directory.createFolder("Target")
    let value = Array("FileCraft".utf8)
    #expect(setxattr(source.path(percentEncoded: false), "de.meandmymac.test", value, value.count, 0, 0) == 0)
    let pastDate = Date(timeIntervalSince1970: 1_600_000_000)
    var mutableSource = source
    var values = URLResourceValues()
    values.tagNames = ["Blue"]
    values.creationDate = pastDate
    values.contentModificationDate = pastDate
    try mutableSource.setResourceValues(values)
    try setMode(0o640, of: source)

    let request = FileOperationRequest(kind: .copy, sources: [source], destination: target, allowsCloning: cloning)
    let result = try await run(request)

    let copy = target.appending(path: "report.txt")
    let copyValues = try copy.resourceValues(forKeys: [.tagNamesKey, .creationDateKey, .contentModificationDateKey])
    #expect(result.state == .completed)
    #expect(result.results.map(\.comparablePath) == [copy.comparablePath])
    #expect(try String(contentsOf: copy, encoding: .utf8) == "hello")
    #expect(getxattr(copy.path(percentEncoded: false), "de.meandmymac.test", nil, 0, 0, 0) == value.count)
    #expect(copyValues.tagNames == ["Blue"])
    #expect(try mode(of: copy) == 0o640)
    #expect(copyValues.creationDate == pastDate)
    #expect(copyValues.contentModificationDate == pastDate)
    #expect(result.processedItems == result.totalItems)
    #expect(result.processedBytes == 5)
  }

  @Test
  internal func `Copying a folder copies its contents and keeps symbolic links as links`() async throws {
    let directory = try TemporaryDirectory()
    let folder = try directory.createFolder("Project")
    try directory.createFile("Project/a.txt", contents: "a")
    try directory.createFolder("Project/Sub")
    try directory.createFile("Project/Sub/b.txt", contents: "bb")
    let link = folder.appending(path: "hosts")
    try FileManager.default.createSymbolicLink(atPath: link.path(percentEncoded: false), withDestinationPath: "/etc/hosts")
    let target = try directory.createFolder("Target")

    let result = try await run(FileOperationRequest(kind: .copy, sources: [folder], destination: target))

    let copiedLink = target.appending(path: "Project/hosts")
    #expect(result.state == .completed)
    #expect(try String(contentsOf: target.appending(path: "Project/Sub/b.txt"), encoding: .utf8) == "bb")
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: copiedLink.path(percentEncoded: false)) == "/etc/hosts")
    // Project, a.txt, Sub, b.txt and the link; the bytes are those of the regular files.
    #expect(result.totalItems == 5)
    #expect(result.processedItems == 5)
    #expect(result.processedBytes == 3)
  }

  @Test
  internal func `Copies share their blocks with the original only when cloning is allowed`() async throws {
    let directory = try TemporaryDirectory()
    let source = try largeFile(in: directory, megabytes: 1)
    let cloneTarget = try directory.createFolder("Clone")
    let copyTarget = try directory.createFolder("Copy")

    _ = try await run(FileOperationRequest(kind: .copy, sources: [source], destination: cloneTarget, allowsCloning: true))
    _ = try await run(FileOperationRequest(kind: .copy, sources: [source], destination: copyTarget, allowsCloning: false))

    #expect(try sharesBlocks(cloneTarget.appending(path: "large.bin")))
    #expect(try sharesBlocks(copyTarget.appending(path: "large.bin")) == false)
  }

  @Test
  internal func `A paused copy waits, and cancelling it removes the partial copy`() async throws {
    let directory = try TemporaryDirectory()
    let source = try largeFile(in: directory, megabytes: 48)
    let destination = directory.url.appending(path: "copy.bin")
    let control = OperationControl()
    control.pause()

    let copy = Task.detached {
      try? FileCopier.copyItem(source, to: destination, cloning: false, control: control)
      return FileManager.default.fileExists(atPath: destination.path(percentEncoded: false))
    }
    try await Task.sleep(for: .milliseconds(400))
    let bytesWhilePaused = control.snapshot.fileBytes
    try await Task.sleep(for: .milliseconds(200))
    let bytesLater = control.snapshot.fileBytes
    control.cancel()
    let copyExists = await copy.value

    #expect(bytesWhilePaused == bytesLater)
    #expect(bytesWhilePaused < 48 << 20)
    #expect(copyExists == false)
  }

  @Test
  internal func `A resumed copy completes`() async throws {
    let directory = try TemporaryDirectory()
    let source = try largeFile(in: directory, megabytes: 16)
    let destination = directory.url.appending(path: "copy.bin")
    let control = OperationControl()
    control.pause()

    let copy = Task.detached {
      (try? FileCopier.copyItem(source, to: destination, cloning: false, control: control)) != nil
    }
    try await Task.sleep(for: .milliseconds(300))
    control.resume()
    let succeeded = await copy.value

    #expect(succeeded)
    #expect(FileVerifier.contentsMatch(source.path(percentEncoded: false), destination.path(percentEncoded: false)))
    #expect(control.snapshot.errors.isEmpty)
  }

  @Test
  internal func `The engine reports the final progress to its observers`() async throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFile("a.txt", contents: "abc")
    let target = try directory.createFolder("Target")
    let engine = FileOperationEngine()
    let updates = await engine.updates()

    let id = await engine.enqueue(FileOperationRequest(kind: .copy, sources: [source], destination: target))
    var finished: FileOperationProgress?
    for await snapshot in updates {
      if let progress = snapshot.first(where: { $0.id == id }), progress.state.isFinished {
        finished = progress
        break
      }
    }

    #expect(finished?.state == .completed)
    #expect(finished?.processedBytes == 3)
    #expect(finished?.fractionCompleted == 1)
    #expect(finished?.currentItemName == nil)
    #expect(finished?.bytesPerSecond == nil)
  }

  // MARK: - Moving

  @Test
  internal func `A move within a volume renames the item and keeps its inode`() async throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFile("notes.txt", contents: "x")
    let target = try directory.createFolder("Target")
    let inodeBefore = try inode(of: source)

    let result = try await run(FileOperationRequest(kind: .move, sources: [source], destination: target))

    let moved = target.appending(path: "notes.txt")
    #expect(result.state == .completed)
    #expect(try inode(of: moved) == inodeBefore)
    #expect(FileManager.default.fileExists(atPath: source.path(percentEncoded: false)) == false)
  }

  @Test
  internal func `Moving an item into the folder it is in changes nothing`() async throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFile("notes.txt", contents: "x")

    let result = try await run(FileOperationRequest(kind: .move, sources: [source], destination: directory.url))

    #expect(result.state == .completed)
    #expect(result.results.isEmpty)
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.url.path(percentEncoded: false)) == ["notes.txt"])
  }

  @Test
  internal func `A move across volumes deletes each source only after its copy, also when interrupted`() throws {
    let directory = try TemporaryDirectory()
    let first = try directory.createFile("a.txt", contents: "a")
    let second = try directory.createFile("b.txt", contents: "b")
    let target = try directory.createFolder("Target")
    let control = OperationControl()
    let calls = CallCounter()
    let request = FileOperationRequest(kind: .move, sources: [first, second], destination: target, allowsCloning: false)
    let totals = [SourceTotals(items: 1, bytes: 1), SourceTotals(items: 1, bytes: 1)]

    // Every move counts as one across volumes; the second one is interrupted as it starts.
    FileOperationWorker.perform(request, totals: totals, control: control, renameWithinVolume: { _, _ in
      if calls.increment() == 2 {
        control.cancel()
      }
      return false
    })

    #expect(FileManager.default.fileExists(atPath: first.path(percentEncoded: false)) == false)
    #expect(FileManager.default.fileExists(atPath: target.appending(path: "a.txt").path(percentEncoded: false)))
    #expect(FileManager.default.fileExists(atPath: second.path(percentEncoded: false)))
    #expect(FileManager.default.fileExists(atPath: target.appending(path: "b.txt").path(percentEncoded: false)) == false)
  }

  // MARK: - Conflicts and Safety

  @Test
  internal func `Keep Both names the new item with the next free number`() async throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFile("report.pdf", contents: "new")
    let target = try directory.createFolder("Target")
    try directory.createFile("Target/report.pdf", contents: "old")

    let result = try await run(FileOperationRequest(kind: .copy, sources: [source], destination: target, conflictPolicy: .keepBoth))

    #expect(result.results.map(\.lastPathComponent) == ["report 2.pdf"])
    #expect(try String(contentsOf: target.appending(path: "report.pdf"), encoding: .utf8) == "old")
  }

  @Test
  internal func `Skip leaves the existing item, Stop ends the operation`() async throws {
    let directory = try TemporaryDirectory()
    let conflicting = try directory.createFile("a.txt", contents: "new")
    let other = try directory.createFile("b.txt", contents: "b")
    let target = try directory.createFolder("Target")
    try directory.createFile("Target/a.txt", contents: "old")

    let skipped = try await run(FileOperationRequest(kind: .copy, sources: [conflicting, other], destination: target, conflictPolicy: .skip))
    try FileManager.default.removeItem(at: target.appending(path: "b.txt"))
    let stopped = try await run(FileOperationRequest(kind: .copy, sources: [conflicting, other], destination: target, conflictPolicy: .stop))

    #expect(skipped.state == .completed)
    #expect(skipped.results.map(\.lastPathComponent) == ["b.txt"])
    #expect(try String(contentsOf: target.appending(path: "a.txt"), encoding: .utf8) == "old")
    #expect(stopped.state == .cancelled)
    #expect(FileManager.default.fileExists(atPath: target.appending(path: "b.txt").path(percentEncoded: false)) == false)
  }

  @Test
  internal func `Replace removes the existing item before copying`() throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFile("a.txt", contents: "new")
    let target = try directory.createFolder("Target")
    try directory.createFile("Target/a.txt", contents: "old")
    let request = FileOperationRequest(kind: .copy, sources: [source], destination: target, conflictPolicy: .replace)

    // Deleting instead of moving to the Trash keeps the user's Trash untouched.
    FileOperationWorker.perform(request, totals: [SourceTotals(items: 1, bytes: 3)], control: OperationControl(), discardExisting: { url in
      try FileManager.default.removeItem(at: url)
    })

    #expect(try String(contentsOf: target.appending(path: "a.txt"), encoding: .utf8) == "new")
  }

  @Test
  internal func `A folder is never copied into itself or one of its folders`() async throws {
    let directory = try TemporaryDirectory()
    let folder = try directory.createFolder("A")
    let subfolder = try directory.createFolder("A/B")

    let result = try await run(FileOperationRequest(kind: .copy, sources: [folder], destination: subfolder))

    #expect(result.state == .failed)
    #expect(result.errors.count == 1)
    #expect(try FileManager.default.contentsOfDirectory(atPath: subfolder.path(percentEncoded: false)).isEmpty)
  }

  @Test
  internal func `Verification compares checksums`() throws {
    let directory = try TemporaryDirectory()
    let first = try directory.createFile("a.txt", contents: "same")
    let second = try directory.createFile("b.txt", contents: "same")
    let third = try directory.createFile("c.txt", contents: "diff")

    #expect(FileVerifier.contentsMatch(first.path(percentEncoded: false), second.path(percentEncoded: false)))
    #expect(FileVerifier.contentsMatch(first.path(percentEncoded: false), third.path(percentEncoded: false)) == false)
  }

  // MARK: - Downloaded Applications

  /// Finder records in a downloaded app's quarantine that it may run in place when the user moves it, so that macOS
  /// stops running it from a temporary copy (App Translocation); FileCraft does the same.
  @Test(arguments: [FileOperationKind.move, .copy])
  internal func `Moving or copying a downloaded app lets it run in place`(kind: FileOperationKind) async throws {
    let directory = try TemporaryDirectory()
    _ = try directory.createFolder("Downloads/Tool.app/Contents")
    let app = directory.url.appending(path: "Downloads/Tool.app")
    try QuarantineTests.setQuarantine("0083;6533c2a1;Safari;6E4C2B1A", on: app)
    let applications = try directory.createFolder("Applications")

    _ = try await run(FileOperationRequest(kind: kind, sources: [app], destination: applications))

    #expect(QuarantineTests.quarantine(of: applications.appending(path: "Tool.app")) == "0183;6533c2a1;Safari;6E4C2B1A")
  }

  @Test
  internal func `Moving a folder that is not an app keeps its quarantine`() async throws {
    let directory = try TemporaryDirectory()
    let folder = try directory.createFolder("Downloads/Photos")
    try QuarantineTests.setQuarantine("0083;6533c2a1;Safari;6E4C2B1A", on: folder)
    let target = try directory.createFolder("Pictures")

    _ = try await run(FileOperationRequest(kind: .move, sources: [folder], destination: target))

    #expect(QuarantineTests.quarantine(of: target.appending(path: "Photos")) == "0083;6533c2a1;Safari;6E4C2B1A")
  }

  @Test
  internal func `Moving an app without quarantine gives it none`() async throws {
    let directory = try TemporaryDirectory()
    _ = try directory.createFolder("Builds/Tool.app/Contents")
    let target = try directory.createFolder("Applications")

    _ = try await run(FileOperationRequest(kind: .move, sources: [directory.url.appending(path: "Builds/Tool.app")], destination: target))

    #expect(QuarantineTests.quarantine(of: target.appending(path: "Tool.app")) == nil)
  }

  // MARK: - Helpers

  private func run(_ request: FileOperationRequest) async throws -> FileOperationProgress {
    let engine = FileOperationEngine()
    let id = await engine.enqueue(request)
    return try #require(await engine.waitUntilFinished(id))
  }

  /// A file named "large.bin" with random contents, so that nothing compresses or deduplicates it.
  private func largeFile(in directory: TemporaryDirectory, megabytes: Int) throws -> URL {
    let url = directory.url.appending(path: "large.bin")
    var data = Data(count: megabytes << 20)
    data.withUnsafeMutableBytes { buffer in
      arc4random_buf(buffer.baseAddress, buffer.count)
    }
    try data.write(to: url)
    return url
  }

  private func setMode(_ mode: UInt16, of url: URL) throws {
    try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: mode)], ofItemAtPath: url.path(percentEncoded: false))
  }

  private func mode(of url: URL) throws -> UInt16 {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
    return (attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
  }

  private func inode(of url: URL) throws -> UInt64 {
    var status = stat()
    guard lstat(url.path(percentEncoded: false), &status) == 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    return UInt64(status.st_ino)
  }

  /// Whether APFS reports that the file may share data blocks with another file, as clones do.
  private func sharesBlocks(_ url: URL) throws -> Bool {
    var list = attrlist()
    list.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
    list.forkattr = attrgroup_t(ATTR_CMNEXT_EXT_FLAGS)
    var buffer = [UInt8](repeating: 0, count: 32)
    let options = UInt32(FSOPT_ATTR_CMN_EXTENDED | FSOPT_NOFOLLOW)
    guard getattrlist(url.path(percentEncoded: false), &list, &buffer, buffer.count, options) == 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    // The buffer holds its length as a 32-bit value, followed by the 64-bit extended flags.
    let flags = buffer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: MemoryLayout<UInt32>.size, as: UInt64.self) }
    return flags & UInt64(EF_MAY_SHARE_BLOCKS) != 0
  }
}

/// Counts calls from the worker's thread.
nonisolated private final class CallCounter: Sendable {

  private let count = Mutex(0)

  /// Adds one and returns the new count.
  fileprivate func increment() -> Int {
    count.withLock {
      $0 += 1
      return $0
    }
  }
}

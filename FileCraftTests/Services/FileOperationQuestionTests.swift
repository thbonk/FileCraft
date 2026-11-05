/*
 * FileOperationQuestionTests.swift
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

/// The questions an operation asks about conflicts and failures, answered by a scripted user. Replace deletes the
/// existing item instead of moving it to the Trash, so the tests leave the user's Trash alone.
@Suite(.timeLimit(.minutes(1)))
internal struct FileOperationQuestionTests {

  // MARK: - Conflicts

  @Test
  internal func `A conflict compares both items, and Keep Both adds the new one under the next free name`() throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFile("report.pdf", contents: "new!")
    let target = try directory.createFolder("Target")
    try directory.createFile("Target/report.pdf", contents: "old")
    let user = ScriptedUser([.conflict(.keepBoth, appliesToAll: false)])

    run(.copy, [source], into: target, user: user)

    guard case .conflict(let new, let existing)? = user.topics.first else {
      Issue.record("Expected a conflict question, got \(user.topics)")
      return
    }
    #expect(new.name == "report.pdf")
    #expect(new.size == 4)
    #expect(existing.url.comparablePath == target.appending(path: "report.pdf").comparablePath)
    #expect(existing.size == 3)
    #expect(existing.isFolder == false)
    #expect(try contents(of: target) == ["report 2.pdf", "report.pdf"])
    #expect(try String(contentsOf: target.appending(path: "report.pdf"), encoding: .utf8) == "old")
  }

  @Test
  internal func `A choice for all conflicts answers the later conflicts of the same kind`() throws {
    let directory = try TemporaryDirectory()
    let first = try directory.createFile("a.txt", contents: "new a")
    let second = try directory.createFile("b.txt", contents: "new b")
    let target = try directory.createFolder("Target")
    try directory.createFile("Target/a.txt", contents: "old")
    try directory.createFile("Target/b.txt", contents: "old")
    let user = ScriptedUser([.conflict(.replace, appliesToAll: true)])

    run(.copy, [first, second], into: target, user: user)

    #expect(user.topics.count == 1)
    #expect(try String(contentsOf: target.appending(path: "a.txt"), encoding: .utf8) == "new a")
    #expect(try String(contentsOf: target.appending(path: "b.txt"), encoding: .utf8) == "new b")
  }

  @Test
  internal func `Replace for all conflicts never replaces a folder by a file without asking`() throws {
    let directory = try TemporaryDirectory()
    let file = try directory.createFile("a.txt", contents: "new")
    let fileNamedLikeFolder = try directory.createFile("data", contents: "file")
    let target = try directory.createFolder("Target")
    try directory.createFile("Target/a.txt", contents: "old")
    try directory.createFolder("Target/data")
    let user = ScriptedUser([.conflict(.replace, appliesToAll: true), .conflict(.skip, appliesToAll: false)])

    run(.copy, [file, fileNamedLikeFolder], into: target, user: user)

    #expect(user.topics.count == 2)
    #expect(FileCopier.isDirectory(target.appending(path: "data")))
    #expect(try String(contentsOf: target.appending(path: "a.txt"), encoding: .utf8) == "new")
  }

  @Test
  internal func `Merging folders combines their contents and asks about conflicts inside them`() throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFolder("Source/Assets")
    try directory.createFile("Source/Assets/a.txt", contents: "a")
    try directory.createFile("Source/Assets/c.txt", contents: "new c")
    try directory.createFolder("Source/Assets/Sub")
    try directory.createFile("Source/Assets/Sub/b.txt", contents: "b")
    let target = try directory.createFolder("Target")
    try directory.createFolder("Target/Assets")
    try directory.createFile("Target/Assets/c.txt", contents: "old c")
    try directory.createFile("Target/Assets/z.txt", contents: "z")
    let user = ScriptedUser([.conflict(.merge, appliesToAll: false), .conflict(.keepBoth, appliesToAll: false)])

    run(.copy, [source], into: target, user: user)

    let merged = target.appending(path: "Assets")
    guard case .conflict(let new, let existing)? = user.topics.first else {
      Issue.record("Expected a conflict question, got \(user.topics)")
      return
    }
    #expect(new.isFolder && existing.isFolder)
    #expect(user.topics.count == 2)
    #expect(try contents(of: merged) == ["Sub", "a.txt", "c 2.txt", "c.txt", "z.txt"])
    #expect(try String(contentsOf: merged.appending(path: "Sub/b.txt"), encoding: .utf8) == "b")
    #expect(try String(contentsOf: merged.appending(path: "c.txt"), encoding: .utf8) == "old c")
    #expect(FileManager.default.fileExists(atPath: source.path(percentEncoded: false)))
  }

  @Test
  internal func `Merging a moved folder removes it unless an item inside it was skipped`() throws {
    let directory = try TemporaryDirectory()
    let kept = try directory.createFolder("Source/A")
    try directory.createFile("Source/A/a.txt", contents: "a")
    try directory.createFile("Source/A/b.txt", contents: "new b")
    let emptied = try directory.createFolder("Source/B")
    try directory.createFile("Source/B/x.txt", contents: "x")
    let target = try directory.createFolder("Target")
    try directory.createFolder("Target/A")
    try directory.createFile("Target/A/b.txt", contents: "old b")
    try directory.createFolder("Target/B")
    try directory.createFile("Target/B/y.txt", contents: "y")
    let user = ScriptedUser([
      .conflict(.merge, appliesToAll: false),
      .conflict(.skip, appliesToAll: false),
      .conflict(.merge, appliesToAll: false),
    ])

    run(.move, [kept, emptied], into: target, user: user)

    #expect(try contents(of: kept) == ["b.txt"])
    #expect(try contents(of: target.appending(path: "A")) == ["a.txt", "b.txt"])
    #expect(FileManager.default.fileExists(atPath: emptied.path(percentEncoded: false)) == false)
    #expect(try contents(of: target.appending(path: "B")) == ["x.txt", "y.txt"])
  }

  @Test
  internal func `Copying an item into its own folder makes a duplicate without asking`() throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFile("plan.txt", contents: "p")
    let user = ScriptedUser([])
    let duplicateName = UniqueNameGenerator().duplicateName(of: "plan.txt", isFolder: false, existingNames: ["plan.txt"])

    run(.copy, [source], into: directory.url, user: user)

    #expect(user.topics.isEmpty)
    #expect(try contents(of: directory.url) == [duplicateName, "plan.txt"].sorted())
  }

  @Test
  internal func `Stop in the conflict dialog ends the operation`() throws {
    let directory = try TemporaryDirectory()
    let first = try directory.createFile("a.txt", contents: "new")
    let second = try directory.createFile("b.txt", contents: "b")
    let target = try directory.createFolder("Target")
    try directory.createFile("Target/a.txt", contents: "old")
    let user = ScriptedUser([.conflict(.stop, appliesToAll: false)])

    let control = run(.copy, [first, second], into: target, user: user)

    #expect(control.isCancelled)
    #expect(try contents(of: target) == ["a.txt"])
  }

  // MARK: - Failures

  @Test
  internal func `A failed item can be skipped and is listed with its reason`() throws {
    let directory = try TemporaryDirectory()
    let unreadable = try directory.createFile("secret.txt", contents: "s")
    let readable = try directory.createFile("open.txt", contents: "o")
    let target = try directory.createFolder("Target")
    try setMode(0o000, of: unreadable)
    let user = ScriptedUser([.failure(.skip, appliesToAll: false)])

    let control = run(.copy, [unreadable, readable], into: target, user: user)

    guard case .failure(let item, let reason, let isPermissionError)? = user.topics.first else {
      Issue.record("Expected a failure question, got \(user.topics)")
      return
    }
    #expect(item.comparablePath == unreadable.comparablePath)
    #expect(isPermissionError)
    #expect(reason.isEmpty == false)
    #expect(control.snapshot.errors.map(\.url.comparablePath) == [unreadable.comparablePath])
    #expect(try contents(of: target) == ["open.txt"])
  }

  @Test
  internal func `Retry copies the item once the problem is solved`() throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFile("secret.txt", contents: "s")
    let target = try directory.createFolder("Target")
    try setMode(0o000, of: source)
    let path = source.path(percentEncoded: false)
    // The user fixes the permissions before choosing Retry.
    let user = ScriptedUser([.failure(.retry, appliesToAll: false)]) { _ in
      chmod(path, 0o644)
    }

    let control = run(.copy, [source], into: target, user: user)

    #expect(user.topics.count == 1)
    #expect(control.snapshot.errors.isEmpty)
    #expect(try String(contentsOf: target.appending(path: "secret.txt"), encoding: .utf8) == "s")
  }

  @Test
  internal func `Skip for all errors answers the later failures`() throws {
    let directory = try TemporaryDirectory()
    let first = try directory.createFile("a.txt", contents: "a")
    let second = try directory.createFile("b.txt", contents: "b")
    let target = try directory.createFolder("Target")
    try setMode(0o000, of: first)
    try setMode(0o000, of: second)
    let user = ScriptedUser([.failure(.skip, appliesToAll: true)])

    let control = run(.copy, [first, second], into: target, user: user)

    #expect(user.topics.count == 1)
    #expect(control.snapshot.errors.count == 2)
    #expect(try contents(of: target).isEmpty)
  }

  @Test
  internal func `Stop in the error dialog cancels the operation`() throws {
    let directory = try TemporaryDirectory()
    let unreadable = try directory.createFile("a.txt", contents: "a")
    let readable = try directory.createFile("b.txt", contents: "b")
    let target = try directory.createFolder("Target")
    try setMode(0o000, of: unreadable)
    let user = ScriptedUser([.failure(.stop, appliesToAll: false)])

    let control = run(.copy, [unreadable, readable], into: target, user: user)

    #expect(control.isCancelled)
    #expect(try contents(of: target).isEmpty)
  }

  @Test
  internal func `A failure inside a folder keeps the source of a move across volumes`() throws {
    let directory = try TemporaryDirectory()
    let folder = try directory.createFolder("Folder")
    try directory.createFile("Folder/open.txt", contents: "o")
    let unreadable = try directory.createFile("Folder/secret.txt", contents: "s")
    let target = try directory.createFolder("Target")
    try setMode(0o000, of: unreadable)
    let user = ScriptedUser([.failure(.skip, appliesToAll: false)])

    run(.move, [folder], into: target, user: user, renameWithinVolume: { _, _ in false })

    #expect(user.topics.count == 1)
    #expect(try contents(of: folder) == ["open.txt", "secret.txt"])
    #expect(try contents(of: target.appending(path: "Folder")) == ["open.txt"])
  }

  @Test
  internal func `A copied folder keeps its date and attributes although its contents arrive later`() throws {
    let directory = try TemporaryDirectory()
    var folder = try directory.createFolder("Folder")
    try directory.createFile("Folder/a.txt", contents: "a")
    let value = Array("x".utf8)
    #expect(setxattr(folder.path(percentEncoded: false), "de.meandmymac.test", value, value.count, 0, 0) == 0)
    let pastDate = Date(timeIntervalSince1970: 1_500_000_000)
    var values = URLResourceValues()
    values.contentModificationDate = pastDate
    try folder.setResourceValues(values)
    let target = try directory.createFolder("Target")

    run(.copy, [folder], into: target, user: ScriptedUser([]))

    let copy = target.appending(path: "Folder")
    #expect(try copy.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate == pastDate)
    #expect(getxattr(copy.path(percentEncoded: false), "de.meandmymac.test", nil, 0, 0, 0) == value.count)
    #expect(try contents(of: copy) == ["a.txt"])
  }

  @Test
  internal func `Authenticate and Retry copies the item through the helper`() throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFile("secret.txt", contents: "s")
    let target = try directory.createFolder("Target")
    try setMode(0o000, of: source)
    let path = source.path(percentEncoded: false)
    let user = ScriptedUser([.failure(.authenticateAndRetry, appliesToAll: false)])
    let control = OperationControl()
    let request = FileOperationRequest(kind: .copy, sources: [source], destination: target)

    // The fake helper copies with the rights it has: it restores the permissions first.
    FileOperationWorker.perform(request, totals: [], control: control, ask: { user.answer($0) }) { job, _ in
      guard case .copy(let from, let to) = job else {
        throw PrivilegedRunner.RunnerError.helper(.invalidRequest)
      }
      chmod(path, 0o644)
      try FileManager.default.copyItem(atPath: from, toPath: to)
    }

    guard case .failure(_, _, let canAuthenticate)? = user.topics.first else {
      Issue.record("Expected a failure question, got \(user.topics)")
      return
    }
    #expect(canAuthenticate)
    #expect(control.snapshot.errors.isEmpty)
    #expect(try String(contentsOf: target.appending(path: "secret.txt"), encoding: .utf8) == "s")
  }

  @Test
  internal func `A failure of the helper is asked about again with the helper's reason`() throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFile("secret.txt", contents: "s")
    let target = try directory.createFolder("Target")
    try setMode(0o000, of: source)
    let user = ScriptedUser([.failure(.authenticateAndRetry, appliesToAll: false), .failure(.skip, appliesToAll: false)])
    let control = OperationControl()
    let request = FileOperationRequest(kind: .copy, sources: [source], destination: target)
    let helperFailure = PrivilegedRunner.RunnerError.helper(.protectedLocation)

    FileOperationWorker.perform(request, totals: [], control: control, ask: { user.answer($0) }) { _, _ in
      throw helperFailure
    }

    #expect(user.topics.count == 2)
    #expect(control.snapshot.errors.map(\.reason) == [helperFailure.errorDescription ?? ""])
  }

  // MARK: - Engine

  @Test
  internal func `The engine shows a question in the progress and continues with the answer`() async throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFile("report.pdf", contents: "new")
    let target = try directory.createFolder("Target")
    try directory.createFile("Target/report.pdf", contents: "old")
    let engine = FileOperationEngine()
    let updates = await engine.updates()

    let id = await engine.enqueue(FileOperationRequest(kind: .copy, sources: [source], destination: target))
    var questionIDs: Set<UUID> = []
    var finished: FileOperationProgress?
    for await snapshot in updates {
      guard let progress = snapshot.first(where: { $0.id == id }) else {
        continue
      }
      if let question = progress.question, questionIDs.insert(question.id).inserted {
        await engine.answer(.conflict(.keepBoth, appliesToAll: false), to: question.id, of: id)
      }
      if progress.state.isFinished {
        finished = progress
        break
      }
    }

    #expect(questionIDs.count == 1)
    #expect(finished?.state == .completed)
    #expect(finished?.results.map(\.lastPathComponent) == ["report 2.pdf"])
  }

  // MARK: - Helpers

  /// Runs a request with the scripted user and returns the operation's control.
  @discardableResult
  private func run(
    _ kind: FileOperationKind,
    _ sources: [URL],
    into destination: URL,
    user: ScriptedUser,
    renameWithinVolume: @escaping FileOperationWorker.RenameWithinVolume = FileOperationWorker.renameWithinVolume
  ) -> OperationControl {
    let control = OperationControl()
    let request = FileOperationRequest(kind: kind, sources: sources, destination: destination)
    FileOperationWorker.perform(
      request,
      totals: [],
      control: control,
      renameWithinVolume: renameWithinVolume,
      discardExisting: { try FileManager.default.removeItem(at: $0) },
      ask: { user.answer($0) })
    return control
  }

  private func contents(of folder: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).sorted()
  }

  private func setMode(_ mode: UInt16, of url: URL) throws {
    try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: mode)], ofItemAtPath: url.path(percentEncoded: false))
  }
}

/// Answers the questions of an operation in order, as a user would, and records them.
nonisolated private final class ScriptedUser: Sendable {

  private struct State {
    var answers: [OperationAnswer]
    var topics: [OperationQuestion.Topic] = []
  }

  private let state: Mutex<State>
  private let beforeAnswering: @Sendable (OperationQuestion.Topic) -> Void

  fileprivate init(
    _ answers: [OperationAnswer],
    beforeAnswering: @escaping @Sendable (OperationQuestion.Topic) -> Void = { _ in }
  ) {
    state = Mutex(State(answers: answers))
    self.beforeAnswering = beforeAnswering
  }

  /// The questions asked so far.
  fileprivate var topics: [OperationQuestion.Topic] {
    state.withLock { $0.topics }
  }

  /// Records `topic` and gives the next answer; without an answer left, the user cancels.
  fileprivate func answer(_ topic: OperationQuestion.Topic) -> OperationAnswer? {
    beforeAnswering(topic)
    return state.withLock { state in
      state.topics.append(topic)
      return state.answers.isEmpty ? nil : state.answers.removeFirst()
    }
  }
}

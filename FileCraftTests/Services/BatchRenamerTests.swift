/*
 * BatchRenamerTests.swift
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

internal struct BatchRenamerTests {

  @Test
  internal func `Names can be exchanged within a batch`() async throws {
    let directory = try TemporaryDirectory()
    let a = try directory.createFile("a.txt", contents: "A")
    let b = try directory.createFile("b.txt", contents: "B")

    try await BatchRenamer().rename([ItemMove(from: a, to: b), ItemMove(from: b, to: a)])

    #expect(try String(contentsOf: a, encoding: .utf8) == "B")
    #expect(try String(contentsOf: b, encoding: .utf8) == "A")
    #expect(try names(in: directory) == ["a.txt", "b.txt"])
  }

  @Test
  internal func `Chains and case changes work`() async throws {
    let directory = try TemporaryDirectory()
    let one = try directory.createFile("1", contents: "one")
    let two = try directory.createFile("2", contents: "two")
    let photo = try directory.createFile("photo.jpg")

    try await BatchRenamer().rename([
      ItemMove(from: one, to: directory.url.appending(path: "2")),
      ItemMove(from: two, to: directory.url.appending(path: "3")),
      ItemMove(from: photo, to: directory.url.appending(path: "Photo.jpg")),
    ])

    #expect(try names(in: directory) == ["2", "3", "Photo.jpg"])
    #expect(try String(contentsOf: directory.url.appending(path: "3"), encoding: .utf8) == "two")
  }

  @Test
  internal func `A failure reverts the renames already made`() async throws {
    let directory = try TemporaryDirectory()
    let first = try directory.createFile("first.txt")
    let locked = try directory.createFile("locked.txt")
    let last = try directory.createFile("last.txt")
    try setLocked(locked, true)
    defer { try? setLocked(locked, false) }

    await #expect(throws: BatchRenameFailure.self) {
      try await BatchRenamer().rename([
        ItemMove(from: first, to: directory.url.appending(path: "1.txt")),
        ItemMove(from: locked, to: directory.url.appending(path: "2.txt")),
        ItemMove(from: last, to: directory.url.appending(path: "3.txt")),
      ])
    }

    #expect(try names(in: directory) == ["first.txt", "last.txt", "locked.txt"])
  }

  @Test
  internal func `An existing item outside the batch is never replaced`() async throws {
    let directory = try TemporaryDirectory()
    let a = try directory.createFile("a.txt", contents: "A")
    try directory.createFile("taken.txt", contents: "keep")

    await #expect(throws: BatchRenameFailure.self) {
      try await BatchRenamer().rename([ItemMove(from: a, to: directory.url.appending(path: "taken.txt"))])
    }

    #expect(try names(in: directory) == ["a.txt", "taken.txt"])
    #expect(try String(contentsOf: directory.url.appending(path: "taken.txt"), encoding: .utf8) == "keep")
  }

  // MARK: - Helpers

  private func names(in directory: TemporaryDirectory) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: directory.url.path(percentEncoded: false)).sorted()
  }

  private func setLocked(_ url: URL, _ isLocked: Bool) throws {
    var values = URLResourceValues()
    values.isUserImmutable = isLocked
    var url = url
    try url.setResourceValues(values)
  }
}

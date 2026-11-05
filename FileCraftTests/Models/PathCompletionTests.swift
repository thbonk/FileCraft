/*
 * PathCompletionTests.swift
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

/// Each test builds a home folder in a temporary directory.
internal struct PathCompletionTests {

  // MARK: - Tests

  @Test
  internal func `Typing "~/Doc" completes to "~/Documents/"`() async throws {
    let home = try TemporaryDirectory()
    try home.createFolder("Documents")
    try home.createFolder("Desktop")

    let completions = await PathCompletion.completions(for: "~/Doc", relativeTo: nil, homeDirectory: home.url)

    #expect(completions == ["~/Documents/"])
  }

  @Test
  internal func `Matches ignore case, are sorted and mark folders with a slash`() async throws {
    let home = try homeWithDocNames()

    let completions = await PathCompletion.completions(for: "~/doc", relativeTo: nil, homeDirectory: home.url)

    #expect(completions == ["~/Docker/", "~/doctor.txt", "~/Documents/"])
  }

  @Test
  internal func `Relative and absolute input keep their notation`() async throws {
    let home = try homeWithDocNames()
    let absolutePrefix = home.url.path(percentEncoded: false)

    let relative = await PathCompletion.completions(for: "Doc", relativeTo: home.url, homeDirectory: home.url)
    let absolute = await PathCompletion.completions(for: absolutePrefix + "Docu", relativeTo: nil, homeDirectory: home.url)

    #expect(relative == ["Docker/", "doctor.txt", "Documents/"])
    #expect(absolute == [absolutePrefix + "Documents/"])
  }

  @Test
  internal func `Hidden names appear only after a typed dot`() async throws {
    let home = try TemporaryDirectory()
    try home.createFolder(".hidden")
    try home.createFolder("Hello")

    let all = await PathCompletion.completions(for: "~/", relativeTo: nil, homeDirectory: home.url)
    let dotted = await PathCompletion.completions(for: "~/.h", relativeTo: nil, homeDirectory: home.url)

    #expect(all == ["~/Hello/"])
    #expect(dotted == ["~/.hidden/"])
  }

  @Test
  internal func `Packages complete without a trailing slash`() async throws {
    let home = try TemporaryDirectory()
    try home.createFolder("Tool.app")

    let completions = await PathCompletion.completions(for: "~/To", relativeTo: nil, homeDirectory: home.url)

    #expect(completions == ["~/Tool.app"])
  }

  @Test
  internal func `A tilde completes to the home folder and file URLs are not completed`() async throws {
    let home = try homeWithDocNames()

    let tilde = await PathCompletion.completions(for: "~", relativeTo: nil, homeDirectory: home.url)
    let fileURL = await PathCompletion.completions(for: home.url.absoluteString + "Doc", relativeTo: nil, homeDirectory: home.url)

    #expect(tilde == ["~/"])
    #expect(fileURL.isEmpty)
  }

  // MARK: - Helpers

  private func homeWithDocNames() throws -> TemporaryDirectory {
    let home = try TemporaryDirectory()
    try home.createFolder("Documents")
    try home.createFolder("Docker")
    try home.createFolder("Desktop")
    try home.createFile("doctor.txt")
    return home
  }
}

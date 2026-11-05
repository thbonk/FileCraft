/*
 * DropPolicyTests.swift
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

/// The drag-and-drop rules, with volumes taken from the first path component so that no second volume is needed.
internal struct DropPolicyTests {

  // MARK: - Properties

  /// "/Disk/…" and "/External/…" count as two volumes.
  private let policy = DropPolicy(volume: { url in url.pathComponents.dropFirst().first })

  // MARK: - Tests

  @Test
  internal func `Drops move on the same volume and copy across volumes`() {
    let file = URL(filePath: "/Disk/Documents/a.txt")

    #expect(policy.action(for: [file], into: URL(filePath: "/Disk/Archive"), keys: .none) == .move)
    #expect(policy.action(for: [file], into: URL(filePath: "/External/Backup"), keys: .none) == .copy)
  }

  @Test
  internal func `Held keys force a copy, a move or aliases`() {
    let file = URL(filePath: "/Disk/Documents/a.txt")
    let sameVolume = URL(filePath: "/Disk/Archive")
    let otherVolume = URL(filePath: "/External/Backup")

    #expect(policy.action(for: [file], into: sameVolume, keys: .copy) == .copy)
    #expect(policy.action(for: [file], into: otherVolume, keys: .move) == .move)
    #expect(policy.action(for: [file], into: otherVolume, keys: .alias) == .alias)
  }

  @Test
  internal func `Dropping items into their own folder changes nothing, unless they are copied`() {
    let folder = URL(filePath: "/Disk/Documents", directoryHint: .isDirectory)
    let file = URL(filePath: "/Disk/Documents/a.txt")

    #expect(policy.action(for: [file], into: folder, keys: .none) == .nothing)
    #expect(policy.action(for: [file], into: folder, keys: .copy) == .copy)
    #expect(policy.action(for: [], into: folder, keys: .none) == .nothing)
  }

  @Test
  internal func `A folder dropped into itself or one of its folders is refused`() throws {
    let directory = try TemporaryDirectory()
    let folder = try directory.createFolder("A")
    let subfolder = try directory.createFolder("A/B")
    let localPolicy = DropPolicy()

    let intoSubfolder = localPolicy.action(for: [folder], into: subfolder, keys: .none)
    let intoItself = localPolicy.action(for: [folder], into: folder, keys: .copy)
    let alias = localPolicy.action(for: [folder], into: subfolder, keys: .alias)

    let reason = String(localized: "A folder can’t be copied or moved into itself.")
    #expect(intoSubfolder == .refuse(reason))
    #expect(intoItself == .refuse(reason))
    #expect(alias == .alias)
  }
}

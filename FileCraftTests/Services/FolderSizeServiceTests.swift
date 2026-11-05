/*
 * FolderSizeServiceTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-10-30.
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

internal struct FolderSizeServiceTests {

  // MARK: - Properties

  private let directory: TemporaryDirectory
  private let service = FolderSizeService()

  // MARK: - Initialization

  internal init() throws {
    directory = try TemporaryDirectory()
    try directory.createFile("a.txt", contents: "abc")
    try directory.createFolder("Sub")
    try directory.createFile("Sub/b.txt", contents: "defg")
  }

  // MARK: - Tests

  @Test
  internal func `Size counts all nested items and bytes`() async throws {
    let size = try await service.size(of: directory.url)

    #expect(size.itemCount == 3)
    #expect(size.logicalBytes == 7)
    #expect(size.physicalBytes >= size.logicalBytes)
  }

  @Test
  internal func `Invalidating a nested item recalculates the folder`() async throws {
    _ = try await service.size(of: directory.url)
    let nested = try directory.createFile("Sub/c.txt", contents: "hi")

    await service.invalidate(nested)
    let size = try await service.size(of: directory.url)

    #expect(size.itemCount == 4)
    #expect(size.logicalBytes == 9)
  }

  @Test
  internal func `Cancelled calculation throws CancellationError`() async {
    let service = service
    let folder = directory.url
    let task = Task {
      try await service.size(of: folder)
    }
    task.cancel()

    await #expect(throws: CancellationError.self) {
      try await task.value
    }
  }
}

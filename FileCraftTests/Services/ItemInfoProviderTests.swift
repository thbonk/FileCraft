/*
 * ItemInfoProviderTests.swift
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

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import FileCraft

internal struct ItemInfoProviderTests {

  // MARK: - Tests

  @Test
  internal func `Folders report their number of visible items`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFolder("Docs")
    try directory.createFile("Docs/a.txt")
    try directory.createFile("Docs/b.txt")
    try directory.createFile("Docs/.hidden")

    let info = await ItemInfoProvider.info(for: try await item(named: "Docs", in: directory))

    #expect(info == .itemCount(2))
  }

  @Test
  internal func `Images report their pixel dimensions`() async throws {
    let directory = try TemporaryDirectory()
    try writePNG(width: 3, height: 2, to: directory.url.appending(path: "dot.png"))

    let info = await ItemInfoProvider.info(for: try await item(named: "dot.png", in: directory))

    #expect(info == .dimensions(width: 3, height: 2))
  }

  @Test
  internal func `Other files have no item info`() async throws {
    let directory = try TemporaryDirectory()
    try directory.createFile("notes.txt", contents: "text")

    let info = await ItemInfoProvider.info(for: try await item(named: "notes.txt", in: directory))

    #expect(info == nil)
  }

  // MARK: - Helpers

  private func item(named name: String, in directory: TemporaryDirectory) async throws -> FileItem {
    let items = try await FileSystemService().contentsOfDirectory(at: directory.url, includingHiddenItems: false)
    return try #require(items.first { $0.name == name })
  }

  private func writePNG(width: Int, height: Int, to url: URL) throws {
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    let image = try #require(context?.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
  }
}

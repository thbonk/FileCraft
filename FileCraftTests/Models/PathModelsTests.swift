/*
 * PathModelsTests.swift
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

internal struct PathModelsTests {

  // MARK: - Properties

  private let home = URL(filePath: "/Users/anna", directoryHint: .isDirectory)

  // MARK: - Path Components

  @Test
  internal func `Segments run from the startup volume to the folder`() {
    let segments = PathComponents.segments(for: URL(filePath: "/Users/anna/Projects"), volumeRoot: URL(filePath: "/")) {
      $0.path(percentEncoded: false) == "/" ? "Macintosh HD" : $0.lastPathComponent
    }

    #expect(segments.map(\.name) == ["Macintosh HD", "Users", "anna", "Projects"])
  }

  @Test
  internal func `Segments of an external volume start at its root`() {
    let segments = PathComponents.segments(
      for: URL(filePath: "/Volumes/Backup/Photos"),
      volumeRoot: URL(filePath: "/Volumes/Backup", directoryHint: .isDirectory)
    ) { $0.lastPathComponent }

    #expect(segments.map(\.name) == ["Backup", "Photos"])
  }

  // MARK: - Path Input

  @Test
  internal func `Typed paths are interpreted like Go to Folder`() {
    let base = URL(filePath: "/Users/anna/Projects", directoryHint: .isDirectory)

    #expect(PathInputParser.url(for: "~/Documents", relativeTo: base, homeDirectory: home)?.path() == "/Users/anna/Documents")
    #expect(PathInputParser.url(for: "~", relativeTo: base, homeDirectory: home)?.path() == "/Users/anna/")
    #expect(PathInputParser.url(for: " /Library/Fonts ", relativeTo: base, homeDirectory: home)?.path() == "/Library/Fonts")
    #expect(PathInputParser.url(for: "FileCraft", relativeTo: base, homeDirectory: home)?.path() == "/Users/anna/Projects/FileCraft")
    #expect(PathInputParser.url(for: "../Music", relativeTo: base, homeDirectory: home)?.path() == "/Users/anna/Music")
    #expect(PathInputParser.url(for: "file:///tmp/", relativeTo: base, homeDirectory: home)?.path() == "/tmp/")
    #expect(PathInputParser.url(for: "   ", relativeTo: base, homeDirectory: home) == nil)
    #expect(PathInputParser.url(for: "relative", relativeTo: nil, homeDirectory: home) == nil)
  }

  // MARK: - Status Summary

  @Test
  internal func `Status summary counts the selection and adds file sizes`() {
    let items = [
      FileItem(url: URL(filePath: "/tmp/a"), size: 1_000),
      FileItem(url: URL(filePath: "/tmp/b"), size: 3_200_000),
      FileItem(url: URL(filePath: "/tmp/Folder"), isDirectory: true),
    ]

    let summary = StatusSummary(items: items, selection: ["/tmp/a", "/tmp/b", "/tmp/Folder"])
    let foldersOnly = StatusSummary(items: items, selection: ["/tmp/Folder"])

    #expect(summary.itemCount == 3)
    #expect(summary.selectedCount == 3)
    #expect(summary.selectedSize == 3_201_000)
    #expect(foldersOnly.selectedSize == nil)
  }

  // MARK: - Byte Sizes

  @Test
  internal func `Decimal sizes follow the locale`() {
    let english = ByteSizeFormatter(units: .decimal, locale: Locale(identifier: "en_US"))
    let german = ByteSizeFormatter(units: .decimal, locale: Locale(identifier: "de_DE"))

    #expect(normalizedSpaces(english.string(for: 4_200_000)) == "4.2 MB")
    #expect(normalizedSpaces(german.string(for: 4_200_000)) == "4,2 MB")
  }

  @Test
  internal func `Binary sizes use IEC prefixes`() {
    let formatter = ByteSizeFormatter(units: .binary, locale: Locale(identifier: "en_US"))

    #expect(formatter.string(for: 1_024) == "1 KiB")
    #expect(formatter.string(for: 1_572_864) == "1.5 MiB")
  }

  // MARK: - Helpers

  /// Formatters may use non-breaking spaces between number and unit.
  private func normalizedSpaces(_ text: String) -> String {
    text.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
  }
}

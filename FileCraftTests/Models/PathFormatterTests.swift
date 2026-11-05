/*
 * PathFormatterTests.swift
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

import AppKit
import Foundation
import Testing
@testable import FileCraft

internal struct PathFormatterTests {

  // MARK: - Types

  internal struct Example: Sendable, CustomTestStringConvertible {
    let format: PathFormat
    let expected: String

    var testDescription: String {
      format.rawValue
    }
  }

  internal struct Escaping: Sendable, CustomTestStringConvertible {
    let text: String
    let expected: String

    var testDescription: String {
      text.debugDescription
    }
  }

  // MARK: - Arguments

  nonisolated private static let home = URL(filePath: "/Users/anna", directoryHint: .isDirectory)
  nonisolated private static let urls = [
    URL(filePath: "/Users/anna/My File.txt"),
    URL(filePath: "/Users/anna/Docs", directoryHint: .isDirectory),
  ]

  nonisolated private static let examples: [Example] = [
    Example(format: .posix, expected: "/Users/anna/My File.txt\n/Users/anna/Docs"),
    Example(format: .homeRelative, expected: "~/My File.txt\n~/Docs"),
    Example(format: .fileURL, expected: "file:///Users/anna/My%20File.txt\nfile:///Users/anna/Docs/"),
    Example(format: .name, expected: "My File.txt\nDocs"),
    Example(format: .shellEscaped, expected: "/Users/anna/My\\ File.txt\n/Users/anna/Docs"),
  ]

  nonisolated private static let escapings: [Escaping] = [
    Escaping(text: "/Users/anna/My File.txt", expected: "/Users/anna/My\\ File.txt"),
    Escaping(text: "a(b)&c;d", expected: "a\\(b\\)\\&c\\;d"),
    Escaping(text: "it's \"$HOME\"", expected: "it\\'s\\ \\\"\\$HOME\\\""),
    Escaping(text: "*?[x]{y}|<>!#~`^=,", expected: "\\*\\?\\[x\\]\\{y\\}\\|\\<\\>\\!\\#\\~\\`\\^\\=\\,"),
    Escaping(text: "Ä-ö_ü.txt", expected: "Ä-ö_ü.txt"),
    Escaping(text: "👨‍👩‍👧 Family", expected: "👨‍👩‍👧\\ Family"),
    Escaping(text: "two\nlines", expected: "$'two\\nlines'"),
    Escaping(text: "tab\tand 'quote'", expected: "$'tab\\tand \\'quote\\''"),
  ]

  // MARK: - Tests

  @Test(arguments: examples)
  internal func `Copy Path As writes one path per line in each format`(example: Example) {
    #expect(PathFormatter.string(for: Self.urls, format: example.format, homeDirectory: Self.home) == example.expected)
  }

  @Test
  internal func `Paths outside the home folder stay absolute, the home folder becomes a tilde`() {
    let paths = [URL(filePath: "/Library/Fonts"), Self.home, URL(filePath: "/Users/annabel")]

    #expect(PathFormatter.string(for: paths, format: .homeRelative, homeDirectory: Self.home) == "/Library/Fonts\n~\n/Users/annabel")
  }

  @Test(arguments: escapings)
  internal func `Shell escaping produces one shell word`(escaping: Escaping) {
    #expect(PathFormatter.shellEscaped(escaping.text) == escaping.expected)
  }

  @Test
  internal func `Copy Path puts the paths on the pasteboard`() {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("FileCraftTests.\(UUID().uuidString)"))
    defer {
      pasteboard.releaseGlobally()
    }

    PasteboardActions.copyPaths(of: Self.urls, as: .posix, to: pasteboard)

    #expect(pasteboard.string(forType: .string) == "/Users/anna/My File.txt\n/Users/anna/Docs")
  }
}

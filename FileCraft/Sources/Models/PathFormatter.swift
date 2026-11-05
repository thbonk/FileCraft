/*
 * PathFormatter.swift
 * FileCraft
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

/// The formats of Edit > Copy Path As.
nonisolated internal enum PathFormat: String, CaseIterable, Sendable {
  /// "/Users/anna/My File.txt"
  case posix
  /// "~/My File.txt"
  case homeRelative
  /// "file:///Users/anna/My%20File.txt"
  case fileURL
  /// "My File.txt"
  case name
  /// "/Users/anna/My\ File.txt"
  case shellEscaped
}

/// Writes paths in the formats of Copy Path and Copy Path As.
nonisolated internal enum PathFormatter {

  /// ASCII characters that a POSIX shell treats specially and that therefore get a backslash.
  private static let shellSpecialCharacters = CharacterSet(charactersIn: " \t!\"#$&'()*,;<=>?[\\]^`{|}~")

  // MARK: - Formatting

  /// The paths of `urls` in `format`, one per line.
  internal static func string(
    for urls: [URL],
    format: PathFormat,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> String {
    urls.map { string(for: $0, format: format, homeDirectory: homeDirectory) }.joined(separator: "\n")
  }

  /// The path of `url` in `format`.
  internal static func string(
    for url: URL,
    format: PathFormat,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> String {
    let path = posixPath(of: url)
    switch format {
    case .posix:
      return path
    case .homeRelative:
      let home = posixPath(of: homeDirectory)
      if path == home {
        return "~"
      }
      return path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    case .fileURL:
      return url.standardizedFileURL.absoluteString
    case .name:
      return url.lastPathComponent
    case .shellEscaped:
      return shellEscaped(path)
    }
  }

  /// `text` as one shell word: special characters get a backslash, and text with control characters such as
  /// line breaks is quoted as `$'…'`, because a backslash before a line break would join the lines.
  internal static func shellEscaped(_ text: String) -> String {
    if text.unicodeScalars.contains(where: isASCIIControl) {
      return ansiCQuoted(text)
    }
    var escaped = String.UnicodeScalarView()
    for scalar in text.unicodeScalars {
      if shellSpecialCharacters.contains(scalar) {
        escaped.append("\\")
      }
      escaped.append(scalar)
    }
    return String(escaped)
  }

  // MARK: - Private

  /// Line breaks, tabs and the other ASCII control characters.
  private static func isASCIIControl(_ scalar: Unicode.Scalar) -> Bool {
    scalar.value < 0x20 || scalar.value == 0x7F
  }

  /// The standardized path without a trailing slash, except for the root folder.
  private static func posixPath(of url: URL) -> String {
    url.comparablePath
  }

  private static func ansiCQuoted(_ text: String) -> String {
    var quoted = "$'"
    for scalar in text.unicodeScalars {
      switch scalar {
      case "\\":
        quoted += "\\\\"
      case "'":
        quoted += "\\'"
      case "\n":
        quoted += "\\n"
      case "\t":
        quoted += "\\t"
      case "\r":
        quoted += "\\r"
      case _ where isASCIIControl(scalar):
        quoted += String(format: "\\x%02x", scalar.value)
      default:
        quoted.unicodeScalars.append(scalar)
      }
    }
    return quoted + "'"
  }
}

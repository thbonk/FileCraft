/*
 * NamePattern.swift
 * FileCraft
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

/// A pattern that item names are matched against, as Select by Pattern and the "matches" search criterion use.
///
/// Wildcard patterns match the whole name: `*` stands for any text, `?` for one character and `[…]` for one
/// character of a set, with `[!…]` negating the set. Regular expressions match anywhere in the name unless they are
/// anchored.
nonisolated internal struct NamePattern: Sendable {

  // MARK: - Types

  internal enum Syntax: String, CaseIterable, Codable, Hashable, Sendable {
    case wildcard
    case regularExpression
  }

  /// Why a pattern cannot be used.
  internal enum PatternError: Error, Equatable {
    case empty
    case invalid
  }

  // MARK: - Properties

  private let expression: NSRegularExpression

  // MARK: - Initialization

  /// Creates a pattern; throws when `text` is empty or not a valid regular expression.
  internal init(_ text: String, syntax: Syntax, isCaseSensitive: Bool = false) throws(PatternError) {
    guard text.isEmpty == false else {
      throw .empty
    }
    let source =
      switch syntax {
      case .wildcard:
        "^" + Self.regularExpression(forWildcard: text) + "$"
      case .regularExpression:
        text
      }
    var options: NSRegularExpression.Options = []
    if isCaseSensitive == false {
      options.insert(.caseInsensitive)
    }
    do {
      expression = try NSRegularExpression(pattern: source, options: options)
    } catch {
      throw .invalid
    }
  }

  // MARK: - Matching

  internal func matches(_ name: String) -> Bool {
    expression.firstMatch(in: name, range: NSRange(location: 0, length: name.utf16.count)) != nil
  }

  // MARK: - Private

  /// Translates a wildcard pattern into the equivalent regular expression without anchors.
  internal static func regularExpression(forWildcard wildcard: String) -> String {
    var result = ""
    var isInSet = false
    var isAtSetStart = false
    for character in wildcard {
      if isInSet {
        switch character {
        case "]" where isAtSetStart == false:
          result.append("]")
          isInSet = false
        case "!" where isAtSetStart:
          result.append("^")
        case "\\", "[", "^":
          result.append("\\\(character)")
        default:
          result.append(character)
        }
        isAtSetStart = false
        continue
      }
      switch character {
      case "*":
        result.append(".*")
      case "?":
        result.append(".")
      case "[" where wildcard.contains("]"):
        result.append("[")
        isInSet = true
        isAtSetStart = true
      default:
        result.append(NSRegularExpression.escapedPattern(for: String(character)))
      }
    }
    if isInSet {
      result.append("]")
    }
    return result
  }
}

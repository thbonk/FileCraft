/*
 * RenameRule.swift
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

/// One rule of a batch rename.
///
/// The settings of all rule types are kept, so that the editor can bind to them directly and switching the type of a
/// rule keeps what the user entered; only the settings of `kind` take part in renaming.
nonisolated internal struct RenameRule: Identifiable, Codable, Hashable, Sendable {

  // MARK: - Types

  internal enum Kind: String, CaseIterable, Codable, Hashable, Sendable {
    case replaceText
    case regularExpression
    case insertText
    case removeCharacters
    case changeCase
    case sequenceNumber
    case date
    case changeExtension
  }

  /// The part of the name a rule changes.
  internal enum Target: String, CaseIterable, Codable, Hashable, Sendable {
    case nameWithoutExtension
    case extensionOnly
    case fullName
  }

  internal enum Occurrence: String, CaseIterable, Codable, Hashable, Sendable {
    case first
    case last
    case all
  }

  internal enum InsertPosition: String, CaseIterable, Codable, Hashable, Sendable {
    case prefix
    case suffix
    case atPosition
  }

  internal enum RemovalPosition: String, CaseIterable, Codable, Hashable, Sendable {
    case fromStart
    case fromEnd
    case atPosition
  }

  internal enum CaseStyle: String, CaseIterable, Codable, Hashable, Sendable {
    case lowercase
    case uppercase
    case titleCase
    case sentenceCase
  }

  /// Where a sequence number or a date goes.
  internal enum EndPosition: String, CaseIterable, Codable, Hashable, Sendable {
    case prefix
    case suffix
  }

  internal enum DateSource: String, CaseIterable, Codable, Hashable, Sendable {
    case created
    case modified
    case current
  }

  internal enum ExtensionChange: String, CaseIterable, Codable, Hashable, Sendable {
    case replace
    case remove
    case lowercase
  }

  // MARK: - Properties

  /// The date formats the Date rule offers besides a custom pattern.
  internal static let dateFormatPresets = ["yyyy-MM-dd", "yyyyMMdd", "yyyy-MM-dd_HH-mm-ss", "dd.MM.yyyy"]

  internal var id = UUID()
  internal var kind: Kind
  internal var isEnabled = true
  internal var target: Target = .nameWithoutExtension

  /// Replace Text and Regular Expression: the text or pattern to find and its replacement; regular expression
  /// replacements may refer to capture groups as "$1".
  internal var findText = ""
  internal var replacementText = ""
  internal var isCaseSensitive = false
  internal var occurrence: Occurrence = .all

  /// Insert Text.
  internal var insertText = ""
  internal var insertPosition: InsertPosition = .suffix
  /// The character position of Insert Text and Remove Characters at a position, counted from 0.
  internal var position = 0

  /// Remove Characters.
  internal var removalCount = 1
  internal var removalPosition: RemovalPosition = .fromStart

  /// Change Case.
  internal var caseStyle: CaseStyle = .lowercase

  /// Sequence Number.
  internal var sequenceStart = 1
  internal var sequenceStep = 1
  internal var sequenceDigits = 3

  /// Sequence Number and Date: where the value goes and what separates it from the name.
  internal var endPosition: EndPosition = .suffix
  internal var separator = "_"

  /// Date: which date and its Unicode date pattern, for example "yyyy-MM-dd".
  internal var dateSource: DateSource = .created
  internal var dateFormat = "yyyy-MM-dd"

  /// Change Extension.
  internal var extensionChange: ExtensionChange = .replace
  internal var newExtension = ""

  // MARK: - Initialization

  internal init(kind: Kind) {
    self.kind = kind
  }
}

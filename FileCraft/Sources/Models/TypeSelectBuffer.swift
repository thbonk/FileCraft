/*
 * TypeSelectBuffer.swift
 * FileCraft
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

/// Collects typed characters into a name prefix for type-to-select.
///
/// The prefix starts over when no character was typed for one second.
nonisolated internal struct TypeSelectBuffer: Sendable {

  // MARK: - Properties

  internal static let resetInterval: Duration = .seconds(1)

  internal private(set) var prefix = ""
  private var lastInput: ContinuousClock.Instant?

  // MARK: - Typing

  /// Appends `characters` typed at `instant` and returns the current prefix.
  internal mutating func append(_ characters: String, at instant: ContinuousClock.Instant) -> String {
    if let lastInput, instant - lastInput > Self.resetInterval {
      prefix = ""
    }
    prefix += characters
    lastInput = instant
    return prefix
  }

  // MARK: - Matching

  /// Returns the first entry, in the given order, whose name starts with `prefix`,
  /// ignoring case and diacritics.
  internal static func firstMatch(
    for prefix: String,
    in entries: [(id: FileItem.ID, name: String)],
    locale: Locale
  ) -> FileItem.ID? {
    guard prefix.isEmpty == false else {
      return nil
    }
    return entries.first { entry in
      entry.name.range(of: prefix, options: [.anchored, .caseInsensitive, .diacriticInsensitive], locale: locale) != nil
    }?.id
  }
}

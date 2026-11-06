/*
 * LocalizationCoverageTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-11-06.
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

/// Checks the String Catalogs in the source folder: every string has a finished German translation with the same
/// placeholders, nothing is stale, and strings with one count have plural variants.
///
/// The catalogs are updated by `xcodebuild -exportLocalizations` (see `docs/dev/LOCALIZATION.md`); run it before this
/// test after changing user-visible text.
internal struct LocalizationCoverageTests {

  // MARK: - Tests

  @Test(arguments: ["Localizable.xcstrings", "InfoPlist.xcstrings"])
  internal func `Every string has a German translation`(catalog: String) throws {
    let strings = try Self.strings(in: catalog)
    let missing = strings.filter { key, entry in
      Self.translates(entry) && Self.germanValues(of: entry).isEmpty
    }.keys.sorted()

    #expect(missing.isEmpty, "Missing German: \(missing)")
  }

  @Test(arguments: ["Localizable.xcstrings", "InfoPlist.xcstrings"])
  internal func `No string is stale or waits for review`(catalog: String) throws {
    let strings = try Self.strings(in: catalog)
    let stale = strings.filter { ($0.value["extractionState"] as? String) == "stale" }.keys.sorted()
    let unfinished = strings.filter { _, entry in
      Self.units(of: entry, language: "de").contains { ($0["state"] as? String) != "translated" }
    }.keys.sorted()

    #expect(stale.isEmpty, "Stale: \(stale)")
    #expect(unfinished.isEmpty, "Not translated yet: \(unfinished)")
  }

  @Test
  internal func `German translations keep the placeholders of the key`() throws {
    let strings = try Self.strings(in: "Localizable.xcstrings")
    var problems: [String] = []
    for (key, entry) in strings where Self.translates(entry) {
      let expected = Self.placeholders(in: key)
      for value in Self.germanValues(of: entry) where Self.placeholders(in: value) != expected {
        problems.append("\(key) → \(value)")
      }
    }
    #expect(problems.isEmpty, "\(problems)")
  }

  @Test
  internal func `Strings with one count have plural variants`() throws {
    let strings = try Self.strings(in: "Localizable.xcstrings")
    let missing = strings.filter { key, entry in
      let counts = Self.placeholders(in: key).filter { $0 != "@" }
      guard counts.count == 1 else {
        return false
      }
      return ["en", "de"].contains { language in
        let localization = (entry["localizations"] as? [String: Any])?[language] as? [String: Any]
        return ((localization?["variations"] as? [String: Any])?["plural"]) == nil
      }
    }.keys.sorted()

    #expect(missing.isEmpty, "Without plural variants: \(missing)")
  }

  // MARK: - Helpers

  private static var resourcesFolder: URL {
    URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .appending(path: "FileCraft/Resources", directoryHint: .isDirectory)
  }

  private static func strings(in catalog: String) throws -> [String: [String: Any]] {
    let data = try Data(contentsOf: resourcesFolder.appending(path: catalog))
    let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    return try #require(root["strings"] as? [String: [String: Any]])
  }

  private static func translates(_ entry: [String: Any]) -> Bool {
    (entry["shouldTranslate"] as? Bool) != false
  }

  /// The string units of `language`, including those of plural variants.
  private static func units(of entry: [String: Any], language: String) -> [[String: Any]] {
    guard let localization = (entry["localizations"] as? [String: Any])?[language] as? [String: Any] else {
      return []
    }
    if let unit = localization["stringUnit"] as? [String: Any] {
      return [unit]
    }
    let plural = (localization["variations"] as? [String: Any])?["plural"] as? [String: Any] ?? [:]
    return plural.values.compactMap { ($0 as? [String: Any])?["stringUnit"] as? [String: Any] }
  }

  private static func germanValues(of entry: [String: Any]) -> [String] {
    units(of: entry, language: "de").compactMap { $0["value"] as? String }
  }

  /// The placeholder types of `text` in order of their positions, for example ["@", "lld"].
  private static func placeholders(in text: String) -> [String] {
    let pattern = /%(?:(\d+)\$)?(lld|ld|li|d|@)/
    var positional: [(Int, String)] = []
    var sequential: [String] = []
    for match in text.matches(of: pattern) {
      if let position = match.output.1.flatMap({ Int($0) }) {
        positional.append((position, String(match.output.2)))
      } else {
        sequential.append(String(match.output.2))
      }
    }
    return sequential + positional.sorted { $0.0 < $1.0 }.map(\.1)
  }
}

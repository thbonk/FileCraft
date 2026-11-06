/*
 * GermanLocalizationTests.swift
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

/// Resolves strings in German regardless of the system language of the test run.
internal struct GermanLocalizationTests {

  private let german = Locale(identifier: "de_DE")

  @Test
  internal func `Counts use the German plural forms`() {
    #expect(String(localized: LocalizedStringResource("\(1) items", locale: german)) == "1 Objekt")
    #expect(String(localized: LocalizedStringResource("\(3) items", locale: german)) == "3 Objekte")
    #expect(String(localized: LocalizedStringResource("\(1) errors", locale: german)) == "1 Fehler")
    #expect(String(localized: LocalizedStringResource("\(2) items match", locale: german)) == "2 Objekte passen")
  }

  @Test
  internal func `Inserted names are quoted with guillemets`() {
    let message = String(localized: LocalizedStringResource("Search for “\("Bericht")”", locale: german))

    #expect(message == "Suche nach »Bericht«")
  }

  @Test
  internal func `Helper failures have their own messages`() {
    let failures: [HelperFailure] = [.invalidPath, .invalidRequest, .versionMismatch(helperVersion: 1), .unknownJob, .protectedLocation, .notAuthorized]
    let messages = failures.compactMap { PrivilegedRunner.RunnerError.helper($0).errorDescription }

    #expect(Set(messages).count == failures.count)
  }
}

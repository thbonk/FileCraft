/*
 * PresentationTests.swift
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

internal struct PresentationTests {

  // MARK: - Properties

  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }()

  /// 2026-10-30 12:00 UTC.
  private let now = Date(timeIntervalSince1970: 1_793_361_600)

  // MARK: - Names

  @Test
  internal func `Always show extensions reveals a hidden extension`() {
    let item = FileItem(url: URL(filePath: "/tmp/Report.pdf"), localizedName: "Report", hasHiddenExtension: true)
    let localized = FileItem(url: URL(filePath: "/Applications"), localizedName: "Programme")

    #expect(ItemPresentation.displayName(of: item, alwaysShowsExtensions: false) == "Report")
    #expect(ItemPresentation.displayName(of: item, alwaysShowsExtensions: true) == "Report.pdf")
    #expect(ItemPresentation.displayName(of: localized, alwaysShowsExtensions: true) == "Programme")
  }

  @Test
  internal func `Permissions read like ls`() {
    #expect(ItemPresentation.symbolicPermissions(0o755) == "rwxr-xr-x")
    #expect(ItemPresentation.symbolicPermissions(0o640) == "rw-r-----")
  }

  // MARK: - Dates

  @Test
  internal func `Relative dates name today and yesterday`() {
    let locale = Locale(identifier: "en_GB")
    let english = Locale.Language(identifier: "en")
    let today = now.addingTimeInterval(-4_680)
    let yesterday = now.addingTimeInterval(-86_400)

    #expect(ItemPresentation.dateString(today, relative: true, locale: locale, calendar: calendar, now: now, language: english) == "Today, 10:42")
    #expect(ItemPresentation.dateString(yesterday, relative: true, locale: locale, calendar: calendar, now: now, language: english) == "Yesterday, 12:00")
  }

  @Test
  internal func `Relative dates are localized in German`() {
    let today = now.addingTimeInterval(-4_680)

    let text = ItemPresentation.dateString(
      today, relative: true, locale: Locale(identifier: "de_DE"), calendar: calendar, now: now,
      language: Locale.Language(identifier: "de"))

    #expect(text == "Heute, 10:42")
  }

  @Test
  internal func `Without relative dates the full date is shown`() {
    let text = ItemPresentation.dateString(now, relative: false, locale: Locale(identifier: "en_GB"), calendar: calendar, now: now)

    #expect(text.contains("2026"))
    #expect(text.contains("Today") == false)
  }

  // MARK: - Accounts and Failures

  @Test
  internal func `Account names resolve the current user`() {
    #expect(AccountNames.userName(for: getuid()) == NSUserName())
    #expect(AccountNames.userName(for: 4_294_000_000) == "4294000000")
  }

  @Test
  internal func `Load failures are classified`() {
    let noPermission = CocoaError(.fileReadNoPermission)
    let missing = CocoaError(.fileReadNoSuchFile)

    #expect(LoadFailure(error: noPermission).kind == .noPermission)
    #expect(LoadFailure(error: missing).kind == .notFound)
    #expect(LoadFailure(error: URLError(.badURL)).kind == .other)
  }
}

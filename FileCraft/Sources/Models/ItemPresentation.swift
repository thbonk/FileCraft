/*
 * ItemPresentation.swift
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

/// How the file views present names, permissions and dates.
nonisolated internal enum ItemPresentation {

  // MARK: - Names

  /// The localized name, or the name on disk when "Always show file extensions" overrides a hidden extension.
  internal static func displayName(of item: FileItem, alwaysShowsExtensions: Bool) -> String {
    alwaysShowsExtensions && item.hasHiddenExtension ? item.name : item.localizedName
  }

  // MARK: - Permissions

  /// The POSIX permissions in symbolic form, for example "rwxr-xr-x" for `0o755`.
  internal static func symbolicPermissions(_ mode: UInt16) -> String {
    let symbols: [(bit: UInt16, symbol: Character)] = [
      (0o400, "r"), (0o200, "w"), (0o100, "x"),
      (0o040, "r"), (0o020, "w"), (0o010, "x"),
      (0o004, "r"), (0o002, "w"), (0o001, "x"),
    ]
    return String(symbols.map { mode & $0.bit != 0 ? $0.symbol : "-" })
  }

  // MARK: - Dates

  /// A date as the list view shows it. With `relative`, dates of today and yesterday read
  /// "Today, 10:42" and "Yesterday, 09:13".
  ///
  /// - Parameter language: The language of "Today" and "Yesterday", or nil for the app's language.
  internal static func dateString(
    _ date: Date,
    relative: Bool,
    locale: Locale,
    calendar: Calendar = .current,
    now: Date = .now,
    language: Locale.Language? = nil
  ) -> String {
    if relative {
      let time = date.formatted(
        Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone))
      if calendar.isDate(date, inSameDayAs: now) {
        return String(format: LocalizedLookup.string("Today, %@", language: language), time)
      }
      if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
        return String(format: LocalizedLookup.string("Yesterday, %@", language: language), time)
      }
    }
    return date.formatted(
      Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone))
  }

  // MARK: - Accessibility

  /// The kind, size and modification date of `item` as one sentence, for example "PDF document, 128 KB, modified
  /// October 30, 2026 at 10:42". VoiceOver reads this as the value of the item's name.
  ///
  /// - Parameter language: The language of "modified", or nil for the app's current language.
  internal static func accessibilityDescription(
    of item: FileItem,
    sizeFormatter: ByteSizeFormatter,
    locale: Locale,
    language: Locale.Language? = nil
  ) -> String {
    var parts = [item.kind]
    if let size = item.size {
      parts.append(sizeFormatter.string(for: size))
    }
    if let modificationDate = item.modificationDate {
      let date = modificationDate.formatted(
        Date.FormatStyle(date: .long, time: .shortened, locale: locale, timeZone: .current))
      parts.append(String(format: LocalizedLookup.string("modified %@", language: language), date))
    }
    return parts.formatted(.list(type: .and).locale(locale))
  }
}

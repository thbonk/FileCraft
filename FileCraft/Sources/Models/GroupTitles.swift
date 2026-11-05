/*
 * GroupTitles.swift
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

/// The localized section headers of grouped file views.
nonisolated internal enum GroupTitles {

  /// The header of `group`, or nil for the single section of an ungrouped view.
  ///
  /// - Parameter language: The language of the header, or nil for the app's language.
  internal static func title(
    for group: ItemGroup,
    locale: Locale = .current,
    calendar: Calendar = .current,
    language: Locale.Language? = nil
  ) -> String? {
    func text(_ key: String) -> String {
      LocalizedLookup.string(key, language: language)
    }
    switch group {
    case .all:
      return nil
    case .kind(let kind):
      return kind.isEmpty ? text("Other Kinds") : kind
    case .date(let bucket):
      switch bucket {
      case .today:
        return text("Today")
      case .yesterday:
        return text("Yesterday")
      case .previousSevenDays:
        return text("Previous 7 Days")
      case .previousThirtyDays:
        return text("Previous 30 Days")
      case .month(let month):
        return monthName(month, locale: locale, calendar: calendar)
      case .year(let year):
        return String(year)
      case .unknown:
        return text("No Date")
      }
    case .size(let bucket):
      switch bucket {
      case .unknown:
        return text("Folders and Packages")
      case .zero:
        return text("Zero Bytes")
      case .belowOneMegabyte:
        return text("Less Than 1 MB")
      case .belowHundredMegabytes:
        return text("1 MB to 100 MB")
      case .belowOneGigabyte:
        return text("100 MB to 1 GB")
      case .oneGigabyteOrMore:
        return text("1 GB or More")
      }
    case .pathExtension(let pathExtension):
      return pathExtension.isEmpty ? text("No Extension") : pathExtension.uppercased()
    case .tag(let tag):
      return tag ?? text("No Tags")
    }
  }

  private static func monthName(_ month: Int, locale: Locale, calendar: Calendar) -> String {
    var calendar = calendar
    calendar.locale = locale
    let symbols = calendar.standaloneMonthSymbols
    return symbols.indices.contains(month - 1) ? symbols[month - 1] : String(month)
  }
}

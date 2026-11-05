/*
 * ItemSorting.swift
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

/// The attribute that items are sorted by.
nonisolated internal enum SortKey: String, CaseIterable, Codable, Sendable {
  case name
  case kind
  case size
  case dateModified
  case dateCreated
  case dateLastOpened
  case dateAdded
  case pathExtension
  case tags
}

/// A tab's sort settings.
nonisolated internal struct ItemSortOrder: Codable, Hashable, Sendable {
  internal var key: SortKey = .name
  internal var isAscending: Bool = true
  /// Keeps folders above files regardless of the sort key.
  internal var foldersFirst: Bool = true
}

/// The attribute that items are grouped by.
nonisolated internal enum GroupingKey: String, CaseIterable, Codable, Sendable {
  case none
  case kind
  case dateModified
  case dateCreated
  case size
  case pathExtension
  case tags
}

/// The date range a grouped item falls into.
nonisolated internal enum DateBucket: Hashable, Sendable {
  case today
  case yesterday
  case previousSevenDays
  case previousThirtyDays
  /// An earlier month of the current year.
  case month(Int)
  /// An earlier year.
  case year(Int)
  case unknown
}

/// The size range a grouped item falls into; sizes use decimal units.
nonisolated internal enum SizeBucket: Int, CaseIterable, Sendable {
  case unknown
  case zero
  case belowOneMegabyte
  case belowHundredMegabytes
  case belowOneGigabyte
  case oneGigabyteOrMore
}

/// The group a section of items belongs to. Localized titles are created by the views.
nonisolated internal enum ItemGroup: Hashable, Sendable {
  case all
  case kind(String)
  case date(DateBucket)
  case size(SizeBucket)
  case pathExtension(String)
  case tag(String?)
}

/// A group of items shown under one section header.
nonisolated internal struct ItemSection: Hashable, Sendable {
  internal let group: ItemGroup
  internal let items: [FileItem]
}

/// Sorts and groups items the way the file views present them.
nonisolated internal struct ItemSorting: Sendable {

  // MARK: - Properties

  internal var order: ItemSortOrder
  internal var locale: Locale
  internal var calendar: Calendar

  // MARK: - Initialization

  internal init(order: ItemSortOrder, locale: Locale = .current, calendar: Calendar = .current) {
    self.order = order
    self.locale = locale
    self.calendar = calendar
  }

  // MARK: - Sorting

  /// Returns `items` in display order. Ties are broken by name in ascending order.
  internal func sorted(_ items: [FileItem]) -> [FileItem] {
    items.sorted(by: precedes)
  }

  /// Compares names the way Finder does: numbers numerically, case ignored, collation of `locale`.
  internal func compareNames(_ lhs: String, _ rhs: String) -> ComparisonResult {
    lhs.compare(rhs, options: [.caseInsensitive, .numeric, .widthInsensitive, .forcedOrdering], range: nil, locale: locale)
  }

  // MARK: - Grouping

  /// Groups `items` into sections, each sorted with `order`.
  ///
  /// - Parameter now: The reference date for date groups.
  internal func sections(of items: [FileItem], groupedBy key: GroupingKey, now: Date = .now) -> [ItemSection] {
    guard key != .none else {
      return [ItemSection(group: .all, items: sorted(items))]
    }
    let grouped = Dictionary(grouping: items) { group(of: $0, by: key, now: now) }
    return grouped
      .map { ItemSection(group: $0.key, items: sorted($0.value)) }
      .sorted { precedes($0.group, $1.group) }
  }

  /// Returns the group of `item` for `key`.
  internal func group(of item: FileItem, by key: GroupingKey, now: Date) -> ItemGroup {
    switch key {
    case .none:
      .all
    case .kind:
      .kind(item.kind)
    case .dateModified:
      .date(bucket(for: item.modificationDate, now: now))
    case .dateCreated:
      .date(bucket(for: item.creationDate, now: now))
    case .size:
      .size(Self.bucket(forSize: item.size))
    case .pathExtension:
      .pathExtension(item.pathExtension.lowercased())
    case .tags:
      .tag(item.tagNames.first)
    }
  }

  /// Returns the date range of `date` relative to `now`.
  internal func bucket(for date: Date?, now: Date) -> DateBucket {
    guard let date else {
      return .unknown
    }
    if calendar.isDate(date, inSameDayAs: now) {
      return .today
    }
    let startOfToday = calendar.startOfDay(for: now)
    if let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday), date >= startOfYesterday {
      return .yesterday
    }
    if let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday), date >= sevenDaysAgo {
      return .previousSevenDays
    }
    if let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: startOfToday), date >= thirtyDaysAgo {
      return .previousThirtyDays
    }
    let year = calendar.component(.year, from: date)
    if year == calendar.component(.year, from: now) {
      return .month(calendar.component(.month, from: date))
    }
    return .year(year)
  }

  /// Returns the size range of `size` in bytes.
  internal static func bucket(forSize size: Int64?) -> SizeBucket {
    switch size {
    case nil:
      .unknown
    case .some(0):
      .zero
    case .some(..<1_000_000):
      .belowOneMegabyte
    case .some(..<100_000_000):
      .belowHundredMegabytes
    case .some(..<1_000_000_000):
      .belowOneGigabyte
    default:
      .oneGigabyteOrMore
    }
  }

  // MARK: - Private

  private func precedes(_ lhs: FileItem, _ rhs: FileItem) -> Bool {
    if order.foldersFirst {
      let lhsIsFolder = Self.isFolder(lhs)
      let rhsIsFolder = Self.isFolder(rhs)
      if lhsIsFolder != rhsIsFolder {
        return lhsIsFolder
      }
    }
    let result = compare(lhs, rhs, by: order.key)
    if result == .orderedSame {
      return compareNames(lhs.localizedName, rhs.localizedName) == .orderedAscending
    }
    return order.isAscending ? result == .orderedAscending : result == .orderedDescending
  }

  private func compare(_ lhs: FileItem, _ rhs: FileItem, by key: SortKey) -> ComparisonResult {
    switch key {
    case .name:
      compareNames(lhs.localizedName, rhs.localizedName)
    case .kind:
      compareNames(lhs.kind, rhs.kind)
    case .size:
      Self.compare(lhs.size, rhs.size)
    case .dateModified:
      Self.compare(lhs.modificationDate, rhs.modificationDate)
    case .dateCreated:
      Self.compare(lhs.creationDate, rhs.creationDate)
    case .dateLastOpened:
      Self.compare(lhs.lastOpenedDate, rhs.lastOpenedDate)
    case .dateAdded:
      Self.compare(lhs.addedDate, rhs.addedDate)
    case .pathExtension:
      compareNames(lhs.pathExtension, rhs.pathExtension)
    case .tags:
      compareNames(lhs.tagNames.first ?? "", rhs.tagNames.first ?? "")
    }
  }

  private func precedes(_ lhs: ItemGroup, _ rhs: ItemGroup) -> Bool {
    switch (lhs, rhs) {
    case (.kind(let lhsKind), .kind(let rhsKind)):
      compareNames(lhsKind, rhsKind) == .orderedAscending
    case (.pathExtension(let lhsExtension), .pathExtension(let rhsExtension)):
      compareNames(lhsExtension, rhsExtension) == .orderedAscending
    case (.tag(let lhsTag), .tag(let rhsTag)):
      Self.precedesTag(lhsTag, rhsTag, using: compareNames)
    case (.size(let lhsSize), .size(let rhsSize)):
      lhsSize.rawValue > rhsSize.rawValue
    case (.date(let lhsDate), .date(let rhsDate)):
      Self.recencyRank(of: lhsDate) < Self.recencyRank(of: rhsDate)
    default:
      false
    }
  }

  /// Folders sort before files; packages such as apps count as files.
  private static func isFolder(_ item: FileItem) -> Bool {
    item.isDirectory && item.isPackage == false
  }

  /// Orders optional values with nil first.
  private static func compare<Value: Comparable>(_ lhs: Value?, _ rhs: Value?) -> ComparisonResult {
    switch (lhs, rhs) {
    case (nil, nil):
      .orderedSame
    case (nil, _):
      .orderedAscending
    case (_, nil):
      .orderedDescending
    case (.some(let lhsValue), .some(let rhsValue)):
      lhsValue < rhsValue ? .orderedAscending : (lhsValue > rhsValue ? .orderedDescending : .orderedSame)
    }
  }

  /// Untagged items come last.
  private static func precedesTag(
    _ lhs: String?,
    _ rhs: String?,
    using compareNames: (String, String) -> ComparisonResult
  ) -> Bool {
    switch (lhs, rhs) {
    case (.some(let lhsTag), .some(let rhsTag)):
      compareNames(lhsTag, rhsTag) == .orderedAscending
    case (.some, nil):
      true
    default:
      false
    }
  }

  /// Lower ranks are more recent; unknown dates come last.
  private static func recencyRank(of bucket: DateBucket) -> Int {
    switch bucket {
    case .today:
      0
    case .yesterday:
      1
    case .previousSevenDays:
      2
    case .previousThirtyDays:
      3
    case .month(let month):
      100 + (12 - month)
    case .year(let year):
      10_000 - year
    case .unknown:
      Int.max
    }
  }
}

/*
 * ItemSortingTests.swift
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

internal struct ItemSortingTests {

  // MARK: - Properties

  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }()

  /// 2026-10-30 12:00 UTC.
  private let now = Date(timeIntervalSince1970: 1_793_361_600)

  // MARK: - Sorting

  @Test
  internal func `Names with numbers sort numerically`() {
    let sorting = ItemSorting(order: ItemSortOrder(), locale: Locale(identifier: "en_US"))

    let names = sorting.sorted([file("File 10"), file("File 2"), file("File 1")]).map(\.name)

    #expect(names == ["File 1", "File 2", "File 10"])
  }

  @Test
  internal func `Umlauts sort with their base letters in German`() {
    let sorting = ItemSorting(order: ItemSortOrder(), locale: Locale(identifier: "de_DE"))

    let names = sorting.sorted([file("Zebra"), file("Äpfel"), file("Birnen")]).map(\.name)

    #expect(names == ["Äpfel", "Birnen", "Zebra"])
  }

  @Test
  internal func `Folders stay first when sorting by date modified`() {
    let order = ItemSortOrder(key: .dateModified, isAscending: false, foldersFirst: true)
    let sorting = ItemSorting(order: order, locale: Locale(identifier: "en_US"))
    let items = [
      file("new.txt", modified: now),
      folder("Old Folder", modified: now.addingTimeInterval(-86_400 * 10)),
      file("old.txt", modified: now.addingTimeInterval(-86_400 * 5)),
      folder("New Folder", modified: now.addingTimeInterval(-60)),
    ]

    let names = sorting.sorted(items).map(\.name)

    #expect(names == ["New Folder", "Old Folder", "new.txt", "old.txt"])
  }

  @Test
  internal func `Apps sort as files when folders come first`() {
    let sorting = ItemSorting(order: ItemSortOrder(), locale: Locale(identifier: "en_US"))
    let app = FileItem(url: URL(filePath: "/Applications/Alpha.app"), isDirectory: true, isPackage: true)

    let names = sorting.sorted([app, folder("Zulu")]).map(\.name)

    #expect(names == ["Zulu", "Alpha.app"])
  }

  @Test
  internal func `Descending size order keeps the name as tiebreaker`() {
    let order = ItemSortOrder(key: .size, isAscending: false, foldersFirst: false)
    let sorting = ItemSorting(order: order, locale: Locale(identifier: "en_US"))

    let names = sorting.sorted([file("b", size: 10), file("a", size: 10), file("c", size: 99)]).map(\.name)

    #expect(names == ["c", "a", "b"])
  }

  // MARK: - Grouping

  @Test
  internal func `Grouping by kind creates alphabetical sections`() {
    let sorting = ItemSorting(order: ItemSortOrder(), locale: Locale(identifier: "en_US"))
    let items = [file("b.pdf", kind: "PDF document"), file("a.jpg", kind: "JPEG image"), file("c.pdf", kind: "PDF document")]

    let sections = sorting.sections(of: items, groupedBy: .kind, now: now)

    #expect(sections.map(\.group) == [.kind("JPEG image"), .kind("PDF document")])
    #expect(sections.last?.items.map(\.name) == ["b.pdf", "c.pdf"])
  }

  /// Days before `now` and the bucket they fall into.
  nonisolated private static let dateCases: [(daysAgo: Double, bucket: DateBucket)] = [
    (0, .today),
    (1, .yesterday),
    (4, .previousSevenDays),
    (20, .previousThirtyDays),
    (120, .month(7)),
    (400, .year(2025)),
  ]

  @Test(arguments: dateCases)
  internal func `Dates fall into recency buckets`(daysAgo: Double, expected: DateBucket) {
    let sorting = ItemSorting(order: ItemSortOrder(), locale: Locale(identifier: "en_US"), calendar: calendar)
    let date = now.addingTimeInterval(-daysAgo * 86_400)

    #expect(sorting.bucket(for: date, now: now) == expected)
  }

  @Test
  internal func `Date sections start with the most recent`() {
    let sorting = ItemSorting(order: ItemSortOrder(), locale: Locale(identifier: "en_US"), calendar: calendar)
    let items = [
      file("old", modified: now.addingTimeInterval(-86_400 * 400)),
      file("today", modified: now),
      file("week", modified: now.addingTimeInterval(-86_400 * 4)),
    ]

    let groups = sorting.sections(of: items, groupedBy: .dateModified, now: now).map(\.group)

    #expect(groups == [.date(.today), .date(.previousSevenDays), .date(.year(2025))])
  }

  /// Sizes in bytes and the bucket they fall into.
  nonisolated private static let sizeCases: [(size: Int64?, bucket: SizeBucket)] = [
    (nil, .unknown),
    (0, .zero),
    (999_999, .belowOneMegabyte),
    (1_000_000, .belowHundredMegabytes),
    (500_000_000, .belowOneGigabyte),
    (1_000_000_000, .oneGigabyteOrMore),
  ]

  @Test(arguments: sizeCases)
  internal func `Sizes fall into decimal size buckets`(size: Int64?, expected: SizeBucket) {
    #expect(ItemSorting.bucket(forSize: size) == expected)
  }

  // MARK: - Helpers

  private func file(_ name: String, kind: String = "", size: Int64? = 1, modified: Date? = nil) -> FileItem {
    FileItem(url: URL(filePath: "/tmp/\(name)"), kind: kind, size: size, modificationDate: modified)
  }

  private func folder(_ name: String, modified: Date? = nil) -> FileItem {
    FileItem(url: URL(filePath: "/tmp/\(name)", directoryHint: .isDirectory), isDirectory: true, modificationDate: modified)
  }
}

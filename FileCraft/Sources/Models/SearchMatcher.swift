/*
 * SearchMatcher.swift
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
import UniformTypeIdentifiers

/// Decides which items a search finds, from the search text, the criteria and the hidden items option.
///
/// Text matching ignores case and diacritics. The Contents criterion is left to Spotlight and always matches here.
nonisolated internal struct SearchMatcher: Sendable {

  // MARK: - Properties

  private let parameters: SearchParameters
  private let criteria: [SearchCriterion]
  private let now: Date
  private let calendar: Calendar
  private let unitBase: Double
  /// The compiled patterns of "matches regular expression" rows by row; rows with invalid patterns match nothing.
  private let patterns: [UUID: NamePattern]

  private static let textOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

  // MARK: - Initialization

  internal init(parameters: SearchParameters, now: Date = .now, calendar: Calendar = .current, sizeUnits: SizeUnits = .decimal) {
    self.parameters = parameters
    criteria = parameters.effectiveCriteria
    self.now = now
    self.calendar = calendar
    unitBase = sizeUnits == .binary ? 1024 : 1000
    var patterns: [UUID: NamePattern] = [:]
    for criterion in criteria where criterion.attribute == .name && criterion.nameOperator == .matchesRegularExpression {
      patterns[criterion.id] = try? NamePattern(criterion.text, syntax: .regularExpression)
    }
    self.patterns = patterns
  }

  // MARK: - Matching

  /// Whether the quick filter `text` matches `item`: its displayed name contains the text, ignoring case and
  /// diacritics.
  internal static func filterMatches(_ item: FileItem, text: String) -> Bool {
    text.isEmpty || item.localizedName.range(of: text, options: textOptions) != nil
  }

  /// Whether an item can match by its names alone; the search uses it to skip items before reading their metadata.
  internal func mayMatch(name: String, localizedName: String) -> Bool {
    guard parameters.includesHiddenItems || name.hasPrefix(".") == false else {
      return false
    }
    return matchesText(name: name, localizedName: localizedName)
  }

  internal func matches(_ item: FileItem) -> Bool {
    guard parameters.includesHiddenItems || (item.isHidden == false && item.name.hasPrefix(".") == false) else {
      return false
    }
    guard matchesText(name: item.name, localizedName: item.localizedName) else {
      return false
    }
    return criteria.allSatisfy { matches(item, criterion: $0) }
  }

  /// The earliest and the end of the dates a date row accepts; nil bounds are open.
  internal static func dateRange(of criterion: SearchCriterion, now: Date, calendar: Calendar) -> (from: Date?, to: Date?) {
    switch criterion.dateCondition {
    case .today:
      let start = calendar.startOfDay(for: now)
      return (start, calendar.date(byAdding: .day, value: 1, to: start))
    case .withinLast:
      let component: Calendar.Component =
        switch criterion.dateUnit {
        case .days:
          .day
        case .weeks:
          .weekOfYear
        case .months:
          .month
        }
      return (calendar.date(byAdding: component, value: -criterion.dateAmount, to: now), nil)
    case .before:
      return (nil, calendar.startOfDay(for: criterion.date))
    case .after:
      let start = calendar.startOfDay(for: criterion.date)
      return (calendar.date(byAdding: .day, value: 1, to: start), nil)
    }
  }

  /// The number of bytes a size row compares with.
  internal static func byteCount(of criterion: SearchCriterion, sizeUnits: SizeUnits) -> Double {
    let base: Double = sizeUnits == .binary ? 1024 : 1000
    return criterion.sizeValue * pow(base, Double(criterion.sizeUnit.exponent))
  }

  /// The content type a Kind row stands for.
  internal static func contentType(of kind: SearchCriterion.ItemKind) -> UTType {
    switch kind {
    case .folder:
      .folder
    case .application:
      .application
    case .document:
      .content
    case .image:
      .image
    case .movie:
      .movie
    case .audio:
      .audio
    case .pdf:
      .pdf
    case .text:
      .text
    case .archive:
      .archive
    }
  }

  // MARK: - Private

  private func matchesText(name: String, localizedName: String) -> Bool {
    let text = parameters.text
    guard text.isEmpty == false else {
      return true
    }
    return localizedName.range(of: text, options: Self.textOptions) != nil || name.range(of: text, options: Self.textOptions) != nil
  }

  private func matches(_ item: FileItem, criterion: SearchCriterion) -> Bool {
    switch criterion.attribute {
    case .name:
      matchesName(item, criterion: criterion)
    case .kind:
      matchesKind(item, kind: criterion.kind)
    case .pathExtension:
      item.pathExtension.compare(Self.normalizedExtension(criterion.text), options: Self.textOptions) == .orderedSame
    case .dateModified:
      matchesDate(item.modificationDate, criterion: criterion)
    case .dateCreated:
      matchesDate(item.creationDate, criterion: criterion)
    case .size:
      matchesSize(item.size, criterion: criterion)
    case .tags:
      item.tagNames.contains { $0.range(of: criterion.text, options: Self.textOptions) != nil }
    case .contents:
      true
    }
  }

  private func matchesName(_ item: FileItem, criterion: SearchCriterion) -> Bool {
    let text = criterion.text
    return [item.localizedName, item.name].contains { name in
      switch criterion.nameOperator {
      case .contains:
        name.range(of: text, options: Self.textOptions) != nil
      case .beginsWith:
        name.range(of: text, options: Self.textOptions.union(.anchored)) != nil
      case .endsWith:
        name.range(of: text, options: Self.textOptions.union([.anchored, .backwards])) != nil
      case .isEqual:
        name.compare(text, options: Self.textOptions) == .orderedSame
      case .matchesRegularExpression:
        patterns[criterion.id]?.matches(name) ?? false
      }
    }
  }

  private func matchesKind(_ item: FileItem, kind: SearchCriterion.ItemKind) -> Bool {
    switch kind {
    case .folder:
      return item.isDirectory && item.isPackage == false
    case .document:
      let type = item.contentType ?? .data
      return item.isDirectory == false && type.conforms(to: .application) == false
    default:
      guard let type = item.contentType else {
        return false
      }
      return type.conforms(to: Self.contentType(of: kind))
    }
  }

  private func matchesDate(_ date: Date?, criterion: SearchCriterion) -> Bool {
    guard let date else {
      return false
    }
    let range = Self.dateRange(of: criterion, now: now, calendar: calendar)
    if let from = range.from, date < from {
      return false
    }
    if let to = range.to, date >= to {
      return false
    }
    return true
  }

  private func matchesSize(_ size: Int64?, criterion: SearchCriterion) -> Bool {
    guard let size else {
      return false
    }
    let limit = criterion.sizeValue * pow(unitBase, Double(criterion.sizeUnit.exponent))
    switch criterion.sizeComparison {
    case .greaterThan:
      return Double(size) > limit
    case .lessThan:
      return Double(size) < limit
    }
  }

  /// The extension without a leading dot, as users often type it.
  internal static func normalizedExtension(_ text: String) -> String {
    text.hasPrefix(".") ? String(text.dropFirst()) : text
  }
}

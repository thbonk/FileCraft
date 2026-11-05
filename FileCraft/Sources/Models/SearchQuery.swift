/*
 * SearchQuery.swift
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

/// Where the search field looks.
nonisolated internal enum SearchScope: String, CaseIterable, Codable, Hashable, Sendable {
  /// Filters the items of the current folder as the user types.
  case thisFolder
  /// Searches the current folder and all folders below it by name.
  case subfolders
  /// Searches the Spotlight index of the whole Mac.
  case thisMac
}

/// One row of the search criteria, combined with the other rows by AND.
///
/// The fields of all attributes are kept, so that switching the attribute of a row keeps what the user entered;
/// only the fields of `attribute` take part in matching.
nonisolated internal struct SearchCriterion: Identifiable, Codable, Hashable, Sendable {

  // MARK: - Types

  internal enum Attribute: String, CaseIterable, Codable, Hashable, Sendable {
    case name
    case kind
    case pathExtension
    case dateModified
    case dateCreated
    case size
    case tags
    /// The text inside documents; only Spotlight can search it.
    case contents
  }

  internal enum NameOperator: String, CaseIterable, Codable, Hashable, Sendable {
    case contains
    case beginsWith
    case endsWith
    case isEqual
    case matchesRegularExpression
  }

  internal enum ItemKind: String, CaseIterable, Codable, Hashable, Sendable {
    case folder
    case application
    case document
    case image
    case movie
    case audio
    case pdf
    case text
    case archive
  }

  internal enum DateCondition: String, CaseIterable, Codable, Hashable, Sendable {
    case today
    case withinLast
    case before
    case after
  }

  internal enum DateUnit: String, CaseIterable, Codable, Hashable, Sendable {
    case days
    case weeks
    case months
  }

  internal enum SizeComparison: String, CaseIterable, Codable, Hashable, Sendable {
    case greaterThan
    case lessThan
  }

  internal enum SizeUnit: String, CaseIterable, Codable, Hashable, Sendable {
    case kilobytes
    case megabytes
    case gigabytes

    /// The power of the unit base: 1 for KB, 2 for MB, 3 for GB.
    internal var exponent: Int {
      switch self {
      case .kilobytes:
        1
      case .megabytes:
        2
      case .gigabytes:
        3
      }
    }
  }

  // MARK: - Properties

  internal var id = UUID()
  internal var attribute: Attribute
  internal var nameOperator: NameOperator = .contains
  /// The value of the Name, Extension, Tags and Contents criteria.
  internal var text = ""
  internal var kind: ItemKind = .document
  internal var dateCondition: DateCondition = .withinLast
  internal var dateAmount = 7
  internal var dateUnit: DateUnit = .days
  internal var date = Date.now
  internal var sizeComparison: SizeComparison = .greaterThan
  internal var sizeValue: Double = 1
  internal var sizeUnit: SizeUnit = .megabytes

  /// Whether the row restricts the results; rows without a value are ignored.
  internal var isComplete: Bool {
    switch attribute {
    case .name, .pathExtension, .tags, .contents:
      text.isEmpty == false
    case .dateModified, .dateCreated:
      dateCondition != .withinLast || dateAmount > 0
    case .kind, .size:
      true
    }
  }

  /// The criterion without its identity, for comparing what two rows match.
  internal var rule: SearchCriterion {
    switch attribute {
    case .name:
      SearchCriterion(id: Self.ruleID, attribute: .name, nameOperator: nameOperator, text: text, date: .distantPast)
    case .pathExtension, .tags, .contents:
      SearchCriterion(id: Self.ruleID, attribute: attribute, text: text, date: .distantPast)
    case .kind:
      SearchCriterion(id: Self.ruleID, attribute: .kind, kind: kind, date: .distantPast)
    case .dateModified, .dateCreated:
      SearchCriterion(
        id: Self.ruleID, attribute: attribute, dateCondition: dateCondition, dateAmount: dateAmount, dateUnit: dateUnit,
        date: dateCondition == .before || dateCondition == .after ? date : .distantPast)
    case .size:
      SearchCriterion(
        id: Self.ruleID, attribute: .size, date: .distantPast, sizeComparison: sizeComparison, sizeValue: sizeValue,
        sizeUnit: sizeUnit)
    }
  }

  private static let ruleID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

  // MARK: - Initialization

  internal init(
    id: UUID = UUID(),
    attribute: Attribute,
    nameOperator: NameOperator = .contains,
    text: String = "",
    kind: ItemKind = .document,
    dateCondition: DateCondition = .withinLast,
    dateAmount: Int = 7,
    dateUnit: DateUnit = .days,
    date: Date = .now,
    sizeComparison: SizeComparison = .greaterThan,
    sizeValue: Double = 1,
    sizeUnit: SizeUnit = .megabytes
  ) {
    self.id = id
    self.attribute = attribute
    self.nameOperator = nameOperator
    self.text = text
    self.kind = kind
    self.dateCondition = dateCondition
    self.dateAmount = dateAmount
    self.dateUnit = dateUnit
    self.date = date
    self.sizeComparison = sizeComparison
    self.sizeValue = sizeValue
    self.sizeUnit = sizeUnit
  }
}

/// What a search looks for, apart from where it started: scope, text, criteria and options.
nonisolated internal struct SearchParameters: Codable, Hashable, Sendable {

  internal var scope: SearchScope = .thisFolder
  /// The text of the search field; items match when their name contains it.
  internal var text = ""
  internal var criteria: [SearchCriterion] = []
  internal var includesHiddenItems = false
  internal var includesPackageContents = false

  /// The criteria that restrict the results; the Contents criterion counts only for This Mac.
  internal var effectiveCriteria: [SearchCriterion] {
    criteria.filter { criterion in
      criterion.isComplete && (criterion.attribute != .contents || scope == .thisMac)
    }
  }

  /// Whether there is anything to search for.
  internal var isEmpty: Bool {
    text.isEmpty && effectiveCriteria.isEmpty
  }

  /// The parameters without row identities, so that equal searches compare equal, as recent searches need.
  internal var rule: SearchParameters {
    var rule = self
    rule.criteria = criteria.map(\.rule)
    return rule
  }
}

/// A search shown as a tab location: the parameters and the folder the search started in.
nonisolated internal struct SearchQuery: Codable, Hashable, Sendable {

  internal var parameters: SearchParameters
  /// The folder the search started in, which Subfolders searches look below; nil when it started at a virtual location.
  internal var origin: FileReference?

  internal init(parameters: SearchParameters, origin: FileReference?) {
    self.parameters = parameters
    self.origin = origin
  }
}

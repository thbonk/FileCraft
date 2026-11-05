/*
 * SpotlightPredicate.swift
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

/// Builds the `NSMetadataQuery` predicate of a This Mac search.
///
/// The predicate narrows the Spotlight results; `SearchMatcher` checks the found items afterwards, which also covers
/// what Spotlight cannot express, such as regular expressions.
nonisolated internal enum SpotlightPredicate {

  // MARK: - Properties

  private static let nameKey = NSMetadataItemFSNameKey
  private static let displayNameKey = NSMetadataItemDisplayNameKey
  private static let contentTypeKey = NSMetadataItemContentTypeKey
  private static let contentTypeTreeKey = NSMetadataItemContentTypeTreeKey
  private static let modificationDateKey = NSMetadataItemFSContentChangeDateKey
  private static let creationDateKey = NSMetadataItemFSCreationDateKey
  private static let sizeKey = NSMetadataItemFSSizeKey
  private static let tagsKey = "kMDItemUserTags"
  private static let textContentKey = NSMetadataItemTextContentKey

  // MARK: - Building

  /// The predicate for `parameters`; a search without restrictions matches every named item.
  internal static func predicate(
    for parameters: SearchParameters,
    now: Date = .now,
    calendar: Calendar = .current,
    sizeUnits: SizeUnits = .decimal
  ) -> NSPredicate {
    var predicates: [NSPredicate] = []
    if parameters.text.isEmpty == false {
      predicates.append(nameContains(parameters.text))
    }
    for criterion in parameters.effectiveCriteria {
      if let predicate = predicate(for: criterion, now: now, calendar: calendar, sizeUnits: sizeUnits) {
        predicates.append(predicate)
      }
    }
    guard predicates.isEmpty == false else {
      return NSPredicate(format: "%K LIKE %@", nameKey, "*")
    }
    return predicates.count == 1 ? predicates[0] : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
  }

  /// Escapes the wildcard characters of a `LIKE` pattern.
  internal static func escapedForLike(_ text: String) -> String {
    var result = ""
    for character in text {
      if character == "*" || character == "?" || character == "\\" {
        result.append("\\")
      }
      result.append(character)
    }
    return result
  }

  // MARK: - Private

  private static func predicate(for criterion: SearchCriterion, now: Date, calendar: Calendar, sizeUnits: SizeUnits) -> NSPredicate? {
    switch criterion.attribute {
    case .name:
      return namePredicate(criterion)
    case .kind:
      if criterion.kind == .folder {
        return NSPredicate(format: "%K == %@", contentTypeKey, SearchMatcher.contentType(of: .folder).identifier)
      }
      return NSPredicate(format: "%K == %@", contentTypeTreeKey, SearchMatcher.contentType(of: criterion.kind).identifier)
    case .pathExtension:
      let pathExtension = SearchMatcher.normalizedExtension(criterion.text)
      return NSPredicate(format: "%K LIKE[c] %@", nameKey, "*." + escapedForLike(pathExtension))
    case .dateModified:
      return datePredicate(key: modificationDateKey, criterion: criterion, now: now, calendar: calendar)
    case .dateCreated:
      return datePredicate(key: creationDateKey, criterion: criterion, now: now, calendar: calendar)
    case .size:
      let bytes = NSNumber(value: SearchMatcher.byteCount(of: criterion, sizeUnits: sizeUnits))
      let comparison = criterion.sizeComparison == .greaterThan ? ">" : "<"
      return NSPredicate(format: "%K \(comparison) %@", sizeKey, bytes)
    case .tags:
      return NSPredicate(format: "%K LIKE[cd] %@", tagsKey, "*" + escapedForLike(criterion.text) + "*")
    case .contents:
      return NSPredicate(format: "%K LIKE[cd] %@", textContentKey, "*" + escapedForLike(criterion.text) + "*")
    }
  }

  private static func nameContains(_ text: String) -> NSPredicate {
    let pattern = "*" + escapedForLike(text) + "*"
    return NSCompoundPredicate(orPredicateWithSubpredicates: [
      NSPredicate(format: "%K LIKE[cd] %@", nameKey, pattern),
      NSPredicate(format: "%K LIKE[cd] %@", displayNameKey, pattern),
    ])
  }

  /// Regular expressions have no Spotlight equivalent; `SearchMatcher` checks them on the results.
  private static func namePredicate(_ criterion: SearchCriterion) -> NSPredicate? {
    let text = escapedForLike(criterion.text)
    switch criterion.nameOperator {
    case .contains:
      return nameContains(criterion.text)
    case .beginsWith:
      return NSPredicate(format: "%K LIKE[cd] %@", nameKey, text + "*")
    case .endsWith:
      return NSPredicate(format: "%K LIKE[cd] %@", nameKey, "*" + text)
    case .isEqual:
      return NSPredicate(format: "%K ==[cd] %@", nameKey, criterion.text)
    case .matchesRegularExpression:
      return nil
    }
  }

  private static func datePredicate(key: String, criterion: SearchCriterion, now: Date, calendar: Calendar) -> NSPredicate? {
    let range = SearchMatcher.dateRange(of: criterion, now: now, calendar: calendar)
    var predicates: [NSPredicate] = []
    if let from = range.from {
      predicates.append(NSPredicate(format: "%K >= %@", key, from as NSDate))
    }
    if let to = range.to {
      predicates.append(NSPredicate(format: "%K < %@", key, to as NSDate))
    }
    switch predicates.count {
    case 0:
      return nil
    case 1:
      return predicates[0]
    default:
      return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
  }
}

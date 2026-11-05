/*
 * RenameEngine.swift
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

/// What the rename rules need to know about one item.
nonisolated internal struct RenameInput: Hashable, Sendable {
  internal let name: String
  /// Whether the name can have an extension; folders other than packages have none.
  internal let hasExtension: Bool
  internal let creationDate: Date?
  internal let modificationDate: Date?

  internal init(name: String, hasExtension: Bool = true, creationDate: Date? = nil, modificationDate: Date? = nil) {
    self.name = name
    self.hasExtension = hasExtension
    self.creationDate = creationDate
    self.modificationDate = modificationDate
  }

  internal init(item: FileItem) {
    self.init(
      name: item.name,
      hasExtension: item.isDirectory == false || item.isPackage,
      creationDate: item.creationDate,
      modificationDate: item.modificationDate)
  }
}

/// Applies the enabled rename rules, in order, to item names.
///
/// Regular expressions and date formatters are prepared once, so that previews of many items stay fast.
nonisolated internal struct RenameEngine {

  // MARK: - Properties

  private let rules: [RenameRule]
  private let expressions: [UUID: NSRegularExpression]
  private let dateFormatters: [UUID: DateFormatter]
  private let now: Date
  private let locale: Locale

  /// The enabled Regular Expression rules whose pattern is not valid; they leave names unchanged.
  internal let invalidRuleIDs: Set<UUID>

  // MARK: - Initialization

  internal init(rules: [RenameRule], now: Date = .now, locale: Locale = .current, timeZone: TimeZone = .current) {
    let enabled = rules.filter(\.isEnabled)
    self.rules = enabled
    self.now = now
    self.locale = locale
    var expressions: [UUID: NSRegularExpression] = [:]
    var invalid = Set<UUID>()
    var formatters: [UUID: DateFormatter] = [:]
    for rule in enabled {
      switch rule.kind {
      case .regularExpression where rule.findText.isEmpty == false:
        let options: NSRegularExpression.Options = rule.isCaseSensitive ? [] : [.caseInsensitive]
        if let expression = try? NSRegularExpression(pattern: rule.findText, options: options) {
          expressions[rule.id] = expression
        } else {
          invalid.insert(rule.id)
        }
      case .date:
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = rule.dateFormat
        formatters[rule.id] = formatter
      default:
        break
      }
    }
    self.expressions = expressions
    dateFormatters = formatters
    invalidRuleIDs = invalid
  }

  // MARK: - Renaming

  /// The new name of `input`, the item at `index` in the batch's order, which sequence numbers count.
  internal func newName(for input: RenameInput, at index: Int) -> String {
    var name = input.name
    for rule in rules {
      name = apply(rule, to: name, input: input, index: index)
    }
    return name
  }

  /// Splits `name` into the name without extension and the extension, which is nil when there is none.
  internal static func split(_ name: String, hasExtension: Bool) -> (base: String, pathExtension: String?) {
    guard hasExtension, let dot = name.lastIndex(of: "."), dot != name.startIndex, name.index(after: dot) != name.endIndex else {
      return (name, nil)
    }
    return (String(name[..<dot]), String(name[name.index(after: dot)...]))
  }

  // MARK: - Private

  private func apply(_ rule: RenameRule, to name: String, input: RenameInput, index: Int) -> String {
    let parts = Self.split(name, hasExtension: input.hasExtension)
    if rule.kind == .changeExtension {
      guard input.hasExtension else {
        return name
      }
      return Self.join(parts.base, changedExtension(parts.pathExtension, rule: rule))
    }
    switch rule.target {
    case .nameWithoutExtension:
      return Self.join(transform(parts.base, rule: rule, input: input, index: index), parts.pathExtension)
    case .extensionOnly:
      guard let pathExtension = parts.pathExtension else {
        return name
      }
      return Self.join(parts.base, transform(pathExtension, rule: rule, input: input, index: index))
    case .fullName:
      return transform(name, rule: rule, input: input, index: index)
    }
  }

  private static func join(_ base: String, _ pathExtension: String?) -> String {
    guard let pathExtension, pathExtension.isEmpty == false else {
      return base
    }
    return base + "." + pathExtension
  }

  private func changedExtension(_ pathExtension: String?, rule: RenameRule) -> String? {
    switch rule.extensionChange {
    case .replace:
      let replacement = rule.newExtension.hasPrefix(".") ? String(rule.newExtension.dropFirst()) : rule.newExtension
      return replacement.isEmpty ? pathExtension : replacement
    case .remove:
      return nil
    case .lowercase:
      return pathExtension?.lowercased()
    }
  }

  private func transform(_ text: String, rule: RenameRule, input: RenameInput, index: Int) -> String {
    switch rule.kind {
    case .replaceText:
      replaceText(in: text, rule: rule)
    case .regularExpression:
      replaceMatches(in: text, rule: rule)
    case .insertText:
      insert(rule.insertText, into: text, at: rule.insertPosition, position: rule.position)
    case .removeCharacters:
      removeCharacters(from: text, rule: rule)
    case .changeCase:
      changeCase(of: text, to: rule.caseStyle)
    case .sequenceNumber:
      attach(sequenceNumber(at: index, rule: rule), to: text, rule: rule)
    case .date:
      attach(dateText(for: input, rule: rule), to: text, rule: rule)
    case .changeExtension:
      text
    }
  }

  private func replaceText(in text: String, rule: RenameRule) -> String {
    guard rule.findText.isEmpty == false else {
      return text
    }
    let options: String.CompareOptions = rule.isCaseSensitive ? [] : [.caseInsensitive]
    switch rule.occurrence {
    case .all:
      return text.replacingOccurrences(of: rule.findText, with: rule.replacementText, options: options)
    case .first, .last:
      let searchOptions = rule.occurrence == .last ? options.union(.backwards) : options
      guard let range = text.range(of: rule.findText, options: searchOptions) else {
        return text
      }
      return text.replacingCharacters(in: range, with: rule.replacementText)
    }
  }

  private func replaceMatches(in text: String, rule: RenameRule) -> String {
    guard let expression = expressions[rule.id] else {
      return text
    }
    let range = NSRange(location: 0, length: text.utf16.count)
    switch rule.occurrence {
    case .all:
      return expression.stringByReplacingMatches(in: text, range: range, withTemplate: rule.replacementText)
    case .first, .last:
      let matches = expression.matches(in: text, range: range)
      guard let match = rule.occurrence == .first ? matches.first : matches.last, let matchRange = Range(match.range, in: text) else {
        return text
      }
      let replacement = expression.replacementString(for: match, in: text, offset: 0, template: rule.replacementText)
      return text.replacingCharacters(in: matchRange, with: replacement)
    }
  }

  private func insert(_ insertion: String, into text: String, at insertPosition: RenameRule.InsertPosition, position: Int) -> String {
    switch insertPosition {
    case .prefix:
      return insertion + text
    case .suffix:
      return text + insertion
    case .atPosition:
      var result = text
      let offset = min(max(position, 0), text.count)
      result.insert(contentsOf: insertion, at: result.index(result.startIndex, offsetBy: offset))
      return result
    }
  }

  private func removeCharacters(from text: String, rule: RenameRule) -> String {
    let count = max(rule.removalCount, 0)
    switch rule.removalPosition {
    case .fromStart:
      return String(text.dropFirst(count))
    case .fromEnd:
      return String(text.dropLast(count))
    case .atPosition:
      let start = min(max(rule.position, 0), text.count)
      let end = min(start + count, text.count)
      var result = text
      result.removeSubrange(result.index(result.startIndex, offsetBy: start)..<result.index(result.startIndex, offsetBy: end))
      return result
    }
  }

  private func changeCase(of text: String, to style: RenameRule.CaseStyle) -> String {
    switch style {
    case .lowercase:
      return text.lowercased(with: locale)
    case .uppercase:
      return text.uppercased(with: locale)
    case .titleCase:
      return text.capitalized(with: locale)
    case .sentenceCase:
      let lowercased = text.lowercased(with: locale)
      guard let first = lowercased.first else {
        return lowercased
      }
      return String(first).uppercased(with: locale) + lowercased.dropFirst()
    }
  }

  private func sequenceNumber(at index: Int, rule: RenameRule) -> String {
    let number = rule.sequenceStart + index * rule.sequenceStep
    let digits = String(abs(number))
    let padding = String(repeating: "0", count: max(rule.sequenceDigits - digits.count, 0))
    return (number < 0 ? "-" : "") + padding + digits
  }

  private func dateText(for input: RenameInput, rule: RenameRule) -> String? {
    let date: Date? =
      switch rule.dateSource {
      case .created:
        input.creationDate
      case .modified:
        input.modificationDate
      case .current:
        now
      }
    guard let date, let formatter = dateFormatters[rule.id] else {
      return nil
    }
    return formatter.string(from: date)
  }

  /// Puts `value` before or after `text`, separated by the rule's separator; a missing value changes nothing.
  private func attach(_ value: String?, to text: String, rule: RenameRule) -> String {
    guard let value, value.isEmpty == false else {
      return text
    }
    switch rule.endPosition {
    case .prefix:
      return value + rule.separator + text
    case .suffix:
      return text + rule.separator + value
    }
  }
}

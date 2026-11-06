/*
 * TagLibrary.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-03.
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

import AppKit
import CoreServices
import Foundation

/// Finder tags: the user's tag list, the items carrying a tag, and tagging items.
///
/// macOS has no public API for the tag list Finder shows, so the standard color tags come from `NSWorkspace` and
/// other tags are the ones Spotlight finds on items, as the risks section of the design describes.
nonisolated internal enum TagLibrary {

  // MARK: - Properties

  /// The most items a Spotlight query reads.
  internal static let queryLimit = 5000

  /// The Spotlight attribute with an item's tag names; the SDK exports no constant for it.
  private static var userTagsAttribute: CFString {
    "kMDItemUserTags" as CFString
  }

  /// The legacy label indexes of the color tags in Finder's sidebar order: red, orange, yellow, green, blue,
  /// purple and gray. Index 0 of `NSWorkspace.fileLabels` is "None".
  private static let finderOrder = [6, 7, 5, 2, 4, 3, 1]

  // MARK: - Tag List

  /// The user's tags: the standard color tags in Finder's order, then the other tags found on items, by name.
  @concurrent
  internal static func userTags() async -> [String] {
    ordered(standard: NSWorkspace.shared.fileLabels, found: foundTagNames())
  }

  /// The color tags of `labels`, which are ordered like `NSWorkspace.fileLabels`, in Finder's order, followed by
  /// the other `found` tags sorted by name.
  /// The localized names of the seven color tags in Finder's order.
  internal static var colorTags: [String] {
    ordered(standard: NSWorkspace.shared.fileLabels, found: [])
  }

  internal static func ordered(standard labels: [String], found: Set<String>) -> [String] {
    let colorTags = finderOrder.compactMap { labels.indices.contains($0) ? labels[$0] : nil }
    let otherTags = found.subtracting(colorTags).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    return colorTags + otherTags
  }

  // MARK: - Tagged Items

  /// The items carrying `tag`, found through Spotlight.
  @concurrent
  internal static func items(taggedWith tag: String) async -> [URL] {
    guard let query = makeQuery("kMDItemUserTags == \"\(escaped(tag))\"", attributes: [kMDItemPath]) else {
      return []
    }
    return (0..<MDQueryGetResultCount(query)).compactMap { index in
      guard let value = MDQueryGetAttributeValueOfResultAtIndex(query, kMDItemPath, index) else {
        return nil
      }
      let path = Unmanaged<NSString>.fromOpaque(value).takeUnretainedValue() as String
      return URL(filePath: path)
    }
  }

  /// Adds `tag` to the items at `urls` that do not carry it yet; the items stay where they are.
  ///
  /// - Returns: The items that could not be tagged.
  @concurrent
  internal static func addTag(_ tag: String, to urls: [URL]) async -> [URL] {
    urls.filter { url in
      do {
        var url = url
        let existing = try url.resourceValues(forKeys: [.tagNamesKey]).tagNames ?? []
        guard existing.contains(tag) == false else {
          return false
        }
        var values = URLResourceValues()
        values.tagNames = existing + [tag]
        try url.setResourceValues(values)
        return false
      } catch {
        return true
      }
    }
  }

  /// `text` for a string in a Spotlight query: quotes, backslashes and the wildcard `*` are escaped.
  internal static func escaped(_ text: String) -> String {
    var result = ""
    for character in text {
      if character == "\"" || character == "\\" || character == "*" {
        result.append("\\")
      }
      result.append(character)
    }
    return result
  }

  // MARK: - Private

  /// The names of all tags that Spotlight finds on items.
  private static func foundTagNames() -> Set<String> {
    guard let query = makeQuery("kMDItemUserTags == \"*\"", attributes: [userTagsAttribute]) else {
      return []
    }
    var names = Set<String>()
    for index in 0..<MDQueryGetResultCount(query) {
      guard let value = MDQueryGetAttributeValueOfResultAtIndex(query, userTagsAttribute, index) else {
        continue
      }
      let tags = Unmanaged<NSArray>.fromOpaque(value).takeUnretainedValue() as? [String] ?? []
      names.formUnion(tags)
    }
    return names
  }

  /// Runs a Spotlight query synchronously and returns it with its results, or nil when it fails.
  private static func makeQuery(_ text: String, attributes: [CFString]) -> MDQuery? {
    guard let query = MDQueryCreate(kCFAllocatorDefault, text as CFString, attributes as CFArray, nil) else {
      return nil
    }
    MDQuerySetMaxCount(query, queryLimit)
    guard MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue)) else {
      return nil
    }
    return query
  }
}

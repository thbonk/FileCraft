/*
 * TagAssignment.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-06.
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

/// The tags of several items, as File > Tags… shows and changes them.
nonisolated internal struct TagAssignment: Hashable, Sendable {

  // MARK: - Types

  internal enum State: Hashable, Sendable {
    case on
    case off
    /// Some of the items carry the tag.
    case mixed
  }

  // MARK: - Properties

  /// The tags of each item, by item URL.
  internal private(set) var tags: [URL: [String]]

  // MARK: - Initialization

  internal init(tags: [URL: [String]]) {
    self.tags = tags
  }

  // MARK: - State

  internal func state(of tag: String) -> State {
    let carrying = tags.values.count { $0.contains(tag) }
    if carrying == 0 {
      return .off
    }
    return carrying == tags.count ? .on : .mixed
  }

  /// Turns `tag` on for all items, or off for all items when all of them carry it.
  ///
  /// - Returns: The items whose tags changed, with their new tags.
  @discardableResult
  internal mutating func toggle(_ tag: String) -> [URL: [String]] {
    let removes = state(of: tag) == .on
    var changed: [URL: [String]] = [:]
    for (url, itemTags) in tags {
      let newTags = removes ? itemTags.filter { $0 != tag } : (itemTags.contains(tag) ? itemTags : itemTags + [tag])
      if newTags != itemTags {
        tags[url] = newTags
        changed[url] = newTags
      }
    }
    return changed
  }
}

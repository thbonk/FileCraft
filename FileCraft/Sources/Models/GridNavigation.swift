/*
 * GridNavigation.swift
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

/// Arrow-key movement in the reflowing grid of icon view.
nonisolated internal enum GridNavigation {

  internal enum Direction: Sendable {
    case left
    case right
    case up
    case down
  }

  /// Returns the index reached from `index` in a grid of `count` items with `columns` columns, or nil when the
  /// move would leave the grid. Moving down from the second-to-last row onto a shorter last row lands on the
  /// last item.
  internal static func index(from index: Int, moving direction: Direction, columns: Int, count: Int) -> Int? {
    guard count > 0, columns > 0, (0..<count).contains(index) else {
      return nil
    }
    let target =
      switch direction {
      case .left:
        index - 1
      case .right:
        index + 1
      case .up:
        index - columns
      case .down:
        index + columns
      }
    if (0..<count).contains(target) {
      return target
    }
    let isAboveLastRow = index / columns < (count - 1) / columns
    return direction == .down && isAboveLastRow ? count - 1 : nil
  }

  /// The number of columns that fit `width` with cells of `cellWidth` separated by `spacing`.
  internal static func columnCount(for width: CGFloat, cellWidth: CGFloat, spacing: CGFloat) -> Int {
    guard cellWidth > 0 else {
      return 1
    }
    return max(1, Int((width + spacing) / (cellWidth + spacing)))
  }
}

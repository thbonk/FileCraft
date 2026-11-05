/*
 * GridNavigationTests.swift
 * FileCraftTests
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
import Testing
@testable import FileCraft

internal struct GridNavigationTests {

  // MARK: - Types

  /// One arrow-key move in a grid of 3 columns holding 7 items:
  ///
  ///     0 1 2
  ///     3 4 5
  ///     6
  internal struct Move: Sendable, CustomTestStringConvertible {
    let index: Int
    let direction: GridNavigation.Direction
    let expected: Int?

    var testDescription: String {
      "\(index) \(direction) → \(expected.map(String.init) ?? "none")"
    }
  }

  // MARK: - Arguments

  nonisolated private static let moves: [Move] = [
    Move(index: 0, direction: .right, expected: 1),
    Move(index: 0, direction: .left, expected: nil),
    Move(index: 3, direction: .left, expected: 2),
    Move(index: 1, direction: .down, expected: 4),
    Move(index: 5, direction: .up, expected: 2),
    Move(index: 2, direction: .up, expected: nil),
    Move(index: 4, direction: .down, expected: 6),
    Move(index: 6, direction: .down, expected: nil),
    Move(index: 6, direction: .right, expected: nil),
  ]

  // MARK: - Tests

  @Test(arguments: moves)
  internal func `Arrow keys move through the grid and stop at its edges`(move: Move) {
    #expect(GridNavigation.index(from: move.index, moving: move.direction, columns: 3, count: 7) == move.expected)
  }

  @Test
  internal func `Moves in an empty grid or from outside it go nowhere`() {
    #expect(GridNavigation.index(from: 0, moving: .right, columns: 3, count: 0) == nil)
    #expect(GridNavigation.index(from: 9, moving: .left, columns: 3, count: 7) == nil)
  }

  @Test
  internal func `The column count matches the cells that fit the width`() {
    #expect(GridNavigation.columnCount(for: 300, cellWidth: 96, spacing: 12) == 2)
    #expect(GridNavigation.columnCount(for: 312, cellWidth: 96, spacing: 12) == 3)
    #expect(GridNavigation.columnCount(for: 0, cellWidth: 96, spacing: 12) == 1)
    #expect(GridNavigation.columnCount(for: 300, cellWidth: 0, spacing: 12) == 1)
  }
}

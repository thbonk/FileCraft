/*
 * ListFileViewPerformanceTests.swift
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

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import FileCraft

/// The benchmark of task 4.1: SwiftUI `Table` with 10,000 items. The limits are loose enough for unoptimized
/// test builds; the measured times are attached to the test results.
internal struct ListFileViewPerformanceTests {

  // MARK: - Properties

  private let tab: TabModel = {
    let base = Date(timeIntervalSince1970: 1_793_361_600)
    let items = (0..<10_000).map { index in
      FileItem(
        url: URL(filePath: "/tmp/Benchmark/File \(index).txt"),
        kind: "Plain Text",
        size: Int64(index * 37),
        modificationDate: base.addingTimeInterval(-Double(index) * 60))
    }
    return TabModel(location: .tag("Benchmark"), listing: DirectoryListing(staticItems: items))
  }()

  // MARK: - Tests

  @Test
  internal func `Sorting and flattening 10,000 rows stays fast`() {
    let clock = ContinuousClock()

    let elapsed = clock.measure {
      _ = tab.outlineRows
    }

    Attachment.record("outlineRows for 10,000 items: \(elapsed)", named: "sort-and-flatten.txt")
    #expect(elapsed < .milliseconds(400))
  }

  /// Every selection change re-evaluates the menu commands, which read the selected items about twenty times.
  @Test
  internal func `Reading the selected items for every menu command stays fast`() {
    tab.selection = Set(tab.visibleItems.prefix(2).map(\.id))
    _ = tab.selectedItems
    let clock = ContinuousClock()

    let elapsed = clock.measure {
      for _ in 0..<20 {
        _ = tab.selectedItems
      }
    }

    Attachment.record("20 reads of selectedItems for 10,000 items: \(elapsed)", named: "selected-items.txt")
    #expect(elapsed < .milliseconds(50))
  }

  /// Each arrow key changes the selection, which the views, menu commands and status bar read at once.
  @Test
  internal func `Moving the selection through twenty rows stays fast`() {
    tab.viewSettings.viewMode = .list
    let rows = Array(tab.outlineRows.prefix(20))
    let clock = ContinuousClock()

    let elapsed = clock.measure {
      for row in rows {
        tab.selection = [row.id]
        _ = tab.selectedItems
      }
    }

    Attachment.record("20 selection changes in 10,000 items: \(elapsed)", named: "selection-changes.txt")
    #expect(elapsed < .milliseconds(30))
  }

  /// The view mode does not change the order, so switching it must not sort again.
  @Test
  internal func `Switching the view mode keeps the sorted items`() {
    _ = tab.outlineRows
    _ = tab.itemSections
    let clock = ContinuousClock()

    let elapsed = clock.measure {
      tab.viewSettings.viewMode = tab.viewSettings.viewMode == .icons ? .list : .icons
      _ = tab.outlineRows
      _ = tab.itemSections
    }

    Attachment.record("view mode switch with 10,000 items: \(elapsed)", named: "view-mode-switch.txt")
    #expect(elapsed < .milliseconds(20))
  }

  @Test
  internal func `Sorting 10,000 items by name stays fast`() {
    let items = tab.listing.items
    let sorting = ItemSorting(order: ItemSortOrder())
    let clock = ContinuousClock()

    let elapsed = clock.measure {
      _ = sorting.sorted(items)
    }

    Attachment.record("sorting 10,000 items by name: \(elapsed)", named: "sort-by-name.txt")
    #expect(elapsed < .milliseconds(150))
  }

  @Test
  internal func `List view lays out 10,000 rows within half a second`() {
    let clock = ContinuousClock()
    var host: NSHostingView<AnyView>?

    let elapsed = clock.measure {
      let view = NSHostingView(rootView: AnyView(ListFileView(tab: tab).frame(width: 900, height: 600)))
      view.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
      view.layoutSubtreeIfNeeded()
      host = view
    }

    Attachment.record("first layout of 10,000 rows: \(elapsed)", named: "first-layout.txt")
    #expect(host != nil)
    #expect(elapsed < .milliseconds(500))
  }
}

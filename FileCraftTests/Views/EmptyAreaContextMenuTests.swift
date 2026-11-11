/*
 * EmptyAreaContextMenuTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-11-11.
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
import SwiftUI
import Testing
@testable import FileCraft

internal struct EmptyAreaContextMenuTests {

  // MARK: - Tests

  @Test
  internal func `A secondary click below the rows shows the menu`() throws {
    let fixture = try TableFixture(tableWidth: 300)

    let rightClick = fixture.anchor.handle(try fixture.event(.rightMouseDown, at: fixture.belowRows))
    let controlClick = fixture.anchor.handle(try fixture.event(.leftMouseDown, at: fixture.belowRows, modifiers: .control))

    #expect(rightClick)
    #expect(controlClick)
    #expect(fixture.presentedViews.count == 2)
    #expect(fixture.presentedViews.allSatisfy { $0 === fixture.table })
  }

  @Test
  internal func `Clicks on rows, on the header, beside the view or without Control pass through`() throws {
    let fixture = try TableFixture(tableWidth: 300)

    let handled = [
      fixture.anchor.handle(try fixture.event(.rightMouseDown, at: fixture.onFirstRow)),
      fixture.anchor.handle(try fixture.event(.rightMouseDown, at: fixture.onHeader)),
      fixture.anchor.handle(try fixture.event(.rightMouseDown, at: fixture.besideView)),
      fixture.anchor.handle(try fixture.event(.leftMouseDown, at: fixture.belowRows)),
    ]

    #expect(handled == [false, false, false, false])
    #expect(fixture.presentedViews.isEmpty)
  }

  @Test(arguments: [ViewMode.list, ViewMode.columns])
  internal func `List and column view offer the background menu below their rows`(mode: ViewMode) throws {
    let directory = try TemporaryDirectory()
    var settings = ViewSettings()
    settings.viewMode = mode
    let tab = TabModel(
      location: .folder(try FileReference(url: directory.url)), viewSettings: settings,
      listing: DirectoryListing(staticItems: []))
    let view = NSHostingView(
      rootView: FileViewContainer(tab: tab)
        .frame(width: 600, height: 400)
        .environment(\.locale, Locale(identifier: "en"))
        .defaultAppStorage(AppEnvironment.userDefaults))
    view.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
    view.layoutSubtreeIfNeeded()

    let anchor = try #require(Self.descendants(of: view).lazy.compactMap { $0 as? EmptyAreaMenuAnchorView }.first)
    let menu = try #require(anchor.makeMenu?())
    menu.update()
    let titles = menu.items.map(\.title)

    #expect(titles.contains("New Folder"))
    #expect(titles.contains("Paste"))
    #expect(titles.contains("Group By"))
  }

  // MARK: - Helpers

  private static func descendants(of view: NSView) -> [NSView] {
    view.subviews + view.subviews.flatMap(descendants(of:))
  }
}

/// A window with a three-row table that fills the left part of the window, and an anchor behind the table's scroll
/// view, as SwiftUI places a background.
@MainActor
private final class TableFixture: NSObject, NSTableViewDataSource {

  let window: NSWindow
  let table = NSTableView()
  let anchor: EmptyAreaMenuAnchorView
  private let scrollView: NSScrollView
  private(set) var presentedViews: [NSView] = []

  /// Creates the window, 400 points wide, with the table `tableWidth` points wide at its leading edge.
  init(tableWidth: CGFloat) throws {
    window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let contentView = try #require(window.contentView)
    let frame = NSRect(x: 0, y: 0, width: tableWidth, height: 300)
    scrollView = NSScrollView(frame: frame)
    anchor = EmptyAreaMenuAnchorView(frame: frame)
    super.init()
    table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name")))
    table.dataSource = self
    scrollView.documentView = table
    scrollView.hasVerticalScroller = true
    contentView.addSubview(anchor)
    contentView.addSubview(scrollView, positioned: .above, relativeTo: anchor)
    scrollView.tile()
    table.reloadData()
    table.sizeLastColumnToFit()
    contentView.layoutSubtreeIfNeeded()
    anchor.present = { [weak self] _, _, view in
      self?.presentedViews.append(view)
    }
    anchor.makeMenu = { NSMenu() }
  }

  /// Near the bottom of the table's scroll view, far below its three rows.
  var belowRows: NSPoint {
    scrollView.convert(NSPoint(x: 50, y: scrollView.isFlipped ? scrollView.bounds.maxY - 10 : 10), to: nil)
  }

  var onFirstRow: NSPoint {
    let row = table.rect(ofRow: 0)
    return table.convert(NSPoint(x: row.midX, y: row.midY), to: nil)
  }

  var onHeader: NSPoint {
    guard let header = table.headerView else {
      return .zero
    }
    return header.convert(NSPoint(x: header.bounds.midX, y: header.bounds.midY), to: nil)
  }

  /// In the window, right of the table.
  var besideView: NSPoint {
    NSPoint(x: 350, y: 150)
  }

  func event(_ type: NSEvent.EventType, at point: NSPoint, modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
    try #require(
      NSEvent.mouseEvent(
        with: type, location: point, modifierFlags: modifiers, timestamp: 0, windowNumber: window.windowNumber,
        context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
  }

  nonisolated func numberOfRows(in tableView: NSTableView) -> Int {
    3
  }
}

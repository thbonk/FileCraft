/*
 * EmptyAreaContextMenu.swift
 * FileCraft
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

extension View {

  /// Shows `menu` when the user secondary-clicks the empty area below the rows of the `List` or `Table` it modifies.
  ///
  /// On macOS 27, `contextMenu(forSelectionType:)` of a `List` or `Table` is not called for clicks outside the rows.
  /// An AppKit view behind the list therefore watches for those clicks and shows the same SwiftUI menu content in an
  /// `NSHostingMenu`.
  internal func emptyAreaContextMenu<Menu: View>(@ViewBuilder _ menu: @escaping () -> Menu) -> some View {
    background {
      EmptyAreaMenuAnchor(menu: menu)
    }
  }
}

/// Places an `EmptyAreaMenuAnchorView` behind the view it modifies.
private struct EmptyAreaMenuAnchor<Menu: View>: NSViewRepresentable {

  let menu: () -> Menu

  func makeNSView(context: Context) -> EmptyAreaMenuAnchorView {
    EmptyAreaMenuAnchorView()
  }

  func updateNSView(_ view: EmptyAreaMenuAnchorView, context: Context) {
    // The menu is not part of the view hierarchy, so it gets the environment values its content reads.
    let locale = context.environment.locale
    view.makeMenu = { [menu] in
      NSHostingMenu(rootView: menu().environment(\.locale, locale).defaultAppStorage(AppEnvironment.userDefaults))
    }
  }
}

/// Lies behind a file view and shows its background menu for secondary clicks below the rows.
///
/// The view never takes clicks itself: a local event monitor sees each click first and handles only secondary clicks
/// inside this view's frame that land on the table's own area. Clicks on rows, the column header or a scroller go on
/// to the table as usual.
internal final class EmptyAreaMenuAnchorView: NSView {

  // MARK: - Properties

  /// Creates the menu to show.
  internal var makeMenu: (() -> NSMenu)?
  /// Shows `menu` for `event` over `view`.
  internal var present: (NSMenu, NSEvent, NSView) -> Void = { menu, event, view in
    NSMenu.popUpContextMenu(menu, with: event, for: view)
  }

  private var monitor: Any?

  // MARK: - NSView

  override internal func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  override internal func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if let monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
    guard window != nil else {
      return
    }
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
      guard let self, self.handle(event) else {
        return event
      }
      return nil
    }
  }

  // MARK: - Handling Clicks

  /// Shows the menu and returns `true` if `event` is a secondary click below the rows of the table this view lies
  /// behind.
  internal func handle(_ event: NSEvent) -> Bool {
    guard
      let window,
      event.windowNumber == window.windowNumber,
      Self.isSecondaryClick(event),
      bounds.contains(convert(event.locationInWindow, from: nil)),
      let table = Self.table(at: event.locationInWindow, in: window),
      table.row(at: table.convert(event.locationInWindow, from: nil)) == -1,
      let menu = makeMenu?()
    else {
      return false
    }
    present(menu, event, table)
    return true
  }

  private static func isSecondaryClick(_ event: NSEvent) -> Bool {
    switch event.type {
    case .rightMouseDown:
      true
    case .leftMouseDown:
      event.modifierFlags.contains(.control)
    default:
      false
    }
  }

  /// The table whose own area lies at `point`, in window coordinates; `nil` over its column header or a scroller.
  private static func table(at point: NSPoint, in window: NSWindow) -> NSTableView? {
    // The window's frame view takes points in window coordinates, as it has no superview.
    guard let frameView = window.contentView?.superview ?? window.contentView, let hitView = frameView.hitTest(point) else {
      return nil
    }
    for view in sequence(first: hitView, next: \.superview) {
      switch view {
      case let table as NSTableView:
        return table
      case is NSTableHeaderView, is NSScroller:
        return nil
      case let clipView as NSClipView:
        // Below a table that is shorter than its scroll view.
        return clipView.documentView as? NSTableView
      default:
        continue
      }
    }
    return nil
  }
}

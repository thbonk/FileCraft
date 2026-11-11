/*
 * FileViewContainerTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-11-10.
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

internal struct FileViewContainerTests {

  // MARK: - Tests

  /// The file view takes keyboard focus, offers Paste and the background menu, so it stays when the folder is empty.
  @Test
  internal func `An empty folder keeps its file view`() {
    var settings = ViewSettings()
    settings.viewMode = .list
    let tab = TabModel(location: .tag("Empty"), viewSettings: settings, listing: DirectoryListing(staticItems: []))
    let view = NSHostingView(rootView: FileViewContainer(tab: tab).frame(width: 600, height: 400))
    view.frame = NSRect(x: 0, y: 0, width: 600, height: 400)

    view.layoutSubtreeIfNeeded()

    #expect(Self.descendants(of: view).contains { $0 is NSTableView })
  }

  // MARK: - Private

  private static func descendants(of view: NSView) -> [NSView] {
    view.subviews + view.subviews.flatMap(descendants(of:))
  }
}

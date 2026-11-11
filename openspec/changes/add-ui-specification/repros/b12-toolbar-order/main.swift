/*
 * main.swift
 * ToolbarRepro
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

// A stock SwiftUI app with a customizable toolbar, the shape of FileCraft's browser window. It quits itself after
// four seconds, so that a script can launch it repeatedly and read the toolbar configuration that AppKit saved.
//
// Compilation conditions:
// - NO_SPLIT: no NavigationSplitView and no inspector; the saved order stays stable.
// - NO_INSPECTOR: NavigationSplitView without the inspector; the order still drifts.
// - REMOVE_TOGGLE: NavigationSplitView without its sidebar toggle; the order still changes.

import AppKit
import SwiftUI

@main
struct ToolbarReproApp: App {
  var body: some Scene {
    WindowGroup(id: "browser") {
      BrowserView()
    }
  }
}

struct BrowserView: View {
  @State private var isInspectorShown = true

  var body: some View {
    Group {
      #if NO_SPLIT
        Text("Detail")
      #else
        NavigationSplitView {
          List { Text("Sidebar") }
          #if REMOVE_TOGGLE
            .toolbar(removing: .sidebarToggle)
          #endif
        } detail: {
          Text("Detail")
        }
        #if !NO_INSPECTOR
          .inspector(isPresented: $isInspectorShown) {
            Text("Inspector")
          }
        #endif
      #endif
    }
    .frame(minWidth: 1300, minHeight: 600)
    .toolbar(id: "browser") {
      ToolbarItem(id: "backForward", placement: .navigation) { Button("Back", systemImage: "chevron.backward") {} }
      ToolbarItem(id: "viewMode") { Button("View", systemImage: "square.grid.2x2") {} }
      ToolbarItem(id: "groupSort") { Button("Sort", systemImage: "arrow.up.arrow.down") {} }
      ToolbarItem(id: "action") { Button("Action", systemImage: "ellipsis.circle") {} }
      ToolbarItem(id: "share") { Button("Share", systemImage: "square.and.arrow.up") {} }
      ToolbarItem(id: "dualPane") { Button("Dual", systemImage: "rectangle.split.2x1") {} }
      ToolbarItem(id: "inspector") { Button("Inspector", systemImage: "sidebar.right") {} }
      ToolbarItem(id: "newFolder", showsByDefault: false) { Button("New Folder", systemImage: "folder.badge.plus") {} }
      ToolbarItem(id: "moveToTrash", showsByDefault: false) { Button("Trash", systemImage: "trash") {} }
      ToolbarItem(id: "getInfo", showsByDefault: false) { Button("Info", systemImage: "info.circle") {} }
      ToolbarItem(id: "shelf", showsByDefault: false) { Button("Shelf", systemImage: "tray") {} }
      ToolbarItem(id: "hiddenFiles", showsByDefault: false) { Button("Hidden", systemImage: "eye") {} }
      ToolbarItem(id: "quickLook", showsByDefault: false) { Button("Quick Look", systemImage: "eye.circle") {} }
      ToolbarItem(id: "compress", showsByDefault: false) { Button("Compress", systemImage: "archivebox") {} }
      ToolbarItem(id: "openInTerminal", showsByDefault: false) { Button("Terminal", systemImage: "terminal") {} }
      ToolbarItem(id: "eject", showsByDefault: false) { Button("Eject", systemImage: "eject") {} }
      ToolbarItem(id: "operations", showsByDefault: false) { Button("Operations", systemImage: "list.bullet") {} }
      ToolbarItem(id: "search") {
        SearchFieldRepresentable().frame(minWidth: 140, idealWidth: 220, maxWidth: 280)
      }
    }
    .task {
      try? await Task.sleep(for: .seconds(4))
      NSApplication.shared.terminate(nil)
    }
  }
}

struct SearchFieldRepresentable: NSViewRepresentable {
  func makeNSView(context: Context) -> NSSearchField { NSSearchField() }
  func updateNSView(_ field: NSSearchField, context: Context) {}
}

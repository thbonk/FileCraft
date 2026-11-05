/*
 * InfoWindowView.swift
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

import SwiftUI

/// A Get Info window (⌘I) for one item. It stays bound to the item through its bookmark, so it follows renames
/// and moves; the bookmark is resolved again whenever the window becomes active.
internal struct InfoWindowView: View {

  // MARK: - Properties

  /// The identifier of the Get Info scene.
  nonisolated internal static let windowID = "info"

  internal let reference: FileReference?

  @Environment(\.appearsActive) private var appearsActive
  @State private var url: URL?
  @State private var isUnresolvable = false

  // MARK: - Body

  internal var body: some View {
    Group {
      if let url {
        InspectorContent(urls: [url]) { itemURL in
          BrowserWindowModel.mostRecentlyActive?.activeTab.reveal(itemURL)
        } didRename: { newURL in
          self.url = newURL
        }
      } else if isUnresolvable {
        ContentUnavailableView("Item Not Found", systemImage: "questionmark.square.dashed")
      } else {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(minWidth: 300, idealWidth: 320, minHeight: 360, idealHeight: 560)
    .navigationTitle(url.map { FileManager.default.displayName(atPath: $0.path(percentEncoded: false)) } ?? "")
    .task(id: appearsActive) {
      await resolve()
    }
  }

  // MARK: - Private

  private func resolve() async {
    guard let reference else {
      isUnresolvable = true
      return
    }
    let resolved = await Self.resolvedURL(of: reference)
    isUnresolvable = resolved == nil
    if resolved != url {
      url = resolved
    }
  }

  @concurrent
  private static func resolvedURL(of reference: FileReference) async -> URL? {
    try? reference.resolve().url
  }
}

#Preview("German") {
  InfoWindowView(reference: FileReference(unresolvedURL: PreviewFixtures.homeFolder))
    .environment(\.locale, Locale(identifier: "de"))
}

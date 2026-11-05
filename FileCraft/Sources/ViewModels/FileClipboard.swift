/*
 * FileClipboard.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-04.
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
import Observation

/// The items that Edit > Cut marked, shown dimmed until they are pasted. The pasteboard holds them like copied
/// items; pasting exactly these items moves them instead of copying them.
@Observable
internal final class FileClipboard {

  // MARK: - Properties

  /// The clipboard of the app, shared by all windows.
  internal static let shared = FileClipboard()

  /// The comparable paths of the cut items.
  internal private(set) var cutPaths: Set<String> = []

  // MARK: - Cutting

  internal func markCut(_ urls: [URL]) {
    cutPaths = Set(urls.map(\.comparablePath))
  }

  internal func isCut(_ url: URL) -> Bool {
    cutPaths.isEmpty == false && cutPaths.contains(url.comparablePath)
  }

  /// Whether pasting `urls` moves them because they are the items cut last; pasting ends the cut either way.
  internal func takeCut(_ urls: [URL]) -> Bool {
    let isCut = cutPaths.isEmpty == false && Set(urls.map(\.comparablePath)) == cutPaths
    cutPaths = []
    return isCut
  }

  internal func clear() {
    cutPaths = []
  }
}

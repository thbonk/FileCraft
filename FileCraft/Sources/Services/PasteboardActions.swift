/*
 * PasteboardActions.swift
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

import AppKit
import Foundation

/// Puts text on the pasteboard for Copy Path and Copy Path As.
///
/// SwiftUI has no API to write the pasteboard from a menu command on macOS, so this uses `NSPasteboard`
/// (design decision D9).
internal enum PasteboardActions {

  /// Replaces the contents of `pasteboard` with `text`.
  internal static func copy(_ text: String, to pasteboard: NSPasteboard = .general) {
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }

  /// Copies the paths of `urls` in `format`, one per line.
  /// Puts the files at `urls` on the pasteboard, as Copy in a context menu does; a cut waiting to be pasted is
  /// forgotten.
  internal static func copyFiles(_ urls: [URL], to pasteboard: NSPasteboard = .general) {
    pasteboard.clearContents()
    pasteboard.writeObjects(urls as [NSURL])
    FileClipboard.shared.clear()
  }

  internal static func copyPaths(of urls: [URL], as format: PathFormat, to pasteboard: NSPasteboard = .general) {
    guard urls.isEmpty == false else {
      return
    }
    copy(PathFormatter.string(for: urls, format: format), to: pasteboard)
  }

  /// The file references on `pasteboard`, as Finder and FileCraft copy them, for Edit > Move Items Here.
  internal static func fileURLs(on pasteboard: NSPasteboard = .general) -> [URL] {
    let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    return (objects as? [URL]) ?? []
  }
}

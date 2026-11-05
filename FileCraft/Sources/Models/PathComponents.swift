/*
 * PathComponents.swift
 * FileCraft
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

import Foundation

/// One folder in the path bar.
nonisolated internal struct PathSegment: Identifiable, Hashable, Sendable {
  internal let url: URL
  internal let name: String

  internal var id: String {
    url.path(percentEncoded: false)
  }
}

/// Splits a location into the segments the path bar shows, from the volume root down.
nonisolated internal enum PathComponents {

  /// Returns the segments from `volumeRoot` (or "/" when unknown) to `url`.
  ///
  /// - Parameter displayName: The name to show for a folder.
  internal static func segments(for url: URL, volumeRoot: URL?, displayName: (URL) -> String) -> [PathSegment] {
    let rootPath = trimmed((volumeRoot ?? URL(filePath: "/")).standardizedFileURL.path(percentEncoded: false))
    var segments: [PathSegment] = []
    var current = url.standardizedFileURL
    while true {
      segments.append(PathSegment(url: current, name: displayName(current)))
      let path = trimmed(current.path(percentEncoded: false))
      guard path != rootPath, path != "/" else {
        break
      }
      current = current.deletingLastPathComponent()
    }
    return segments.reversed()
  }

  /// Loads the segments of `url` with the names macOS displays, off the caller's actor.
  @concurrent
  internal static func load(for url: URL) async -> [PathSegment] {
    let volumeRoot = try? url.resourceValues(forKeys: [.volumeURLKey]).volume
    return segments(for: url, volumeRoot: volumeRoot) {
      FileManager.default.displayName(atPath: $0.path(percentEncoded: false))
    }
  }

  private static func trimmed(_ path: String) -> String {
    path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
  }
}

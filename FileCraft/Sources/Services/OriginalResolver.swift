/*
 * OriginalResolver.swift
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

import Foundation

/// The outcome of File > Show Original.
nonisolated internal enum OriginalResolution: Hashable, Sendable {
  /// The item the alias or symbolic link points to.
  case original(URL)
  /// The alias or link points to an item that no longer exists.
  case broken
}

/// Finds the original items of aliases and symbolic links.
nonisolated internal enum OriginalResolver {

  /// The original of `item`, or nil when `item` is neither an alias nor a symbolic link.
  ///
  /// A symbolic link is followed one step, as Finder does. Resolving an alias may mount the volume it points to,
  /// but never shows UI.
  @concurrent
  internal static func original(of item: FileItem) async -> OriginalResolution? {
    if item.isSymbolicLink {
      return symbolicLinkTarget(of: item.url)
    }
    if item.isAliasFile {
      guard let target = try? URL(resolvingAliasFileAt: item.url, options: [.withoutUI]) else {
        return .broken
      }
      return .original(target.standardizedFileURL)
    }
    return nil
  }

  // MARK: - Private

  private static func symbolicLinkTarget(of url: URL) -> OriginalResolution {
    let fileManager = FileManager.default
    guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: url.path(percentEncoded: false)) else {
      return .broken
    }
    // A relative destination starts from the folder that contains the link.
    let target = URL(filePath: destination, relativeTo: url.deletingLastPathComponent()).absoluteURL.standardizedFileURL
    return fileManager.fileExists(atPath: target.path(percentEncoded: false)) ? .original(target) : .broken
  }
}

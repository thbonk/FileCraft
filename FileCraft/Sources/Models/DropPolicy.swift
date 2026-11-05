/*
 * DropPolicy.swift
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

/// The keys held during a drop, as the drag session reports them: ⌥ copies, ⌘ moves, ⌥⌘ makes aliases.
nonisolated internal enum DropKeys: Hashable, Sendable {
  /// No key that forces an operation.
  case none
  case copy
  case move
  case alias
}

/// What a drop does.
nonisolated internal enum DropAction: Hashable, Sendable {
  case move
  case copy
  case alias
  /// The drop changes nothing, as moving items into the folder they are in.
  case nothing
  /// The drop is refused for the localized reason.
  case refuse(String)
}

/// The drag-and-drop rules of the file views spec: dropping moves items on the same volume and copies them across
/// volumes; ⌥ forces a copy, ⌘ a move and ⌥⌘ creates aliases. A folder never goes into itself or one of its
/// folders.
nonisolated internal struct DropPolicy: Sendable {

  // MARK: - Properties

  /// The volume of an item, compared to tell moves from copies.
  internal var volume: @Sendable (URL) -> String? = Self.volumePath

  // MARK: - Deciding

  /// What dropping `items` onto `folder` with `keys` does.
  internal func action(for items: [URL], into folder: URL, keys: DropKeys) -> DropAction {
    guard items.isEmpty == false else {
      return .nothing
    }
    if keys == .alias {
      return .alias
    }
    let folderPath = folder.comparablePath
    let containsFolder = items.contains { item in
      let path = item.comparablePath
      return FileCopier.isDirectory(item) && (folderPath == path || folderPath.hasPrefix(path + "/"))
    }
    if containsFolder {
      return .refuse(String(localized: "A folder can’t be copied or moved into itself."))
    }
    let operation = operation(for: items, into: folder, keys: keys)
    let isInFolder = items.allSatisfy { $0.deletingLastPathComponent().comparablePath == folderPath }
    // Moving items into their own folder changes nothing; copying them there duplicates them.
    return isInFolder && operation == .move ? .nothing : operation
  }

  /// Move or copy for `items` dropped onto `folder`, without the checks of `action(for:into:keys:)`; the drop
  /// cursor shows it while dragging.
  internal func operation(for items: [URL], into folder: URL, keys: DropKeys) -> DropAction {
    switch keys {
    case .copy:
      return .copy
    case .move:
      return .move
    case .alias:
      return .alias
    case .none:
      let target = volume(folder)
      let isSameVolume = target != nil && items.allSatisfy { volume($0) == target }
      return isSameVolume ? .move : .copy
    }
  }

  // MARK: - Private

  @Sendable
  private static func volumePath(of url: URL) -> String? {
    (try? url.resourceValues(forKeys: [.volumeURLKey]).volume)?.comparablePath
  }
}

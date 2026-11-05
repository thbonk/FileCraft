/*
 * ItemInfoProvider.swift
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
import ImageIO
import UniformTypeIdentifiers

/// The extra information icon view shows below an item's name.
nonisolated internal enum ItemInfo: Hashable, Sendable {
  /// The number of visible items in a folder.
  case itemCount(Int)
  /// The pixel dimensions of an image.
  case dimensions(width: Int, height: Int)
}

/// Reads item information off the caller's actor.
nonisolated internal enum ItemInfoProvider {

  /// Returns the item count of a folder or the dimensions of an image, or nil for other items.
  @concurrent
  internal static func info(for item: FileItem) async -> ItemInfo? {
    if item.isDirectory && item.isPackage == false {
      let contents = try? FileManager.default.contentsOfDirectory(
        at: item.url,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles])
      return contents.map { .itemCount($0.count) }
    }
    guard
      item.contentType?.conforms(to: .image) == true,
      let source = CGImageSourceCreateWithURL(item.url as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int
    else {
      return nil
    }
    return .dimensions(width: width, height: height)
  }
}

/*
 * ThumbnailService.swift
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

import CoreGraphics
import Foundation
import QuickLookThumbnailing

/// Creates Quick Look thumbnails and keeps the most recent ones in memory.
internal actor ThumbnailService {

  // MARK: - Types

  nonisolated private struct Key: Hashable {
    let path: String
    let pixelSize: Int
    let modificationDate: Date?
  }

  // MARK: - Properties

  /// The cache shared by all windows.
  nonisolated internal static let shared = ThumbnailService()

  private let capacity: Int
  private var images: [Key: CGImage] = [:]
  private var insertionOrder: [Key] = []

  // MARK: - Initialization

  /// - Parameter capacity: The maximum number of cached thumbnails.
  internal init(capacity: Int = 512) {
    self.capacity = capacity
  }

  // MARK: - Thumbnails

  /// Returns a thumbnail that fits `size` points at `scale`, or nil when Quick Look cannot create one.
  ///
  /// Results are cached per file, pixel size and modification date.
  internal func thumbnail(for url: URL, size: CGSize, scale: CGFloat, modificationDate: Date?) async -> CGImage? {
    let key = Key(
      path: url.path(percentEncoded: false),
      pixelSize: Int(max(size.width, size.height) * scale),
      modificationDate: modificationDate)
    if let image = images[key] {
      return image
    }
    guard let image = await ThumbnailRenderer.render(url: url, size: size, scale: scale) else {
      return nil
    }
    store(image, for: key)
    return image
  }

  // MARK: - Private

  private func store(_ image: CGImage, for key: Key) {
    if images[key] == nil {
      insertionOrder.append(key)
    }
    images[key] = image
    while insertionOrder.count > capacity {
      images[insertionOrder.removeFirst()] = nil
    }
  }
}

/// Renders thumbnails off the caller's actor.
nonisolated private enum ThumbnailRenderer {

  @concurrent
  static func render(url: URL, size: CGSize, scale: CGFloat) async -> CGImage? {
    let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .thumbnail)
    do {
      return try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).cgImage
    } catch {
      return nil
    }
  }
}

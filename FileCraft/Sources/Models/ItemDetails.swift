/*
 * ItemDetails.swift
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

import Foundation

/// An extended attribute of an item, listed read-only in the inspector.
nonisolated internal struct ExtendedAttribute: Hashable, Sendable {
  internal let name: String
  /// The size of the value in bytes.
  internal let size: Int
}

/// The pixel dimensions of an image.
nonisolated internal struct PixelSize: Hashable, Sendable {
  internal let width: Int
  internal let height: Int
}

/// Everything the inspector shows about one item beyond its `FileItem` snapshot.
nonisolated internal struct ItemDetails: Hashable, Sendable {
  internal var item: FileItem
  /// The Locked attribute (user immutable flag).
  internal var isLocked: Bool
  internal var lastOpenedDate: Date?
  /// The short version of an app or other bundle.
  internal var version: String?
  internal var pixelSize: PixelSize?
  /// The duration of an audio or video file in seconds.
  internal var duration: TimeInterval?
  /// What an alias or symbolic link points to; nil for other items.
  internal var original: OriginalResolution?
  internal var ownerName: String?
  internal var groupName: String?
  /// The access control entries, one readable line each.
  internal var accessControlEntries: [String]
  internal var extendedAttributes: [ExtendedAttribute]
}

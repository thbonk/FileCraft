/*
 * Volume.swift
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

/// A mounted volume with the properties the sidebar shows.
nonisolated internal struct Volume: Identifiable, Hashable, Sendable {

  // MARK: - Properties

  internal let url: URL
  internal let name: String
  internal let totalCapacity: Int64?
  internal let availableCapacity: Int64?
  internal let isEjectable: Bool
  internal let isRemovable: Bool
  internal let isInternal: Bool
  internal let isLocal: Bool
  internal let isRootFileSystem: Bool

  internal var id: String {
    url.path(percentEncoded: false)
  }

  /// The space to show as available: the space for important data, which includes purgeable space, or the plain
  /// available space when the former is unknown or 0, as APFS disk images report it.
  internal static func availableCapacity(importantUsage: Int64?, plain: Int?) -> Int64? {
    if let importantUsage, importantUsage > 0 {
      return importantUsage
    }
    return plain.map(Int64.init) ?? importantUsage
  }

  /// Whether the sidebar offers an eject button for the volume.
  internal var canEject: Bool {
    isRootFileSystem == false && (isEjectable || isRemovable || isLocal == false || isInternal == false)
  }

  // MARK: - Initialization

  internal init(
    url: URL,
    name: String,
    totalCapacity: Int64? = nil,
    availableCapacity: Int64? = nil,
    isEjectable: Bool = false,
    isRemovable: Bool = false,
    isInternal: Bool = true,
    isLocal: Bool = true,
    isRootFileSystem: Bool = false
  ) {
    self.url = url
    self.name = name
    self.totalCapacity = totalCapacity
    self.availableCapacity = availableCapacity
    self.isEjectable = isEjectable
    self.isRemovable = isRemovable
    self.isInternal = isInternal
    self.isLocal = isLocal
    self.isRootFileSystem = isRootFileSystem
  }
}

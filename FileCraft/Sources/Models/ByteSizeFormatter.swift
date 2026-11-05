/*
 * ByteSizeFormatter.swift
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

/// Formats byte counts in decimal units like Finder, or in binary units with IEC prefixes.
nonisolated internal struct ByteSizeFormatter: Sendable {

  // MARK: - Properties

  internal var units: SizeUnits
  internal var locale: Locale

  private static let binaryUnits = ["KiB", "MiB", "GiB", "TiB", "PiB"]

  // MARK: - Initialization

  internal init(units: SizeUnits = .decimal, locale: Locale = .current) {
    self.units = units
    self.locale = locale
  }

  // MARK: - Formatting

  /// Returns `bytes` formatted for `locale`, for example "4.2 MB" or "1 KiB".
  internal func string(for bytes: Int64) -> String {
    guard units == .binary, bytes >= 1_024 else {
      return bytes.formatted(.byteCount(style: .file).locale(locale))
    }
    var value = Double(bytes) / 1_024
    var unitIndex = 0
    while value >= 1_024 && unitIndex < Self.binaryUnits.count - 1 {
      value /= 1_024
      unitIndex += 1
    }
    let number = value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
    return "\(number) \(Self.binaryUnits[unitIndex])"
  }
}

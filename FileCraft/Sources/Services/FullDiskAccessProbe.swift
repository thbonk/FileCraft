/*
 * FullDiskAccessProbe.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-06.
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

import Darwin
import Foundation

/// Whether FileCraft has Full Disk Access.
nonisolated internal enum FullDiskAccessStatus: Hashable, Sendable {
  case granted
  case notGranted
  /// None of the probed locations exists, so the status cannot be told.
  case unknown
}

/// Tells whether FileCraft has Full Disk Access by reading locations that only Full Disk Access unlocks.
///
/// macOS offers no API for the status, so reading the user's privacy database is the common test: it exists for every
/// user, and reading it fails with "operation not permitted" without Full Disk Access.
nonisolated internal struct FullDiskAccessProbe: Sendable {

  // MARK: - Types

  /// The outcome of trying to read one location.
  internal enum ReadResult: Sendable {
    case readable
    case notPermitted
    case missing
  }

  // MARK: - Properties

  /// The probed locations, most reliable first.
  internal let locations: [URL]
  private let read: @Sendable (URL) -> ReadResult

  // MARK: - Initialization

  internal init(
    locations: [URL] = FullDiskAccessProbe.standardLocations,
    read: @escaping @Sendable (URL) -> ReadResult = FullDiskAccessProbe.tryReading
  ) {
    self.locations = locations
    self.read = read
  }

  internal static var standardLocations: [URL] {
    let library = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library", directoryHint: .isDirectory)
    return [
      library.appending(path: "Application Support/com.apple.TCC/TCC.db", directoryHint: .notDirectory),
      library.appending(path: "Safari", directoryHint: .isDirectory),
    ]
  }

  // MARK: - Probing

  /// The status after trying the locations in order; the first location that exists decides.
  @concurrent
  internal func status() async -> FullDiskAccessStatus {
    for location in locations {
      switch read(location) {
      case .readable:
        return .granted
      case .notPermitted:
        return .notGranted
      case .missing:
        continue
      }
    }
    return .unknown
  }

  /// Opens a file for reading, or lists a folder, and reports whether that worked.
  internal static func tryReading(_ url: URL) -> ReadResult {
    let descriptor = url.withUnsafeFileSystemRepresentation { path -> Int32 in
      guard let path else {
        return -1
      }
      return Darwin.open(path, O_RDONLY)
    }
    guard descriptor >= 0 else {
      return errno == ENOENT ? .missing : .notPermitted
    }
    defer {
      close(descriptor)
    }
    // A folder opens without Full Disk Access; listing it is what Full Disk Access unlocks.
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory), isDirectory.boolValue {
      return (try? FileManager.default.contentsOfDirectory(atPath: url.path(percentEncoded: false))) == nil ? .notPermitted : .readable
    }
    var byte: UInt8 = 0
    return Darwin.read(descriptor, &byte, 1) >= 0 ? .readable : .notPermitted
  }
}

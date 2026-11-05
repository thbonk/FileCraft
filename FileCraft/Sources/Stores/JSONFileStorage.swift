/*
 * JSONFileStorage.swift
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

/// Reads and writes one store file off the main actor.
nonisolated internal struct JSONFileStorage: Sendable {

  // MARK: - Properties

  internal let fileURL: URL

  /// The folder in Application Support that holds FileCraft's store files.
  internal static let applicationSupportFolder = URL.applicationSupportDirectory
    .appending(path: "FileCraft", directoryHint: .isDirectory)

  // MARK: - Initialization

  internal init(fileURL: URL) {
    self.fileURL = fileURL
  }

  /// Storage for `fileName` inside FileCraft's Application Support folder.
  internal init(fileName: String) {
    self.init(fileURL: Self.applicationSupportFolder.appending(path: fileName, directoryHint: .notDirectory))
  }

  // MARK: - Access

  /// Returns the file's contents, or nil when the file does not exist or cannot be read.
  @concurrent
  internal func read() async -> Data? {
    try? Data(contentsOf: fileURL)
  }

  /// Replaces the file atomically, creating its folder when needed.
  @concurrent
  internal func write(_ data: Data) async throws {
    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: fileURL, options: .atomic)
  }
}

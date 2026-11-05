/*
 * TemporaryDirectory.swift
 * FileCraftTests
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

/// A uniquely named folder in the temporary directory that is deleted when the value is released.
///
/// The URL has symbolic links resolved, matching the paths that resolved bookmarks report.
nonisolated internal final class TemporaryDirectory: Sendable {

  // MARK: - Properties

  internal let url: URL

  // MARK: - Initialization

  internal init() throws {
    let url = FileManager.default.temporaryDirectory
      .appending(path: "FileCraftTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    self.url = url.resolvingSymlinksInPath()
  }

  deinit {
    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Creating Items

  /// Creates a file with UTF-8 `contents` at `relativePath`.
  @discardableResult
  internal func createFile(_ relativePath: String, contents: String = "") throws -> URL {
    let fileURL = url.appending(path: relativePath, directoryHint: .notDirectory)
    try Data(contents.utf8).write(to: fileURL)
    return fileURL
  }

  /// Creates a folder, including missing parents, at `relativePath`.
  @discardableResult
  internal func createFolder(_ relativePath: String) throws -> URL {
    let folderURL = url.appending(path: relativePath, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    return folderURL
  }
}

/*
 * PathInputParser.swift
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

/// Interprets paths typed into the path bar or the Go to Folder sheet.
nonisolated internal enum PathInputParser {

  /// Returns the URL for `input`: an absolute path, a path starting with "~", a file URL,
  /// or a path relative to `base`. Returns nil for empty input or a relative path without base.
  internal static func url(
    for input: String,
    relativeTo base: URL?,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> URL? {
    let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard text.isEmpty == false else {
      return nil
    }
    if text.hasPrefix("file://") {
      guard let url = URL(string: text), url.isFileURL else {
        return nil
      }
      return url.standardizedFileURL
    }
    if text == "~" {
      return homeDirectory.standardizedFileURL
    }
    if text.hasPrefix("~/") {
      return homeDirectory.appending(path: String(text.dropFirst(2))).standardizedFileURL
    }
    if text.hasPrefix("/") {
      return URL(filePath: text).standardizedFileURL
    }
    return base.map { $0.appending(path: text).standardizedFileURL }
  }
}

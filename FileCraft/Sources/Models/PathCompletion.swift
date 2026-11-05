/*
 * PathCompletion.swift
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

/// Completes paths typed into Go to Folder and the path bar.
nonisolated internal enum PathCompletion {

  /// The maximum number of completions offered for one input.
  internal static let limit = 20

  /// Returns the completions of `input` as complete texts in the notation the user typed, for example
  /// "~/Documents/" for "~/Doc".
  ///
  /// The last path component matches as a prefix, ignoring case and diacritics. Names starting with "." appear
  /// only when the typed component starts with ".". Folders end with "/", packages such as apps do not.
  /// File URLs are not completed.
  @concurrent
  internal static func completions(
    for input: String,
    relativeTo base: URL?,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) async -> [String] {
    if input == "~" {
      return ["~/"]
    }
    guard input.isEmpty == false, input.hasPrefix("file:") == false else {
      return []
    }
    let (folderText, partialName) = split(input)
    guard
      let folder = folderText.isEmpty
        ? base
        : PathInputParser.url(for: folderText, relativeTo: base, homeDirectory: homeDirectory),
      let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
    else {
      return []
    }
    let visibleNames: [String] = partialName.hasPrefix(".") ? names : names.filter { $0.hasPrefix(".") == false }
    let matchingNames: [String] = visibleNames.filter { name in
      partialName.isEmpty || name.range(of: partialName, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
    }
    let sortedNames: [String] = matchingNames.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    return sortedNames.prefix(limit).map { name in
      let suffix = isFolder(folder.appending(path: name)) ? "/" : ""
      return folderText + name + suffix
    }
  }

  // MARK: - Private

  /// Splits "~/Doc" into the folder text "~/" and the partial name "Doc"; text without "/" is all partial name.
  private static func split(_ input: String) -> (folderText: String, partialName: String) {
    guard let slash = input.lastIndex(of: "/") else {
      return ("", input)
    }
    let nameStart = input.index(after: slash)
    return (String(input[..<nameStart]), String(input[nameStart...]))
  }

  /// Whether `url`, after following symbolic links, is a folder that opens as a folder rather than a package.
  private static func isFolder(_ url: URL) -> Bool {
    let values = try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
    return values?.isDirectory == true && values?.isPackage != true
  }
}

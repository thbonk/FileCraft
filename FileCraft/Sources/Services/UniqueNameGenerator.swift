/*
 * UniqueNameGenerator.swift
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

/// Creates localized names for new, duplicated and extracted items that do not collide with existing names.
///
/// Collisions are detected case- and normalization-insensitively, as on the default APFS volume format.
/// A taken name gets the next free number: "untitled folder 2", "plan copy 2.key", "report 2.pdf".
nonisolated internal struct UniqueNameGenerator: Sendable {

  // MARK: - Properties

  private let bundle: Bundle
  private let language: Locale.Language?

  // MARK: - Initialization

  /// - Parameters:
  ///   - bundle: The bundle containing the localized base names.
  ///   - language: The language of generated names, or nil for the app's current language.
  internal init(bundle: Bundle = .main, language: Locale.Language? = nil) {
    self.bundle = bundle
    self.language = language
  }

  // MARK: - Names

  /// The name for a new folder, for example "untitled folder" or "Neuer Ordner".
  internal func untitledFolderName(existingNames: some Sequence<String>) -> String {
    availableName(base: localized("untitled folder"), pathExtension: nil, existingNames: existingNames)
  }

  /// The name for a new plain-text file, for example "untitled.txt" or "Unbenannt.txt".
  internal func untitledTextFileName(existingNames: some Sequence<String>) -> String {
    availableName(base: localized("untitled"), pathExtension: "txt", existingNames: existingNames)
  }

  /// The name for a duplicate of `name`, for example "plan copy.key" or "Bericht Kopie.pdf".
  ///
  /// - Parameter isFolder: Whether the item is a folder; folder names are never split at a dot.
  internal func duplicateName(of name: String, isFolder: Bool, existingNames: some Sequence<String>) -> String {
    let parts = split(name, isFolder: isFolder)
    let base = String(format: localized("%@ copy"), parts.base)
    return availableName(base: base, pathExtension: parts.pathExtension, existingNames: existingNames)
  }

  /// The name for an alias of `name`, for example "Projects alias".
  internal func aliasName(of name: String, existingNames: some Sequence<String>) -> String {
    availableName(base: String(format: localized("%@ alias"), name), pathExtension: nil, existingNames: existingNames)
  }

  /// The name of an archive: "<name>.zip" for one item, or "Archive.zip" when `itemName` is nil.
  ///
  /// - Parameter pathExtension: The archive's extension, such as "zip" or "tar.gz".
  internal func archiveName(
    forItemNamed itemName: String?, pathExtension: String = "zip", existingNames: some Sequence<String>
  ) -> String {
    availableName(base: itemName ?? localized("Archive"), pathExtension: pathExtension, existingNames: existingNames)
  }

  /// `name` itself when it is free, otherwise the next numbered variant, for example "report 2.pdf".
  internal func availableName(for name: String, isFolder: Bool, existingNames: some Sequence<String>) -> String {
    let parts = split(name, isFolder: isFolder)
    return availableName(base: parts.base, pathExtension: parts.pathExtension, existingNames: existingNames)
  }

  // MARK: - Private

  private func availableName(base: String, pathExtension: String?, existingNames: some Sequence<String>) -> String {
    let takenNames = Set(existingNames.map(Self.normalized))
    var number = 1
    while true {
      let numberedBase = number == 1 ? base : "\(base) \(number)"
      let candidate = pathExtension.map { "\(numberedBase).\($0)" } ?? numberedBase
      if takenNames.contains(Self.normalized(candidate)) == false {
        return candidate
      }
      number += 1
    }
  }

  private func split(_ name: String, isFolder: Bool) -> (base: String, pathExtension: String?) {
    let nsName = name as NSString
    guard isFolder == false, nsName.pathExtension.isEmpty == false else {
      return (name, nil)
    }
    return (nsName.deletingPathExtension, nsName.pathExtension)
  }

  private func localized(_ key: String) -> String {
    LocalizedLookup.string(key, bundle: bundle, language: language)
  }

  private static func normalized(_ name: String) -> String {
    name.precomposedStringWithCanonicalMapping.lowercased()
  }
}

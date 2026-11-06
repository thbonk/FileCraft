/*
 * AssetAuditTests.swift
 * FileCraftTests
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

import Foundation
import Testing

/// Pins the app bundle's resources to the ones the `appearance-and-accessibility` capability allows: the app icon,
/// the asset catalog (colors only) and localization. Everything else — images, sounds, interface files sourced from
/// Path Finder or anywhere else — must never appear, so a new resource always needs a conscious decision here.
internal struct AssetAuditTests {

  @Test
  internal func `The bundle contains only the app icon, the asset catalog and localization`() throws {
    let resources = try #require(Bundle.main.resourceURL)
    let names = try FileManager.default.contentsOfDirectory(atPath: resources.path(percentEncoded: false))
    let allowedExtensions: Set<String> = ["icns", "car", "lproj", "nib"]
    let unexpected = names.filter { name in
      // "nib" covers SwiftUI's compiled storyboard for the menu bar; "lproj" folders hold only strings below.
      allowedExtensions.contains((name as NSString).pathExtension) == false
    }

    #expect(unexpected.isEmpty, "Unexpected bundle resources: \(unexpected)")
  }

  @Test
  internal func `Each language folder holds only localized strings`() throws {
    let resources = try #require(Bundle.main.resourceURL)
    let languageFolders = try FileManager.default.contentsOfDirectory(atPath: resources.path(percentEncoded: false))
      .filter { $0.hasSuffix(".lproj") }

    #expect(languageFolders.isEmpty == false)
    for folder in languageFolders {
      let files = try FileManager.default.contentsOfDirectory(
        atPath: resources.appending(path: folder).path(percentEncoded: false))
      let unexpected = files.filter { file in
        ["strings", "stringsdict"].contains((file as NSString).pathExtension) == false
      }
      #expect(unexpected.isEmpty, "\(folder): \(unexpected)")
    }
  }

  @Test
  internal func `The repository has no image, sound or interface files besides the app icon`() throws {
    // Walks up from this test file to the repository root, which holds FileCraft/, FileCraftTests/ and .git.
    var root = URL(filePath: #filePath).deletingLastPathComponent()
    while FileManager.default.fileExists(atPath: root.appending(path: ".git").path(percentEncoded: false)) == false {
      let parent = root.deletingLastPathComponent()
      try #require(parent != root, "Could not find the repository root above \(#filePath)")
      root = parent
    }
    let forbiddenExtensions: Set<String> = [
      "jpg", "jpeg", "gif", "svg", "bmp", "tiff", "icon", "aiff", "wav", "caf", "mp3", "m4a", "nib", "xib", "storyboard",
    ]
    let found = try Self.files(
      in: root, excluding: ["Build", ".git", "DerivedData"],
      where: { forbiddenExtensions.contains(($0.lastPathComponent as NSString).pathExtension.lowercased()) })

    #expect(found.isEmpty, "\(found.map(\.path))")
  }

  @Test
  internal func `Every PNG in the repository belongs to the app icon set`() throws {
    var root = URL(filePath: #filePath).deletingLastPathComponent()
    while FileManager.default.fileExists(atPath: root.appending(path: ".git").path(percentEncoded: false)) == false {
      root = root.deletingLastPathComponent()
    }
    let found = try Self.files(
      in: root, excluding: ["Build", ".git", "DerivedData"],
      where: { $0.pathExtension.lowercased() == "png" })
    let outsideAppIcon = found.filter { $0.path(percentEncoded: false).contains("AppIcon.appiconset/") == false }

    #expect(outsideAppIcon.isEmpty, "\(outsideAppIcon.map(\.path))")
  }

  // MARK: - Private

  private static func files(in folder: URL, excluding excludedNames: Set<String>, where matches: (URL) -> Bool) throws -> [URL] {
    guard
      let enumerator = FileManager.default.enumerator(
        at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
    else {
      return []
    }
    var found: [URL] = []
    for case let url as URL in enumerator {
      if excludedNames.contains(url.lastPathComponent) {
        enumerator.skipDescendants()
        continue
      }
      let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
      if isDirectory == false, matches(url) {
        found.append(url)
      }
    }
    return found
  }
}

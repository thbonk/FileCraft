/*
 * PreviewFixtures.swift
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
import UniformTypeIdentifiers

/// Static sample data for `#Preview` blocks; previews never touch the real file system.
///
/// The preview support is compiled in every configuration, not only in Debug: `#Preview` blocks are type-checked in
/// Release builds too, so Release builds and Xcode Cloud archives fail without it.
nonisolated internal enum PreviewFixtures {

  // MARK: - Types

  internal enum Language: Sendable {
    case english
    case german
  }

  // MARK: - Properties

  internal static let homeFolder = URL(filePath: "/Users/preview", directoryHint: .isDirectory)

  /// A fixed reference date, 2026-10-30 10:42 UTC, so previews always look the same.
  internal static let referenceDate = Date(timeIntervalSince1970: 1_793_356_920)

  internal static let volumes: [Volume] = [
    Volume(
      url: URL(filePath: "/", directoryHint: .isDirectory),
      name: "Macintosh HD",
      totalCapacity: 994_662_584_320,
      availableCapacity: 412_301_337_600,
      isRootFileSystem: true),
    Volume(
      url: URL(filePath: "/Volumes/Backup", directoryHint: .isDirectory),
      name: "Backup",
      totalCapacity: 2_000_189_177_856,
      availableCapacity: 1_201_400_000_000,
      isEjectable: true,
      isRemovable: true,
      isInternal: false),
  ]

  // MARK: - Items

  /// Sample items of a home folder, named and described in `language`.
  internal static func items(in language: Language) -> [FileItem] {
    let german = language == .german
    return [
      folder(german ? "Dokumente" : "Documents", kind: german ? "Ordner" : "Folder", daysAgo: 1),
      folder(german ? "Projekte" : "Projects", kind: german ? "Ordner" : "Folder", daysAgo: 12),
      file(
        german ? "Bericht.pdf" : "Report.pdf",
        type: .pdf,
        kind: german ? "PDF-Dokument" : "PDF document",
        size: 4_200_000,
        daysAgo: 0,
        tags: [german ? "Arbeit" : "Work"]),
      file(german ? "Foto.jpg" : "photo.jpg", type: .jpeg, kind: german ? "JPEG-Bild" : "JPEG image", size: 2_513_408, daysAgo: 3),
      file(
        german ? "Notizen.txt" : "notes.txt",
        type: .plainText,
        kind: german ? "Reiner Text" : "Plain Text",
        size: 1_024,
        daysAgo: 40),
      FileItem(
        url: homeFolder.appending(path: "FileCraft.app", directoryHint: .isDirectory),
        localizedName: "FileCraft",
        isDirectory: true,
        isPackage: true,
        hasHiddenExtension: true,
        contentType: .applicationBundle,
        kind: german ? "Programm" : "Application",
        modificationDate: date(daysAgo: 5)),
      file(".zshrc", type: .plainText, kind: german ? "Reiner Text" : "Plain Text", size: 312, daysAgo: 90, isHidden: true),
    ]
  }

  /// Sample tag names in `language`.
  internal static func tagNames(in language: Language) -> [String] {
    language == .german ? ["Rot", "Blau", "Arbeit"] : ["Red", "Blue", "Work"]
  }

  // MARK: - Private

  private static func folder(_ name: String, kind: String, daysAgo: Int) -> FileItem {
    FileItem(
      url: homeFolder.appending(path: name, directoryHint: .isDirectory),
      isDirectory: true,
      contentType: .folder,
      kind: kind,
      creationDate: date(daysAgo: daysAgo + 30),
      modificationDate: date(daysAgo: daysAgo),
      permissions: 0o755)
  }

  private static func file(
    _ name: String,
    type: UTType,
    kind: String,
    size: Int64,
    daysAgo: Int,
    isHidden: Bool = false,
    tags: [String] = []
  ) -> FileItem {
    FileItem(
      url: homeFolder.appending(path: name, directoryHint: .notDirectory),
      isHidden: isHidden,
      contentType: type,
      kind: kind,
      size: size,
      allocatedSize: (size / 4_096 + 1) * 4_096,
      creationDate: date(daysAgo: daysAgo + 30),
      modificationDate: date(daysAgo: daysAgo),
      tagNames: tags,
      permissions: 0o644)
  }

  private static func date(daysAgo: Int) -> Date {
    referenceDate.addingTimeInterval(-Double(daysAgo) * 86_400)
  }
}

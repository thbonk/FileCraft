/*
 * UniqueNameGeneratorTests.swift
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
import Testing
@testable import FileCraft

internal struct UniqueNameGeneratorTests {

  // MARK: - Properties

  private let english = UniqueNameGenerator(language: Locale.Language(identifier: "en"))
  private let german = UniqueNameGenerator(language: Locale.Language(identifier: "de"))

  // MARK: - English

  @Test
  internal func `New folders are numbered when the name is taken`() {
    #expect(english.untitledFolderName(existingNames: []) == "untitled folder")
    #expect(english.untitledFolderName(existingNames: ["untitled folder"]) == "untitled folder 2")
    #expect(english.untitledFolderName(existingNames: ["untitled folder", "untitled folder 2"]) == "untitled folder 3")
  }

  @Test
  internal func `Duplicates get the copy suffix before the extension`() {
    #expect(english.duplicateName(of: "plan.key", isFolder: false, existingNames: ["plan.key"]) == "plan copy.key")
    #expect(
      english.duplicateName(of: "plan.key", isFolder: false, existingNames: ["plan.key", "plan copy.key"])
        == "plan copy 2.key")
  }

  @Test
  internal func `Folder names are never split at a dot`() {
    #expect(english.duplicateName(of: "my.folder", isFolder: true, existingNames: []) == "my.folder copy")
  }

  @Test
  internal func `Aliases, text files and archives get English names`() {
    #expect(english.aliasName(of: "Projects", existingNames: []) == "Projects alias")
    #expect(english.untitledTextFileName(existingNames: []) == "untitled.txt")
    #expect(english.archiveName(forItemNamed: nil, existingNames: []) == "Archive.zip")
    #expect(english.archiveName(forItemNamed: "Projects", existingNames: ["Projects.zip"]) == "Projects 2.zip")
  }

  @Test
  internal func `Collisions ignore case`() {
    #expect(english.availableName(for: "report.pdf", isFolder: false, existingNames: ["REPORT.PDF"]) == "report 2.pdf")
  }

  // MARK: - German

  @Test
  internal func `German names follow the glossary`() {
    #expect(german.untitledFolderName(existingNames: ["Neuer Ordner"]) == "Neuer Ordner 2")
    #expect(german.duplicateName(of: "Bericht.pdf", isFolder: false, existingNames: ["Bericht.pdf"]) == "Bericht Kopie.pdf")
    #expect(german.aliasName(of: "Projekte", existingNames: []) == "Projekte Alias")
    #expect(german.untitledTextFileName(existingNames: []) == "Unbenannt.txt")
    #expect(german.archiveName(forItemNamed: nil, existingNames: []) == "Archiv.zip")
  }
}

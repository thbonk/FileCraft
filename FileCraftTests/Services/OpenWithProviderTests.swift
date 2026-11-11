/*
 * OpenWithProviderTests.swift
 * FileCraftTests
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
import Testing
@testable import FileCraft

/// Uses the applications installed on the test machine, so the checks are about structure, not names.
internal struct OpenWithProviderTests {

  // MARK: - Tests

  @Test
  internal func `A text file lists each application once with the default one first`() throws {
    let directory = try TemporaryDirectory()
    let text = try directory.createFile("notes.txt", contents: "x")

    let applications = OpenWithProvider.applications(toOpen: [text])

    #expect(applications.isEmpty == false)
    #expect(applications.filter(\.isDefault).count <= 1)
    #expect(applications.contains(where: \.isDefault) == false || applications.first?.isDefault == true)
    #expect(Set(applications.map(\.url)).count == applications.count)
  }

  @Test
  internal func `Applications with the same name are told apart by their version`() {
    let pages = choice("/Applications/Pages.app", name: "Pages")
    let studio = choice("/Applications/Pages Creator Studio.app", name: "Pages")
    let textEdit = choice("/System/Applications/TextEdit.app", name: "TextEdit")
    let versions = [pages.url: "14.4", studio.url: "15.0"]

    let names = OpenWithProvider.disambiguatingNames([textEdit, pages, studio]) { versions[$0] }.map(\.name)

    #expect(names == ["TextEdit", "Pages (14.4)", "Pages (15.0)"])
  }

  @Test
  internal func `Applications with the same name and version are told apart by their file name`() {
    let pages = choice("/Applications/Pages.app", name: "Pages")
    let studio = choice("/Applications/Pages Creator Studio.app", name: "Pages")

    let names = OpenWithProvider.disambiguatingNames([pages, studio]) { _ in "14.4" }.map(\.name)

    #expect(names == ["Pages", "Pages (Pages Creator Studio)"])
  }

  @Test
  internal func `Several items offer only applications that open each of them`() throws {
    let directory = try TemporaryDirectory()
    let text = try directory.createFile("notes.txt", contents: "x")
    let html = try directory.createFile("page.html", contents: "<p>x</p>")

    let common = Set(OpenWithProvider.applications(toOpen: [text, html]).map(\.url))
    let forText = Set(OpenWithProvider.applications(toOpen: [text]).map(\.url))
    let forHTML = Set(OpenWithProvider.applications(toOpen: [html]).map(\.url))

    #expect(common.isSubset(of: forText))
    #expect(common.isSubset(of: forHTML))
  }

  // MARK: - Private

  private func choice(_ path: String, name: String) -> ApplicationChoice {
    ApplicationChoice(url: URL(filePath: path, directoryHint: .isDirectory), name: name, isDefault: false)
  }
}

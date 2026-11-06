/*
 * DefaultFileViewerTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-11-05.
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

/// Uses fake preferences only, so that the tests never change the file viewer of this Mac.
internal struct DefaultFileViewerTests {

  @Test
  internal func `Turning the setting on makes FileCraft the file viewer`() throws {
    let preferences = FakeFileViewerPreferences(fileViewer: nil)
    let viewer = viewer(preferences)

    try viewer.apply(usesFileCraft: true)

    #expect(preferences.fileViewer == "de.meandmymac.FileCraft")
    #expect(viewer.isFileCraft)
  }

  @Test
  internal func `Turning it off makes Finder the file viewer again`() throws {
    let preferences = FakeFileViewerPreferences(fileViewer: "de.meandmymac.FileCraft")

    try viewer(preferences).apply(usesFileCraft: false)

    #expect(preferences.fileViewer == DefaultFileViewer.finderBundleIdentifier)
  }

  @Test
  internal func `A preference that cannot be stored is reported with its file`() {
    let preferences = FakeFileViewerPreferences(fileViewer: nil, ignoresWrites: true)

    #expect(throws: FileViewerError(file: preferences.storageURL, expected: "de.meandmymac.FileCraft", found: nil)) {
      try viewer(preferences).apply(usesFileCraft: true)
    }
  }

  @Test
  internal func `Drift is corrected in both directions`() {
    let takenOver = FakeFileViewerPreferences(fileViewer: "com.other.viewer")
    viewer(takenOver).correctDrift(usesFileCraft: true)
    #expect(viewer(takenOver).isFileCraft)

    let leftOver = FakeFileViewerPreferences(fileViewer: "de.meandmymac.FileCraft")
    viewer(leftOver).correctDrift(usesFileCraft: false)
    #expect(leftOver.fileViewer == DefaultFileViewer.finderBundleIdentifier)
  }

  @Test
  internal func `Another viewer chosen while the setting is off stays`() {
    let preferences = FakeFileViewerPreferences(fileViewer: "com.other.viewer")

    viewer(preferences).correctDrift(usesFileCraft: false)

    #expect(preferences.fileViewer == "com.other.viewer")
    #expect(preferences.changes == 0)
  }

  private func viewer(_ preferences: FakeFileViewerPreferences) -> DefaultFileViewer {
    DefaultFileViewer(preferences: preferences, appBundleIdentifier: "de.meandmymac.FileCraft")
  }
}

/// The file viewer preference in memory; with `ignoresWrites`, storing has no effect, as when the preferences file
/// cannot be written.
private final class FakeFileViewerPreferences: FileViewerPreferences {

  private(set) var fileViewer: String?
  private(set) var changes = 0
  private let ignoresWrites: Bool

  let storageURL = URL(filePath: "/tmp/FakeGlobalPreferences.plist")

  init(fileViewer: String?, ignoresWrites: Bool = false) {
    self.fileViewer = fileViewer
    self.ignoresWrites = ignoresWrites
  }

  func setFileViewer(_ bundleIdentifier: String?) {
    changes += 1
    if ignoresWrites == false {
      fileViewer = bundleIdentifier
    }
  }
}

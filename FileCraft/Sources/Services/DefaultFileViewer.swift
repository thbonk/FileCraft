/*
 * DefaultFileViewer.swift
 * FileCraft
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
import OSLog

/// The system preference behind "Use FileCraft as default file viewer".
internal protocol FileViewerPreferences {
  /// The bundle identifier in the global `NSFileViewer` preference, or nil when it is not set, which means Finder.
  var fileViewer: String? { get }
  func setFileViewer(_ bundleIdentifier: String?)
  /// The file that stores the preference, which error messages name.
  var storageURL: URL { get }
}

/// The real preference: `NSFileViewer` in the global preferences domain of the current user.
internal struct SystemFileViewerPreferences: FileViewerPreferences {

  private static let key = "NSFileViewer" as CFString

  internal var fileViewer: String? {
    CFPreferencesCopyValue(Self.key, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? String
  }

  internal func setFileViewer(_ bundleIdentifier: String?) {
    CFPreferencesSetValue(
      Self.key, bundleIdentifier as CFString?, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
  }

  internal var storageURL: URL {
    FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Preferences/.GlobalPreferences.plist")
  }
}

/// Why the file viewer preference could not be changed.
nonisolated internal struct FileViewerError: LocalizedError, Equatable {

  /// The file that stores the preference.
  internal let file: URL
  /// The bundle identifier that should have been stored.
  internal let expected: String
  /// The bundle identifier read back after storing, or nil.
  internal let found: String?

  internal var errorDescription: String? {
    String(
      localized: "The file viewer could not be stored in “\(file.path(percentEncoded: false))”.",
      comment: "Error of the default file viewer setting; the value is the path of the global preferences file.")
  }

  /// The expected and the stored value, for the details line under the error.
  internal var details: String {
    "NSFileViewer: \(expected) → \(found ?? "–")"
  }
}

/// Makes FileCraft or Finder the file viewer of the system.
///
/// Applications that reveal files through `NSWorkspace`, as "Show in Finder" commands do, use the file viewer in the
/// global `NSFileViewer` preference. Which application opens folders is a different matter: macOS refuses to change
/// the default application for `public.folder` and `public.directory` (Launch Services answers `paramErr`, even for
/// the handler that is already set), so folders opened from other applications, as with `open ~/Documents`, always
/// open in Finder.
internal struct DefaultFileViewer {

  // MARK: - Properties

  internal static let finderBundleIdentifier = "com.apple.finder"

  private let preferences: any FileViewerPreferences
  private let appBundleIdentifier: String

  private static let logger = Logger(subsystem: "de.meandmymac.FileCraft", category: "DefaultFileViewer")

  // MARK: - Initialization

  internal init(
    preferences: any FileViewerPreferences = SystemFileViewerPreferences(),
    appBundleIdentifier: String = Bundle.main.bundleIdentifier ?? "de.meandmymac.FileCraft"
  ) {
    self.preferences = preferences
    self.appBundleIdentifier = appBundleIdentifier
  }

  // MARK: - State

  /// Whether FileCraft is the file viewer.
  internal var isFileCraft: Bool {
    preferences.fileViewer == appBundleIdentifier
  }

  // MARK: - Changing

  /// Makes FileCraft or Finder the file viewer and checks that the preference was stored.
  ///
  /// - Throws: `FileViewerError` naming the preferences file when the stored value differs.
  internal func apply(usesFileCraft: Bool) throws(FileViewerError) {
    let identifier = usesFileCraft ? appBundleIdentifier : Self.finderBundleIdentifier
    preferences.setFileViewer(identifier)
    let stored = preferences.fileViewer
    guard stored == identifier else {
      let failure = FileViewerError(file: preferences.storageURL, expected: identifier, found: stored)
      Self.logger.error("Storing the file viewer failed: \(failure.details, privacy: .public)")
      throw failure
    }
  }

  /// Brings the preference in line with the setting after something else changed it: with the setting on, FileCraft
  /// becomes the file viewer again; with it off, a preference that still names FileCraft goes back to Finder.
  /// Another file viewer the user chose with the setting off stays.
  internal func correctDrift(usesFileCraft: Bool) {
    guard usesFileCraft != isFileCraft else {
      return
    }
    do {
      try apply(usesFileCraft: usesFileCraft)
      Self.logger.info("Corrected the file viewer to \(usesFileCraft ? "FileCraft" : "Finder", privacy: .public)")
    } catch {
      Self.logger.error("Correcting the file viewer failed: \(error.details, privacy: .public)")
    }
  }
}

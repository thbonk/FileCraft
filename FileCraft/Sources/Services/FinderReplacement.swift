/*
 * FinderReplacement.swift
 * FileCraft
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

import AppKit
import OSLog

/// Starts and quits Finder.
internal protocol FinderControlling {
  var isRunning: Bool { get }
  /// Asks Finder to quit and waits until it did, for at most a few seconds.
  func quit() async
  func launch() async
  /// Starts Finder without waiting, for the moment FileCraft quits.
  func launchWithoutWaiting()
}

/// Finder's own preference that decides whether it draws the desktop icons.
internal protocol FinderDesktopPreference {
  /// Whether Finder shows the desktop; true when the preference is not set.
  var showsDesktop: Bool { get }
  func setShowsDesktop(_ showsDesktop: Bool)
}

/// The real Finder.
internal struct SystemFinderController: FinderControlling {

  private static let bundleIdentifier = "com.apple.finder"
  private static let quitTimeout = Duration.seconds(5)

  private var runningFinder: NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier).first
  }

  internal var isRunning: Bool {
    runningFinder != nil
  }

  internal func quit() async {
    guard let finder = runningFinder else {
      return
    }
    finder.terminate()
    let deadline = ContinuousClock.now + Self.quitTimeout
    while finder.isTerminated == false, ContinuousClock.now < deadline {
      try? await Task.sleep(for: .milliseconds(100))
    }
  }

  internal func launch() async {
    guard isRunning == false, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleIdentifier) else {
      return
    }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
  }

  internal func launchWithoutWaiting() {
    guard isRunning == false else {
      return
    }
    // `open` keeps running after FileCraft has quit, unlike a request that FileCraft would have to wait for.
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/open")
    process.arguments = ["-g", "-b", Self.bundleIdentifier]
    try? process.run()
  }
}

/// The `CreateDesktop` preference in Finder's preferences domain.
internal struct SystemFinderDesktopPreference: FinderDesktopPreference {

  private static let key = "CreateDesktop" as CFString
  private static let domain = "com.apple.finder" as CFString

  internal var showsDesktop: Bool {
    let value = CFPreferencesCopyValue(Self.key, Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    return (value as? Bool) ?? true
  }

  internal func setShowsDesktop(_ showsDesktop: Bool) {
    // Showing the desktop is Finder's default, so the key is removed instead of set.
    let value: CFPropertyList? = showsDesktop ? nil : kCFBooleanFalse
    CFPreferencesSetValue(Self.key, value, Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    CFPreferencesSynchronize(Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
  }
}

/// The Integration settings "Quit Finder when FileCraft launches" and "Hide Finder's desktop".
///
/// FileCraft quits Finder when it launches and starts it again when it quits. Hiding the desktop sets Finder's
/// `CreateDesktop` preference and restarts Finder, so the desktop stays empty even while FileCraft is not running.
internal struct FinderReplacement {

  // MARK: - Properties

  private let finder: any FinderControlling
  private let desktop: any FinderDesktopPreference

  private static let logger = Logger(subsystem: "de.meandmymac.FileCraft", category: "FinderReplacement")

  // MARK: - Initialization

  internal init(
    finder: any FinderControlling = SystemFinderController(),
    desktop: any FinderDesktopPreference = SystemFinderDesktopPreference()
  ) {
    self.finder = finder
    self.desktop = desktop
  }

  // MARK: - Launch and Quit

  /// At launch: hides Finder's desktop again if the setting is on and something showed it, and quits Finder when that
  /// setting is on. A desktop the user hid without FileCraft stays hidden.
  internal func applyAtLaunch(quitsFinder: Bool, hidesDesktop: Bool) async {
    if hidesDesktop, desktop.showsDesktop {
      await setHidesDesktop(true, restartsFinder: quitsFinder == false)
    }
    if quitsFinder {
      Self.logger.info("Quitting Finder at launch")
      await finder.quit()
    }
  }

  /// When FileCraft quits: starts Finder again if FileCraft quit it.
  internal func applyAtQuit(quitsFinder: Bool) {
    if quitsFinder {
      finder.launchWithoutWaiting()
    }
  }

  // MARK: - Changing the Settings

  /// Turns "Quit Finder when FileCraft launches" on or off: on quits Finder now, off starts it again.
  internal func setQuitsFinder(_ quitsFinder: Bool) async {
    if quitsFinder {
      await finder.quit()
    } else {
      await finder.launch()
    }
  }

  /// Hides or shows Finder's desktop; a running Finder restarts, so that it reads the preference again.
  internal func setHidesDesktop(_ hidesDesktop: Bool, restartsFinder: Bool = true) async {
    desktop.setShowsDesktop(hidesDesktop == false)
    guard restartsFinder, finder.isRunning else {
      return
    }
    await finder.quit()
    await finder.launch()
  }
}

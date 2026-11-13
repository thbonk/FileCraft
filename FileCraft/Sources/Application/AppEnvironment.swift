/*
 * AppEnvironment.swift
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

import Foundation

/// Facts about how FileCraft was started.
nonisolated internal enum AppEnvironment {

  /// Whether FileCraft runs as the host of the unit tests, which must not quit Finder or open the welcome window.
  internal static let isTestHost: Bool = {
    #if DEBUG
      ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    #else
      false
    #endif
  }()

  /// Whether this is a Debug build, which checks for updates only when asked.
  internal static let isDebugBuild: Bool = {
    #if DEBUG
      true
    #else
      false
    #endif
  }()

  /// The name of the test host's defaults suite.
  internal static let testHostDefaultsSuiteName = "de.meandmymac.FileCraft.TestHost"

  /// The defaults that hold FileCraft's settings: the standard defaults, or in the test host a suite of its own, so
  /// that test runs leave the user's settings alone.
  internal static var userDefaults: UserDefaults {
    guard isTestHost else {
      return .standard
    }
    _ = emptiesTestHostDefaults
    // The suite name is neither the bundle identifier nor the global domain, so the suite always exists.
    return UserDefaults(suiteName: testHostDefaultsSuiteName) ?? .standard
  }

  /// Empties the test host's suite once per launch, so that each test run sees the defaults of the settings spec.
  /// `UserDefaults` is not `Sendable`, so the suite itself is not kept in a static property.
  private static let emptiesTestHostDefaults: Void = {
    UserDefaults(suiteName: testHostDefaultsSuiteName)?.removePersistentDomain(forName: testHostDefaultsSuiteName)
  }()
}

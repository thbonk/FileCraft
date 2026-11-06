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
internal enum AppEnvironment {

  /// Whether FileCraft runs as the host of the unit tests, which must not quit Finder or open the welcome window.
  internal static let isTestHost: Bool = {
    #if DEBUG
      ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    #else
      false
    #endif
  }()
}

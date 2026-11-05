/*
 * AppConfigurationTests.swift
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

/// Checks the build configuration that FileCraft relies on at runtime.
///
/// The tests run inside the host app, so `Bundle.main` and the process
/// environment belong to FileCraft itself.
internal struct AppConfigurationTests {

  // MARK: - Tests

  @Test
  internal func `App uses the final bundle identifier`() {
    #expect(Bundle.main.bundleIdentifier == "de.meandmymac.FileCraft")
  }

  @Test
  internal func `App runs outside the App Sandbox`() {
    #expect(ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil)
  }
}

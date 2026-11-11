/*
 * TestEnvironment.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-11-11.
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

/// Facts about the machine the tests run on.
internal enum TestEnvironment {

  /// Whether the tests run on a shared CI machine, where timing is slower than on a Mac in use.
  ///
  /// The CI workflow sets `TEST_RUNNER_CI`; xcodebuild passes it to the test host as `CI`.
  internal static let isCI = ProcessInfo.processInfo.environment["CI"] == "true"
}

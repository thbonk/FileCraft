/*
 * HelperSelfTest.swift
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

#if DEBUG
import Foundation
import os

/// Registers the helper and pings it when FileCraft starts with `-FCHelperSelfTest`, logging each step, so that
/// registration and approval can be checked without any UI. Debug builds only.
internal enum HelperSelfTest {

  private static let logger = Logger(subsystem: "de.meandmymac.FileCraft", category: "HelperSelfTest")

  internal static func run() async {
    let client = PrivilegedHelperClient.shared
    logger.notice("Status before: \(String(describing: client.status), privacy: .public)")
    do {
      let status = try client.registerIfNeeded()
      logger.notice("Status after registering: \(String(describing: status), privacy: .public)")
      let result = try await client.send(.ping)
      logger.notice("Ping result: \(String(describing: result), privacy: .public)")
    } catch {
      logger.notice("Self-test failed: \(String(describing: error), privacy: .public); status now \(String(describing: client.status), privacy: .public)")
    }
  }
}
#endif

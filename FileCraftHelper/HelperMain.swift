/*
 * HelperMain.swift
 * FileCraftHelper
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
import os
import XPC

/// The privileged helper of FileCraft (design decision D11), a launchd daemon that `SMAppService` registers. It
/// accepts connections only from FileCraft signed by the same team and answers typed requests.
@main
internal enum HelperMain {

  internal static func main() {
    // Messages stay private in the unified log; only states and status codes are public.
    let logger = Logger(subsystem: HelperIdentity.helperIdentifier, category: "Helper")
    HelperAuthorizationRight.defineIfNeeded(logger: logger)
    var handler = HelperRequestHandler(isAuthorized: HelperAuthorizationRight.isAuthorized)
    // The operation and its outcome are public, the paths private.
    handler.log = { operation, paths, outcome in
      logger.info(
        "\(operation, privacy: .public) \(paths.joined(separator: " -> "), privacy: .private): \(outcome, privacy: .public)")
    }
    let requestHandler = handler
    do {
      let listener = try XPCListener(
        service: HelperIdentity.machServiceName,
        requirement: .isFromSameTeam(andMatchesSigningIdentifier: HelperIdentity.appIdentifier)
      ) { request in
        request.accept { (message: HelperRequest) -> (any Encodable)? in
          requestHandler.handle(message)
        }
      }
      logger.info("Listening, protocol version \(HelperIdentity.protocolVersion, privacy: .public)")
      // The XPC framework delivers messages on its own queues; the main queue keeps the process alive.
      withExtendedLifetime(listener) {
        dispatchMain()
      }
    } catch {
      logger.error("Listening failed: \(error.localizedDescription, privacy: .public)")
      exit(EXIT_FAILURE)
    }
  }
}

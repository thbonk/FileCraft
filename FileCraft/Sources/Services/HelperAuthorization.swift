/*
 * HelperAuthorization.swift
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
import Security
import Synchronization

/// When an obtained authorization may be used again: for at most five minutes, as the helper's right allows.
nonisolated internal struct AuthorizationReuse: Hashable, Sendable {

  /// How long an authorization is reused, in seconds.
  internal static let lifetime = TimeInterval(HelperIdentity.rightTimeout)

  internal let obtainedAt: Date

  internal func isValid(at date: Date) -> Bool {
    date.timeIntervalSince(obtainedAt) < Self.lifetime && date >= obtainedAt
  }
}

/// Obtains the helper's authorization right with Authorization Services, which shows the system dialog with Touch
/// ID where available, and reuses it for at most five minutes (design decision D11).
nonisolated internal final class HelperAuthorization: Sendable {

  // MARK: - Types

  internal enum AuthorizationError: Error, Hashable, Sendable {
    /// The user cancelled the dialog.
    case cancelled
    case failed(OSStatus)
  }

  private struct State {
    var authorization: AuthorizationRef?
    var reuse: AuthorizationReuse?
  }

  // MARK: - Properties

  internal static let shared = HelperAuthorization()

  private let state = Mutex(State())

  // MARK: - Obtaining

  /// The external form of an authorization for the right, for the next request. It asks the user only when no
  /// authorization of the last five minutes can be reused; the dialog runs off the main thread.
  ///
  /// - Parameter prompt: The localized explanation in the dialog.
  @concurrent
  internal func externalForm(prompt: String, now: Date = .now) async throws -> Data {
    try state.withLock { state in
      if let authorization = state.authorization, state.reuse?.isValid(at: now) == true {
        return try Self.externalForm(of: authorization)
      }
      if let authorization = state.authorization {
        AuthorizationFree(authorization, [.destroyRights])
        state.authorization = nil
      }
      let authorization = try Self.obtainRight(prompt: prompt)
      state.authorization = authorization
      state.reuse = AuthorizationReuse(obtainedAt: now)
      return try Self.externalForm(of: authorization)
    }
  }

  /// Forgets the authorization, so that the next request asks again.
  internal func reset() {
    state.withLock { state in
      if let authorization = state.authorization {
        AuthorizationFree(authorization, [.destroyRights])
      }
      state = State()
    }
  }

  // MARK: - Private

  private static func obtainRight(prompt: String) throws -> AuthorizationRef {
    var authorization: AuthorizationRef?
    let created = AuthorizationCreate(nil, nil, [], &authorization)
    guard created == errAuthorizationSuccess, let authorization else {
      throw AuthorizationError.failed(created)
    }
    let status = HelperIdentity.rightName.withCString { name in
      kAuthorizationEnvironmentPrompt.withCString { promptKey in
        prompt.withCString { promptValue in
          var right = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
          var promptItem = AuthorizationItem(
            name: promptKey, valueLength: strlen(promptValue), value: UnsafeMutableRawPointer(mutating: promptValue), flags: 0)
          return withUnsafeMutablePointer(to: &right) { rightPointer in
            withUnsafeMutablePointer(to: &promptItem) { promptPointer in
              var rights = AuthorizationRights(count: 1, items: rightPointer)
              var environment = AuthorizationEnvironment(count: 1, items: promptPointer)
              return AuthorizationCopyRights(
                authorization, &rights, &environment, [.interactionAllowed, .extendRights, .preAuthorize], nil)
            }
          }
        }
      }
    }
    guard status == errAuthorizationSuccess else {
      AuthorizationFree(authorization, [])
      throw status == errAuthorizationCanceled ? AuthorizationError.cancelled : AuthorizationError.failed(status)
    }
    return authorization
  }

  private static func externalForm(of authorization: AuthorizationRef) throws -> Data {
    var form = AuthorizationExternalForm()
    let status = AuthorizationMakeExternalForm(authorization, &form)
    guard status == errAuthorizationSuccess else {
      throw AuthorizationError.failed(status)
    }
    return withUnsafeBytes(of: form.bytes) { Data($0) }
  }
}

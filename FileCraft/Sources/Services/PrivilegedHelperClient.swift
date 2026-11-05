/*
 * PrivilegedHelperClient.swift
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
import os
import ServiceManagement
import Synchronization
import XPC

// MARK: - Registration

/// Whether the privileged helper can run.
nonisolated internal enum HelperStatus: Hashable, Sendable {
  case notRegistered
  /// Registered, but the user has not allowed it in System Settings yet.
  case requiresApproval
  case enabled
  /// launchd does not know the helper. `SMAppService` reports this before the first registration too, so only a
  /// `notFound` after registering means that the app bundle lacks the helper or its property list.
  case notFound
}

/// Registers and removes the helper's launch daemon.
nonisolated internal protocol HelperRegistrar: Sendable {
  var status: HelperStatus { get }
  func register() throws
  func unregister() async throws
}

/// The helper's launch daemon through `SMAppService` (design decision D11).
nonisolated internal struct DaemonRegistrar: HelperRegistrar {

  private var service: SMAppService {
    .daemon(plistName: HelperIdentity.plistName)
  }

  internal var status: HelperStatus {
    switch service.status {
    case .notRegistered:
      .notRegistered
    case .enabled:
      .enabled
    case .requiresApproval:
      .requiresApproval
    case .notFound:
      .notFound
    @unknown default:
      .notFound
    }
  }

  internal func register() throws {
    try service.register()
  }

  internal func unregister() async throws {
    try await service.unregister()
  }
}

// MARK: - Transport

/// Sends requests to the helper and receives its responses.
nonisolated internal protocol HelperTransport: Sendable {
  func send(_ request: HelperRequest) async throws -> HelperResponse
}

/// The XPC connection to the helper's Mach service. The peer must be the helper signed by the same team.
nonisolated internal final class XPCHelperTransport: HelperTransport {

  private let session = Mutex<XPCSession?>(nil)

  internal init() {}

  internal func send(_ request: HelperRequest) async throws -> HelperResponse {
    let session = try currentSession()
    return try await withCheckedThrowingContinuation { continuation in
      do {
        try session.send(request) { (result: Result<HelperResponse, any Error>) in
          continuation.resume(with: result)
        }
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

  /// The open session, or a new one after the previous one ended, for example because the helper restarted.
  private func currentSession() throws -> XPCSession {
    try session.withLock { session in
      if let session {
        return session
      }
      let newSession = try XPCSession(
        machService: HelperIdentity.machServiceName,
        requirement: .isFromSameTeam(andMatchesSigningIdentifier: HelperIdentity.helperIdentifier)
      ) { [weak self] _ in
        self?.session.withLock { $0 = nil }
      }
      session = newSession
      return newSession
    }
  }
}

// MARK: - Client

/// Talks to the privileged helper: registers it when needed, checks the protocol version and re-registers a helper
/// of another version, for example after an update of FileCraft (task 10.8).
nonisolated internal struct PrivilegedHelperClient: Sendable {

  // MARK: - Types

  internal enum ClientError: Error, Hashable, Sendable {
    /// The user has to allow the helper in System Settings first.
    case needsApproval
    /// The app bundle lacks the helper.
    case helperMissing
    /// The helper refused or failed the request.
    case refused(HelperFailure)
  }

  // MARK: - Properties

  internal static let shared = PrivilegedHelperClient()

  internal var registrar: any HelperRegistrar = DaemonRegistrar()
  internal var transport: any HelperTransport = XPCHelperTransport()

  private static let logger = Logger(subsystem: "de.meandmymac.FileCraft", category: "PrivilegedHelper")

  // MARK: - Registration

  internal var status: HelperStatus {
    registrar.status
  }

  /// Whether the helper still has to be registered.
  internal var needsRegistration: Bool {
    let status = registrar.status
    return status == .notRegistered || status == .notFound
  }

  /// Registers the helper unless it is; the result says whether the user still has to allow it.
  @discardableResult
  internal func registerIfNeeded() throws -> HelperStatus {
    guard needsRegistration else {
      return registrar.status
    }
    do {
      try registrar.register()
    } catch {
      // A daemon that waits for the user's approval is registered, but `register()` reports "Operation not
      // permitted" for it.
      let status = registrar.status
      guard status == .requiresApproval || status == .enabled else {
        throw error
      }
      return status
    }
    return registrar.status
  }

  // MARK: - Requests

  /// Sends `command` and returns the helper's result. A helper of another protocol version is registered anew and
  /// asked once more.
  ///
  /// - Throws: `ClientError.needsApproval` or `.helperMissing` before sending, `.refused` for the helper's
  ///   failures, and transport errors.
  internal func send(_ command: HelperCommand, authorization: Data? = nil) async throws -> HelperResult {
    try ensureEnabled()
    let request = HelperRequest(command: command, authorization: authorization)
    var response = try await transport.send(request)
    if Self.isVersionMismatch(response) {
      Self.logger.info("The helper speaks another protocol version; registering it again")
      try await reregister()
      try ensureEnabled()
      response = try await transport.send(request)
    }
    if case .failure(let failure) = response.result {
      throw ClientError.refused(failure)
    }
    return response.result
  }

  // MARK: - Private

  private func ensureEnabled() throws {
    switch try registerIfNeeded() {
    case .enabled:
      return
    case .requiresApproval, .notRegistered:
      throw ClientError.needsApproval
    case .notFound:
      throw ClientError.helperMissing
    }
  }

  private func reregister() async throws {
    try await registrar.unregister()
    try registrar.register()
  }

  private static func isVersionMismatch(_ response: HelperResponse) -> Bool {
    if case .failure(.versionMismatch) = response.result {
      return true
    }
    return response.version != HelperIdentity.protocolVersion
  }
}

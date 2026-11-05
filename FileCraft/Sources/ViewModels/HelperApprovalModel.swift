/*
 * HelperApprovalModel.swift
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
import Observation
import ServiceManagement

/// The installation and approval of the privileged helper (privileged helper spec, tasks 10.3 and 10.9). A
/// privileged action waits in `ensureReady()`: FileCraft first explains the helper and registers it only after the
/// user agrees, then explains the approval in System Settings and continues once the user allowed the helper and
/// returned to FileCraft.
@Observable
internal final class HelperApprovalModel {

  // MARK: - Types

  internal enum Phase: Hashable {
    /// Explains the helper before registering it.
    case install
    /// Explains that the helper must be allowed in System Settings.
    case approval
    /// Registering failed or the installation is damaged, with the reason.
    case failure(String)
  }

  // MARK: - Properties

  /// The flow of the app.
  internal static let shared = HelperApprovalModel()

  /// The step the sheet shows, or nil while no action waits.
  internal private(set) var phase: Phase?

  internal var isPresented: Bool {
    phase != nil
  }

  @ObservationIgnored private let client: PrivilegedHelperClient
  @ObservationIgnored private let openSettings: () -> Void
  @ObservationIgnored private var waiters: [CheckedContinuation<Bool, Never>] = []

  // MARK: - Initialization

  internal init(
    client: PrivilegedHelperClient = .shared,
    openSettings: @escaping () -> Void = { SMAppService.openSystemSettingsLoginItems() }
  ) {
    self.client = client
    self.openSettings = openSettings
  }

  // MARK: - Flow

  /// Whether the helper can run, after the user installed and allowed it when needed; false when the user
  /// cancelled.
  internal func ensureReady() async -> Bool {
    switch client.status {
    case .enabled:
      return true
    case .notRegistered, .notFound:
      // Before the first registration, the status can also be "not found".
      phase = .install
    case .requiresApproval:
      phase = .approval
    }
    return await withCheckedContinuation { continuation in
      waiters.append(continuation)
    }
  }

  /// Registers the helper after the user agreed to install it.
  internal func install() {
    do {
      switch try client.registerIfNeeded() {
      case .enabled:
        finish(isReady: true)
      case .requiresApproval, .notRegistered:
        phase = .approval
      case .notFound:
        phase = .failure(Self.missingHelperMessage)
      }
    } catch {
      phase = .failure(error.localizedDescription)
    }
  }

  /// Opens Login Items & Extensions in System Settings, where the user allows the helper.
  internal func openSystemSettings() {
    openSettings()
  }

  /// Checks the helper again, as when FileCraft becomes active; the waiting action continues once it is allowed.
  internal func recheck() {
    guard phase == .approval, client.status == .enabled else {
      return
    }
    finish(isReady: true)
  }

  internal func cancel() {
    finish(isReady: false)
  }

  // MARK: - Private

  private static var missingHelperMessage: String {
    String(localized: "The helper is missing from FileCraft. Please reinstall FileCraft.")
  }

  private func finish(isReady: Bool) {
    phase = nil
    let waiting = waiters
    waiters.removeAll()
    for waiter in waiting {
      waiter.resume(returning: isReady)
    }
  }
}

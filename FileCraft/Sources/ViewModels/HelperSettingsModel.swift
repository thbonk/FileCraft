/*
 * HelperSettingsModel.swift
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

/// The Helper pane of Settings: the privileged helper's status and the actions that install and remove it.
@Observable
internal final class HelperSettingsModel {

  // MARK: - Types

  /// The status as the pane shows it.
  internal enum DisplayStatus: Hashable {
    case notInstalled
    case waitingForApproval
    case enabled
    case error(String)
  }

  // MARK: - Properties

  internal private(set) var status: DisplayStatus = .notInstalled
  internal private(set) var isWorking = false

  @ObservationIgnored private let registrar: any HelperRegistrar
  @ObservationIgnored private let openSettings: () -> Void
  /// Whether this pane registered the helper; `notFound` after that means the bundle lacks the helper.
  @ObservationIgnored private var hasRegistered = false

  // MARK: - Initialization

  internal init(
    registrar: any HelperRegistrar = PrivilegedHelperClient.shared.registrar,
    openSettings: @escaping () -> Void = { SMAppService.openSystemSettingsLoginItems() }
  ) {
    self.registrar = registrar
    self.openSettings = openSettings
    refresh()
  }

  // MARK: - Actions

  internal var canInstall: Bool {
    isWorking == false && (status == .notInstalled || isError)
  }

  internal var canRemove: Bool {
    isWorking == false && (status == .enabled || status == .waitingForApproval)
  }

  /// Reads the status again, as after FileCraft becomes active.
  internal func refresh() {
    status = Self.displayStatus(for: registrar.status, hasRegistered: hasRegistered)
  }

  /// Registers the helper; macOS then asks the user to allow it in System Settings.
  internal func install() {
    hasRegistered = true
    do {
      try registrar.register()
      refresh()
    } catch {
      // A daemon waiting for approval is registered, but `register()` reports "Operation not permitted" for it.
      let current = registrar.status
      if current == .requiresApproval || current == .enabled {
        refresh()
      } else {
        status = .error(error.localizedDescription)
      }
    }
  }

  /// Unregisters the helper's daemon.
  internal func remove() async {
    isWorking = true
    defer {
      isWorking = false
    }
    do {
      try await registrar.unregister()
      hasRegistered = false
      refresh()
    } catch {
      status = .error(error.localizedDescription)
    }
  }

  internal func openSystemSettings() {
    openSettings()
  }

  /// The pane's status for a registrar status. `notFound` means "not installed" until FileCraft registered the
  /// helper, because `SMAppService` reports it before the first registration too.
  internal static func displayStatus(for status: HelperStatus, hasRegistered: Bool) -> DisplayStatus {
    switch status {
    case .notRegistered:
      .notInstalled
    case .requiresApproval:
      .waitingForApproval
    case .enabled:
      .enabled
    case .notFound:
      hasRegistered ? .error(String(localized: "The helper is missing from the FileCraft application. Reinstall FileCraft.")) : .notInstalled
    }
  }

  // MARK: - Private

  private var isError: Bool {
    if case .error = status {
      return true
    }
    return false
  }
}

/*
 * HelperSettingsModelTests.swift
 * FileCraftTests
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
import Synchronization
import Testing
@testable import FileCraft

internal struct HelperSettingsModelTests {

  @Test
  internal func `Statuses map to what the pane shows`() {
    #expect(HelperSettingsModel.displayStatus(for: .notRegistered, hasRegistered: false) == .notInstalled)
    #expect(HelperSettingsModel.displayStatus(for: .requiresApproval, hasRegistered: true) == .waitingForApproval)
    #expect(HelperSettingsModel.displayStatus(for: .enabled, hasRegistered: false) == .enabled)
    #expect(HelperSettingsModel.displayStatus(for: .notFound, hasRegistered: false) == .notInstalled)
    if case .error = HelperSettingsModel.displayStatus(for: .notFound, hasRegistered: true) {
    } else {
      Issue.record("notFound after registering must be an error")
    }
  }

  @Test
  internal func `Install waits for approval and Remove unregisters`() async {
    let registrar = FakeRegistrar(status: .notRegistered)
    let model = HelperSettingsModel(registrar: registrar, openSettings: {})
    #expect(model.canInstall)

    model.install()
    #expect(model.status == .waitingForApproval)
    #expect(model.canRemove)

    await model.remove()
    #expect(model.status == .notInstalled)
    #expect(registrar.status == .notRegistered)
  }

  @Test
  internal func `Open System Settings uses the given action`() {
    var opened = false
    let model = HelperSettingsModel(registrar: FakeRegistrar(status: .requiresApproval), openSettings: { opened = true })

    model.openSystemSettings()

    #expect(opened)
  }
}

/// A launch daemon registration in memory that waits for approval after registering.
nonisolated private final class FakeRegistrar: HelperRegistrar {

  private let state: Mutex<HelperStatus>

  init(status: HelperStatus) {
    state = Mutex(status)
  }

  var status: HelperStatus {
    state.withLock { $0 }
  }

  func register() throws {
    state.withLock { $0 = .requiresApproval }
  }

  func unregister() async throws {
    state.withLock { $0 = .notRegistered }
  }
}

/*
 * WelcomeModelTests.swift
 * FileCraftTests
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
import Testing
@testable import FileCraft

/// Uses a private defaults suite, so that the tests never change the user's onboarding state.
internal final class WelcomeModelTests {

  private let suiteName = "FileCraftTests.\(UUID().uuidString)"
  private let settings: SettingsStore

  internal init() throws {
    settings = SettingsStore(defaults: try #require(UserDefaults(suiteName: suiteName)))
  }

  isolated deinit {
    UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
  }

  @Test
  internal func `The steps go forward and back within their range`() {
    let model = WelcomeModel(settings: settings)

    model.goBack()
    #expect(model.step == .welcome)
    model.goForward()
    model.goForward()
    model.goForward()
    #expect(model.step == .defaultFileViewer)
    #expect(model.isLastStep)
    model.restart()
    #expect(model.step == .welcome)
  }

  @Test
  internal func `The window shows at launch until it is completed`() {
    #expect(WelcomeModel.showsAtLaunch(settings: settings))

    WelcomeModel(settings: settings).complete()

    #expect(WelcomeModel.showsAtLaunch(settings: settings) == false)
  }

  @Test
  internal func `Refreshing reads the Full Disk Access status`() async {
    let probe = FullDiskAccessProbe(locations: [URL(filePath: "/protected")], read: { _ in .notPermitted })
    let model = WelcomeModel(probe: probe, settings: settings)

    await model.refreshFullDiskAccess()

    #expect(model.fullDiskAccess == .notGranted)
  }
}

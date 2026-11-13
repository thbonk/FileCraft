/*
 * UpdaterModelTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-11-12.
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

/// Uses a fake updater and a private defaults suite per test, removed again in `deinit`.
internal final class UpdaterModelTests {

  // MARK: - Properties

  private let suiteName = "FileCraftTests.\(UUID().uuidString)"
  private let defaults: UserDefaults
  private let settings: SettingsStore
  private let updater = FakeUpdater()

  // MARK: - Initialization

  internal init() throws {
    defaults = try #require(UserDefaults(suiteName: suiteName))
    settings = SettingsStore(defaults: defaults)
  }

  isolated deinit {
    defaults.removePersistentDomain(forName: suiteName)
  }

  // MARK: - Policy

  @Test
  internal func `Pre-releases come from the beta channel only when they are included`() {
    #expect(UpdatePolicy.allowedChannels(includesPreReleases: false).isEmpty)
    #expect(UpdatePolicy.allowedChannels(includesPreReleases: true) == ["beta"])
  }

  @Test
  internal func `Debug builds check for updates only when asked`() {
    #expect(UpdatePolicy.allowsCheck(.scheduled, isDebugBuild: true) == false)
    #expect(UpdatePolicy.allowsCheck(.requested, isDebugBuild: true))
    #expect(UpdatePolicy.allowsCheck(.scheduled, isDebugBuild: false))
  }

  // MARK: - Settings

  @Test
  internal func `The update settings write through to the updater`() {
    let model = makeModel()

    model.checksAutomatically = false
    model.installsAutomatically = true
    model.checkForUpdates()

    #expect(updater.automaticallyChecksForUpdates == false)
    #expect(updater.automaticallyDownloadsUpdates)
    #expect(updater.checks == 1)
  }

  @Test
  internal func `Changes the updater made itself show in the settings`() {
    let model = makeModel()

    updater.automaticallyDownloadsUpdates = true
    updater.canCheckForUpdates = false
    model.refresh()

    #expect(model.installsAutomatically)
    #expect(model.canCheckForUpdates == false)
  }

  @Test
  internal func `Including pre-releases is stored in the settings`() {
    let model = makeModel()

    model.includesPreReleases = true

    #expect(settings.value(for: SettingsKeys.includesPreReleases))
    #expect(makeModel().includesPreReleases)
  }

  @Test
  internal func `Without an updater, Check for Updates is unavailable`() {
    let model = UpdaterModel(updater: nil, settings: settings, isBusy: { false }, confirmQuit: { _ in })

    #expect(model.canCheckForUpdates == false)
  }

  // MARK: - Relaunch

  @Test
  internal func `A relaunch waits for the quit confirmation while operations run`() {
    var replies: [@MainActor (Bool) -> Void] = []
    let model = UpdaterModel(updater: updater, settings: settings, isBusy: { true }, confirmQuit: { replies.append($0) })
    var relaunches = 0

    let postponesFirst = model.shouldPostponeRelaunch { relaunches += 1 }
    replies.first?(false)
    let afterCancel = relaunches
    let postponesSecond = model.shouldPostponeRelaunch { relaunches += 1 }
    replies.last?(true)

    #expect(postponesFirst)
    #expect(postponesSecond)
    #expect(afterCancel == 0)
    #expect(relaunches == 1)
  }

  @Test
  internal func `A relaunch goes ahead when no operations run`() {
    var asked = false
    let model = UpdaterModel(updater: updater, settings: settings, isBusy: { false }, confirmQuit: { _ in asked = true })

    let postpones = model.shouldPostponeRelaunch {}

    #expect(postpones == false)
    #expect(asked == false)
  }

  // MARK: - Helpers

  private func makeModel() -> UpdaterModel {
    UpdaterModel(updater: updater, settings: settings, isBusy: { false }, confirmQuit: { _ in })
  }
}

/// Records what the model asks of Sparkle's updater.
private final class FakeUpdater: SoftwareUpdater {
  var canCheckForUpdates = true
  var automaticallyChecksForUpdates = true
  var automaticallyDownloadsUpdates = false
  private(set) var checks = 0

  func checkForUpdates() {
    checks += 1
  }
}

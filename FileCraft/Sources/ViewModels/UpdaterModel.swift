/*
 * UpdaterModel.swift
 * FileCraft
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
import Observation
import Sparkle

/// The parts of Sparkle's updater that FileCraft uses, so that tests can replace it.
internal protocol SoftwareUpdater: AnyObject {
  var canCheckForUpdates: Bool { get }
  var automaticallyChecksForUpdates: Bool { get set }
  var automaticallyDownloadsUpdates: Bool { get set }
  func checkForUpdates()
}

extension SPUUpdater: SoftwareUpdater {}

/// FileCraft's rules for software updates, apart from Sparkle so that tests can check them.
nonisolated internal enum UpdatePolicy {

  /// How an update check was started.
  internal enum Check {
    /// Check for Updates….
    case requested
    /// Sparkle's daily check.
    case scheduled
    /// A probe that only looks for update information.
    case information
  }

  /// The appcast channel of pre-releases.
  internal static let preReleaseChannel = "beta"

  /// The channels besides the default channel that updates may come from.
  internal static func allowedChannels(includesPreReleases: Bool) -> Set<String> {
    includesPreReleases ? [preReleaseChannel] : []
  }

  /// Debug builds check only when asked, so that they never offer a published release in place of themselves.
  internal static func allowsCheck(_ check: Check, isDebugBuild: Bool) -> Bool {
    isDebugBuild == false || check != .scheduled
  }
}

/// Drives software updates through Sparkle: the Check for Updates… command and the update settings of the General
/// pane. Sparkle shows its own update windows, which it localizes in English and German.
///
/// The test host has no updater, so that tests never check for updates or show Sparkle's windows.
@Observable
internal final class UpdaterModel {

  // MARK: - Properties

  internal static let shared = UpdaterModel()

  /// Whether Check for Updates… is available; not while a check runs, and never without an updater.
  internal private(set) var canCheckForUpdates = false

  internal var checksAutomatically = false {
    didSet {
      if let updater, updater.automaticallyChecksForUpdates != checksAutomatically {
        updater.automaticallyChecksForUpdates = checksAutomatically
      }
    }
  }

  /// Whether found updates are downloaded and installed without asking.
  internal var installsAutomatically = false {
    didSet {
      if let updater, updater.automaticallyDownloadsUpdates != installsAutomatically {
        updater.automaticallyDownloadsUpdates = installsAutomatically
      }
    }
  }

  internal var includesPreReleases = false {
    didSet {
      if settings.value(for: SettingsKeys.includesPreReleases) != includesPreReleases {
        settings.set(includesPreReleases, for: SettingsKeys.includesPreReleases)
      }
    }
  }

  @ObservationIgnored private let updater: (any SoftwareUpdater)?
  @ObservationIgnored private let settings: SettingsStore
  @ObservationIgnored private let isBusy: () -> Bool
  @ObservationIgnored private let confirmQuit: (@escaping @MainActor (Bool) -> Void) -> Void
  /// Sparkle's controller and its delegate, which Sparkle does not retain.
  @ObservationIgnored private var controller: SPUStandardUpdaterController?
  @ObservationIgnored private var delegate: UpdaterDelegate?
  @ObservationIgnored private var observations: [NSKeyValueObservation] = []
  @ObservationIgnored private var defaultsChanges: Task<Void, Never>?

  // MARK: - Initialization

  /// Creates a model around `updater`, which is `nil` where updates are unavailable.
  internal init(
    updater: (any SoftwareUpdater)?,
    settings: SettingsStore = SettingsStore(),
    isBusy: @escaping () -> Bool,
    confirmQuit: @escaping (@escaping @MainActor (Bool) -> Void) -> Void
  ) {
    self.updater = updater
    self.settings = settings
    self.isBusy = isBusy
    self.confirmQuit = confirmQuit
    refresh()
  }

  /// Starts Sparkle, except in the test host; running operations hold back an update's relaunch.
  private convenience init() {
    let delegate = UpdaterDelegate()
    let controller = AppEnvironment.isTestHost
      ? nil
      : SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: delegate, userDriverDelegate: nil)
    self.init(
      updater: controller?.updater,
      isBusy: { OperationQueueModel.shared.isBusy },
      confirmQuit: { reply in OperationQueueModel.shared.confirmQuit(reply: reply) })
    self.controller = controller
    self.delegate = delegate
    delegate.model = self
    if let updater = controller?.updater {
      observeChanges(of: updater)
    }
  }

  // MARK: - Updates

  internal func checkForUpdates() {
    updater?.checkForUpdates()
  }

  /// Reads the settings again, after Sparkle changed them or Restore Defaults removed them.
  internal func refresh() {
    let canCheck = updater?.canCheckForUpdates ?? false
    let checks = updater?.automaticallyChecksForUpdates ?? false
    let installs = updater?.automaticallyDownloadsUpdates ?? false
    let preReleases = settings.value(for: SettingsKeys.includesPreReleases)
    if canCheckForUpdates != canCheck {
      canCheckForUpdates = canCheck
    }
    if checksAutomatically != checks {
      checksAutomatically = checks
    }
    if installsAutomatically != installs {
      installsAutomatically = installs
    }
    if includesPreReleases != preReleases {
      includesPreReleases = preReleases
    }
  }

  /// Holds back the relaunch that installs an update while operations run, until the user decided in the quit
  /// confirmation, as for ⌘Q. Returns whether the relaunch waits; `proceed` continues it.
  internal func shouldPostponeRelaunch(proceed: @escaping @MainActor () -> Void) -> Bool {
    guard isBusy() else {
      return false
    }
    confirmQuit { quits in
      if quits {
        proceed()
      }
    }
    return true
  }

  // MARK: - Private

  private func observeChanges(of updater: SPUUpdater) {
    let refresh: @Sendable (SPUUpdater, Any) -> Void = { [weak self] _, _ in
      Task { @MainActor in
        self?.refresh()
      }
    }
    observations = [
      updater.observe(\.canCheckForUpdates, changeHandler: refresh),
      updater.observe(\.automaticallyChecksForUpdates, changeHandler: refresh),
      updater.observe(\.automaticallyDownloadsUpdates, changeHandler: refresh),
    ]
    // Restore Defaults and Reset All Settings remove Sparkle's keys without telling Sparkle.
    defaultsChanges = Task { [weak self] in
      for await _ in NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification).map({ _ in () }) {
        self?.refresh()
      }
    }
  }
}

/// Answers Sparkle's questions for `UpdaterModel`. Sparkle keeps its delegate only weakly.
private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {

  weak var model: UpdaterModel?

  func allowedChannels(for updater: SPUUpdater) -> Set<String> {
    UpdatePolicy.allowedChannels(includesPreReleases: model?.includesPreReleases ?? false)
  }

  func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
    let check: UpdatePolicy.Check = switch updateCheck {
    case .updates: .requested
    case .updatesInBackground: .scheduled
    default: .information
    }
    guard UpdatePolicy.allowsCheck(check, isDebugBuild: AppEnvironment.isDebugBuild) else {
      throw NSError(
        domain: "de.meandmymac.FileCraft.Updates", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Debug builds check for updates only when asked."])
    }
  }

  func updater(
    _ updater: SPUUpdater,
    shouldPostponeRelaunchForUpdate item: SUAppcastItem,
    untilInvokingBlock installHandler: @escaping () -> Void
  ) -> Bool {
    // Sparkle calls its delegate and this handler on the main thread; it only lacks the Sendable annotation.
    nonisolated(unsafe) let installHandler = installHandler
    return model?.shouldPostponeRelaunch { installHandler() } ?? false
  }
}

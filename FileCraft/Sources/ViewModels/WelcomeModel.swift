/*
 * WelcomeModel.swift
 * FileCraft
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
import Observation

/// The welcome window: its steps, the Full Disk Access status and whether onboarding is completed.
@Observable
internal final class WelcomeModel {

  // MARK: - Types

  internal enum Step: Int, CaseIterable, Hashable {
    case welcome
    case fullDiskAccess
    case defaultFileViewer
  }

  // MARK: - Properties

  internal private(set) var step: Step = .welcome
  internal private(set) var fullDiskAccess: FullDiskAccessStatus = .unknown

  @ObservationIgnored private let probe: FullDiskAccessProbe
  @ObservationIgnored private let settings: SettingsStore

  internal var isFirstStep: Bool {
    step == .welcome
  }

  internal var isLastStep: Bool {
    step == Step.allCases.last
  }

  // MARK: - Initialization

  internal init(probe: FullDiskAccessProbe = FullDiskAccessProbe(), settings: SettingsStore = SettingsStore()) {
    self.probe = probe
    self.settings = settings
  }

  // MARK: - First Launch

  /// Whether the welcome window opens at launch: until the user finished or skipped it once.
  internal static func showsAtLaunch(settings: SettingsStore = SettingsStore()) -> Bool {
    settings.value(for: SettingsKeys.hasCompletedWelcome) == false
  }

  // MARK: - Steps

  /// Starts at the first step, as when the window opens again.
  internal func restart() {
    step = .welcome
  }

  internal func goForward() {
    if let next = Step(rawValue: step.rawValue + 1) {
      step = next
    }
  }

  internal func goBack() {
    if let previous = Step(rawValue: step.rawValue - 1) {
      step = previous
    }
  }

  /// Done, Skip and closing the window: the window no longer opens at launch.
  internal func complete() {
    settings.set(true, for: SettingsKeys.hasCompletedWelcome)
  }

  // MARK: - Full Disk Access

  /// Reads the Full Disk Access status again, as when FileCraft becomes active.
  internal func refreshFullDiskAccess() async {
    fullDiskAccess = await probe.status()
  }
}

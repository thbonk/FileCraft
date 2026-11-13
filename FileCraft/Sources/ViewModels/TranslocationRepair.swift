/*
 * TranslocationRepair.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-13.
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

import AppKit
import Foundation
import Observation

/// Lets a translocated FileCraft run in place again, so that it can update itself (issue #5).
///
/// A FileCraft that was downloaded and then moved without Finder, for example with FileCraft itself, still runs from a
/// temporary copy, which Sparkle refuses to update. The first browser window offers to let FileCraft run in place, as
/// a move in Finder would, and to relaunch it from its own location.
@Observable
internal final class TranslocationRepair {

  // MARK: - Types

  internal enum State: Equatable {
    case inPlace
    /// macOS runs FileCraft from a temporary copy; `original` is FileCraft's own location, if known.
    case translocated(original: URL?)
  }

  // MARK: - Properties

  internal static let shared = TranslocationRepair(state: .current)

  internal let state: State
  @ObservationIgnored private var hasOffered = false

  // MARK: - Initialization

  internal init(state: State) {
    self.state = state
  }

  // MARK: - Offering

  /// Whether the caller presents the offer: true once while FileCraft runs translocated.
  internal func claimOffer() -> Bool {
    guard case .translocated = state, hasOffered == false else {
      return false
    }
    hasOffered = true
    return true
  }

  /// Lets FileCraft at its own location run in place and relaunches it from there.
  internal func repairAndRelaunch() throws {
    guard case .translocated(let original?) = state else {
      return
    }
    try Quarantine.allowRunningInPlace(at: original)
    // The new FileCraft starts once this one has quit, so that it does not hand over to it.
    let relaunch = Process()
    relaunch.executableURL = URL(filePath: "/bin/sh")
    relaunch.arguments = [
      "-c", #"while /bin/kill -0 "$0" 2> /dev/null; do /bin/sleep 0.2; done; exec /usr/bin/open "$1""#,
      String(ProcessInfo.processInfo.processIdentifier), original.path(percentEncoded: false),
    ]
    try relaunch.run()
    NSApplication.shared.terminate(nil)
  }
}

extension TranslocationRepair.State {

  /// The state of this FileCraft; the test host and a process that hands over never ask.
  fileprivate static var current: Self {
    let bundle = Bundle.main.bundleURL
    guard
      AppEnvironment.isTestHost == false, InstanceHandover.isActive == false,
      Translocation.isTranslocatedPath(bundle.path(percentEncoded: false))
    else {
      return .inPlace
    }
    return .translocated(original: Translocation.originalURL(ofTranslocated: bundle))
  }
}

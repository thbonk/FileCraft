/*
 * LaunchRestoration.swift
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

import AppKit

/// Tracks whether AppKit has finished restoring the windows of the last session.
///
/// SwiftUI creates a restored window's views first and fills their `@SceneStorage` only when AppKit restores the
/// window's state, after the views' first `.task` started. Windows wait here before they read their stored state;
/// windows opened later find restoration finished and do not wait.
internal enum LaunchRestoration {

  // MARK: - Properties

  /// How long a window waits at most, in case AppKit never reports the end of restoration.
  private static let timeout = Duration.seconds(3)

  private static var isFinished = false
  private static var waiters: [CheckedContinuation<Void, Never>] = []
  private static var observer: (any NSObjectProtocol)?

  // MARK: - Starting

  /// Starts listening for the end of window restoration; call it before the first window appears.
  internal static func start() {
    guard observer == nil, isFinished == false else {
      return
    }
    observer = NotificationCenter.default.addObserver(
      forName: NSApplication.didFinishRestoringWindowsNotification, object: nil, queue: .main
    ) { _ in
      MainActor.assumeIsolated {
        finish()
      }
    }
    Task {
      try? await Task.sleep(for: timeout)
      finish()
    }
  }

  // MARK: - Waiting

  /// Returns once AppKit has restored the windows of the last session, or at once when it has.
  internal static func waitUntilFinished() async {
    guard isFinished == false else {
      return
    }
    await withCheckedContinuation { continuation in
      waiters.append(continuation)
    }
  }

  // MARK: - Private

  private static func finish() {
    guard isFinished == false else {
      return
    }
    isFinished = true
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
    let waiting = waiters
    waiters.removeAll()
    for waiter in waiting {
      waiter.resume()
    }
  }
}

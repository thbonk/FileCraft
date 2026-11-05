/*
 * AppDelegate.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-03.
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

/// The application delegate, for what SwiftUI has no API for (design decision D9): the confirmation before quitting
/// while file operations run. The confirmation itself is a SwiftUI alert in the Operations window.
internal final class AppDelegate: NSObject, NSApplicationDelegate {

  /// Defers quitting while operations run or are paused, until the user decided in the Operations window.
  internal func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    let operations = OperationQueueModel.shared
    guard operations.isBusy else {
      return .terminateNow
    }
    operations.confirmQuit { shouldQuit in
      sender.reply(toApplicationShouldTerminate: shouldQuit)
    }
    return .terminateLater
  }

  /// An authorization for the privileged helper never outlives FileCraft.
  internal func applicationWillTerminate(_ notification: Notification) {
    HelperAuthorization.shared.reset()
  }
}

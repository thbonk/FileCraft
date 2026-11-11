/*
 * ActiveBrowserWindow.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-11.
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

import Observation

/// The browser window that was activated last, for windows outside the browser windows such as the View Options
/// panel. On macOS 27 a SwiftUI utility window does not receive the main window's focused scene values, so each
/// browser window reports itself here when it becomes active and when it closes.
@Observable
internal final class ActiveBrowserWindow {

  // MARK: - Properties

  internal static let shared = ActiveBrowserWindow()

  /// The browser window activated last, or nil once it closed.
  internal private(set) var window: BrowserWindowModel?

  // MARK: - Activation

  /// Makes `window` the active browser window.
  internal func activate(_ window: BrowserWindowModel) {
    if self.window !== window {
      self.window = window
    }
  }

  /// Forgets `window` when it is the active one; another window becomes active when it is activated.
  internal func close(_ window: BrowserWindowModel) {
    if self.window === window {
      self.window = nil
    }
  }
}

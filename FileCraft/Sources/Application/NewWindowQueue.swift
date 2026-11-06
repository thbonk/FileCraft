/*
 * NewWindowQueue.swift
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

/// The locations of browser windows that are about to open, oldest first.
///
/// The browser window group opens windows without a value, so a window that should show a particular folder, as when
/// folders open in new windows, takes its location from here when it appears.
internal enum NewWindowQueue {

  private static var locations: [Location] = []

  /// Asks the next new browser window to show `location`.
  internal static func push(_ location: Location) {
    locations.append(location)
  }

  /// Takes the oldest waiting location, or nil when no window asked for one.
  internal static func pop() -> Location? {
    locations.isEmpty ? nil : locations.removeFirst()
  }
}

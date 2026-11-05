/*
 * SettingsStore.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-10-30.
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

/// Reads, writes, registers and resets the preferences defined in `SettingsKeys`.
nonisolated internal struct SettingsStore {

  // MARK: - Properties

  private let defaults: UserDefaults

  // MARK: - Initialization

  internal init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  // MARK: - Values

  /// Registers every default so that `UserDefaults` and `@AppStorage` agree on unset keys.
  internal func registerDefaults() {
    defaults.register(defaults: Dictionary(uniqueKeysWithValues: SettingsKeys.all.map { ($0.name, $0.defaultValue as Any) }))
  }

  /// Makes macOS keep FileCraft's windows on quit exactly when "Restore windows" is on.
  ///
  /// With "Close windows when quitting an application" on in System Settings, as it is by default, macOS
  /// discards the window state on ⌘Q, and with it each window's tabs, locations and view modes. The value in
  /// FileCraft's own domain overrides the system setting for FileCraft only. Call it at launch and whenever
  /// "Restore windows" changes.
  internal func applyWindowRestoration() {
    defaults.set(value(for: SettingsKeys.restoresWindows), forKey: Self.quitKeepsWindowsKey)
  }

  /// The AppKit preference behind "Close windows when quitting an application", inverted.
  internal static let quitKeepsWindowsKey = "NSQuitAlwaysKeepsWindows"

  /// Returns the stored value of `key`, or its default when nothing valid is stored.
  internal func value<Value>(for key: SettingsKey<Value>) -> Value {
    defaults.object(forKey: key.name).flatMap(Value.init(propertyListValue:)) ?? key.defaultValue
  }

  internal func set<Value>(_ value: Value, for key: SettingsKey<Value>) {
    defaults.set(value.propertyListValue, forKey: key.name)
  }

  // MARK: - Resetting

  /// Restores the defaults of all keys shown in `pane`.
  internal func restoreDefaults(of pane: SettingsPane) {
    remove(SettingsKeys.all.filter { $0.pane == pane })
  }

  /// Shows all warnings again that the user turned off.
  internal func resetWarnings() {
    remove(SettingsKeys.all.filter(\.isWarning))
  }

  /// Restores the defaults of all keys, including saved view defaults.
  internal func resetAll() {
    remove(SettingsKeys.all)
    for key in ViewMode.allCases.map(Self.viewDefaultsKey) + [Self.listColumnDefaultsKey] {
      defaults.removeObject(forKey: key)
    }
  }

  // MARK: - View Defaults

  /// The view settings saved with "Use as Defaults" for `mode`.
  internal func viewDefaults(for mode: ViewMode) -> ViewSettings? {
    defaults.data(forKey: Self.viewDefaultsKey(mode)).flatMap { try? JSONDecoder().decode(ViewSettings.self, from: $0) }
  }

  /// Saves `settings` as the defaults for new tabs in its view mode.
  internal func saveViewDefaults(_ settings: ViewSettings) {
    defaults.set(try? JSONEncoder().encode(settings), forKey: Self.viewDefaultsKey(settings.viewMode))
  }

  /// The encoded list column layout saved with "Use as Defaults".
  internal func listColumnDefaults() -> Data? {
    defaults.data(forKey: Self.listColumnDefaultsKey)
  }

  internal func saveListColumnDefaults(_ data: Data) {
    defaults.set(data, forKey: Self.listColumnDefaultsKey)
  }

  private static let listColumnDefaultsKey = "viewDefaults.listColumns"

  private static func viewDefaultsKey(_ mode: ViewMode) -> String {
    "viewDefaults.\(mode.rawValue)"
  }

  // MARK: - Private

  private func remove(_ keys: [AnySettingsKey]) {
    for key in keys {
      defaults.removeObject(forKey: key.name)
    }
  }
}

/*
 * LocalizedLookup.swift
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

/// Looks up strings of the app's String Catalog in the app's language or in an explicit language.
///
/// Keys used through this lookup are not extracted by the compiler, so they are added to the
/// catalog by hand with extraction state "manual".
nonisolated internal enum LocalizedLookup {

  /// Returns the localization of `key`, or `key` itself when no localization exists.
  ///
  /// - Parameter language: The language to use, or nil for the app's current language.
  internal static func string(_ key: String, bundle: Bundle = .main, language: Locale.Language? = nil) -> String {
    guard let language else {
      return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    return bundle.localizedString(forKey: key, value: key, table: nil, localizations: [language])
  }
}

/*
 * SpotlightAttributes.swift
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

import CoreServices
import Foundation

/// Reads metadata that only Spotlight provides.
nonisolated internal enum SpotlightAttributes {

  /// Returns the dates the items were last opened, by path; items without a date are left out.
  ///
  /// Stops early when the calling task is cancelled.
  @concurrent
  internal static func lastOpenedDates(of urls: [URL]) async -> [String: Date] {
    var dates: [String: Date] = [:]
    for (index, url) in urls.enumerated() {
      if index.isMultiple(of: 128), Task.isCancelled {
        break
      }
      guard
        let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL),
        let date = MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
      else {
        continue
      }
      dates[url.path(percentEncoded: false)] = date
    }
    return dates
  }

  /// Returns the short version string of an app or other bundle.
  @concurrent
  internal static func bundleVersion(of url: URL) async -> String? {
    Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
  }
}

/*
 * Translocation.swift
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

import Darwin
import Foundation

/// App Translocation: macOS runs a downloaded app from a temporary, read-only copy until the app may run in place.
nonisolated internal enum Translocation {

  /// Whether `path` lies in a translocated copy, tested as Sparkle tests it before it refuses to update.
  internal static func isTranslocatedPath(_ path: String) -> Bool {
    path.contains("/AppTranslocation/")
  }

  /// The place of the app that macOS runs translocated from `url`, or nil when it is unknown.
  ///
  /// It uses `SecTranslocateCreateOriginalPathForURL` from the Security framework, which macOS has but the SDK does
  /// not declare, so it is looked up at runtime.
  internal static func originalURL(ofTranslocated url: URL) -> URL? {
    typealias CreateOriginalPath = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?
    guard
      let security = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOW),
      let symbol = dlsym(security, "SecTranslocateCreateOriginalPathForURL")
    else {
      return nil
    }
    let createOriginalPath = unsafeBitCast(symbol, to: CreateOriginalPath.self)
    guard let original = createOriginalPath(url as CFURL, nil)?.takeRetainedValue() as URL? else {
      return nil
    }
    return isTranslocatedPath(original.path(percentEncoded: false)) ? nil : original
  }
}

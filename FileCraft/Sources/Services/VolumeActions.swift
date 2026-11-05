/*
 * VolumeActions.swift
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
import Foundation

/// The outcome of ejecting a volume.
nonisolated internal enum EjectResult: Hashable, Sendable {
  case ejected
  /// The volume is in use, for example by an open file.
  case busy
  /// Ejecting failed for another reason, with its localized description.
  case failed(String)
}

/// Ejects volumes through `NSWorkspace` (design decision D9).
nonisolated internal enum VolumeActions {

  /// The Carbon error "file busy", which ejecting reports for a volume in use.
  private static let fileBusyError = -47

  /// Unmounts the volume at `url` and ejects its device. This can take seconds, so it runs off the caller's actor.
  @concurrent
  internal static func eject(_ url: URL) async -> EjectResult {
    do {
      try NSWorkspace.shared.unmountAndEjectDevice(at: url)
      return .ejected
    } catch {
      return isBusy(error as NSError) ? .busy : .failed(error.localizedDescription)
    }
  }

  /// Whether `error`, or an error it wraps, says that the volume is in use.
  internal static func isBusy(_ error: NSError) -> Bool {
    switch (error.domain, error.code) {
    case (NSOSStatusErrorDomain, fileBusyError), (NSPOSIXErrorDomain, Int(EBUSY)):
      return true
    default:
      return (error.userInfo[NSUnderlyingErrorKey] as? NSError).map(isBusy) ?? false
    }
  }
}

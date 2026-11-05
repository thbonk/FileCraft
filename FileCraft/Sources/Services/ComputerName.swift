/*
 * ComputerName.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-10-31.
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
import SystemConfiguration

/// The name of this Mac, as set in System Settings > General > Sharing.
nonisolated internal enum ComputerName {

  /// The computer name, read once; "Computer" when it is not set.
  ///
  /// The system configuration store answers locally, unlike `Host.current()`, which may wait for DNS.
  internal static let current: String = {
    guard let name = SCDynamicStoreCopyComputerName(nil, nil).map({ $0 as String }), name.isEmpty == false else {
      return String(localized: "Computer")
    }
    return name
  }()
}

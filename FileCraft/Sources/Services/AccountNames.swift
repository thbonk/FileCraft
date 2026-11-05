/*
 * AccountNames.swift
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

import Darwin
import Foundation
import Synchronization

/// Resolves user and group IDs to account names, caching every lookup.
nonisolated internal enum AccountNames {

  // MARK: - Properties

  private static let userNames = Mutex<[UInt32: String]>([:])
  private static let groupNames = Mutex<[UInt32: String]>([:])

  // MARK: - Lookups

  /// The short name of the user with `uid`, or the number when the user is unknown.
  internal static func userName(for uid: UInt32) -> String {
    if let cached = userNames.withLock({ $0[uid] }) {
      return cached
    }
    let name = lookUpUser(uid) ?? String(uid)
    userNames.withLock { $0[uid] = name }
    return name
  }

  /// The name of the group with `gid`, or the number when the group is unknown.
  internal static func groupName(for gid: UInt32) -> String {
    if let cached = groupNames.withLock({ $0[gid] }) {
      return cached
    }
    let name = lookUpGroup(gid) ?? String(gid)
    groupNames.withLock { $0[gid] = name }
    return name
  }

  // MARK: - Private

  private static func lookUpUser(_ uid: uid_t) -> String? {
    var entry = passwd()
    var result: UnsafeMutablePointer<passwd>?
    var buffer = [CChar](repeating: 0, count: 4_096)
    guard getpwuid_r(uid, &entry, &buffer, buffer.count, &result) == 0, result != nil, let name = entry.pw_name else {
      return nil
    }
    return String(cString: name)
  }

  private static func lookUpGroup(_ gid: gid_t) -> String? {
    var entry = group()
    var result: UnsafeMutablePointer<group>?
    var buffer = [CChar](repeating: 0, count: 4_096)
    guard getgrgid_r(gid, &entry, &buffer, buffer.count, &result) == 0, result != nil, let name = entry.gr_name else {
      return nil
    }
    return String(cString: name)
  }
}

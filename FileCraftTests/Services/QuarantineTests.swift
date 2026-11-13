/*
 * QuarantineTests.swift
 * FileCraftTests
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
import Testing
@testable import FileCraft

internal struct QuarantineTests {

  // MARK: - Attribute Values

  @Test
  internal func `Running in place adds the do-not-translocate flag and keeps the rest`() {
    let value = Quarantine.valueAllowingRunningInPlace("0083;6533c2a1;Safari;6E4C2B1A-1111-2222-3333-444455556666")

    #expect(value == "0183;6533c2a1;Safari;6E4C2B1A-1111-2222-3333-444455556666")
  }

  @Test
  internal func `A quarantine that already allows running in place stays as it is`() {
    #expect(Quarantine.valueAllowingRunningInPlace("01c1;6533c2a1;Vivaldi;6E4C2B1A") == nil)
  }

  @Test
  internal func `Values that are not a quarantine are left alone`() {
    #expect(Quarantine.valueAllowingRunningInPlace("") == nil)
    #expect(Quarantine.valueAllowingRunningInPlace("zz83;6533c2a1;Safari;6E4C2B1A") == nil)
  }

  // MARK: - Files

  @Test
  internal func `A downloaded app is allowed to run in place`() throws {
    let directory = try TemporaryDirectory()
    let app = try directory.createFolder("Tool.app")
    try Self.setQuarantine("0083;6533c2a1;Safari;6E4C2B1A", on: app)

    let changed = try Quarantine.allowRunningInPlace(at: app)

    #expect(changed)
    #expect(Self.quarantine(of: app) == "0183;6533c2a1;Safari;6E4C2B1A")
  }

  @Test
  internal func `An item without quarantine gets none`() throws {
    let directory = try TemporaryDirectory()
    let app = try directory.createFolder("Tool.app")

    let changed = try Quarantine.allowRunningInPlace(at: app)

    #expect(changed == false)
    #expect(Self.quarantine(of: app) == nil)
  }

  // MARK: - Helpers

  internal static func setQuarantine(_ value: String, on url: URL) throws {
    let result = setxattr(url.path(percentEncoded: false), "com.apple.quarantine", value, value.utf8.count, 0, XATTR_NOFOLLOW)
    try #require(result == 0, "setxattr failed with errno \(errno)")
  }

  internal static func quarantine(of url: URL) -> String? {
    let path = url.path(percentEncoded: false)
    let size = getxattr(path, "com.apple.quarantine", nil, 0, 0, XATTR_NOFOLLOW)
    guard size > 0 else {
      return nil
    }
    var buffer = [UInt8](repeating: 0, count: size)
    let read = getxattr(path, "com.apple.quarantine", &buffer, size, 0, XATTR_NOFOLLOW)
    return read == size ? String(decoding: buffer, as: UTF8.self) : nil
  }
}

/*
 * VolumeMonitorTests.swift
 * FileCraftTests
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

import Testing
@testable import FileCraft

internal struct VolumeMonitorTests {

  // MARK: - Tests

  @Test
  internal func `Mounted volumes include the startup volume`() async throws {
    let volumes = await VolumeMonitor().mountedVolumes()

    let rootVolume = volumes.first { $0.isRootFileSystem }

    let startup = try #require(rootVolume)
    #expect(startup.canEject == false)
    #expect(startup.name.isEmpty == false)
    #expect((startup.totalCapacity ?? 0) > 0)
  }

  /// Values measured on macOS 27: the startup volume reports both, an APFS disk image 0 for important usage.
  @Test(arguments: [
    (Int64?(63_388_769_200), Int?(38_475_902_976), Int64?(63_388_769_200)),
    (Int64?(0), Int?(208_187_392), Int64?(208_187_392)),
    (nil, Int?(5_000), Int64?(5_000)),
    (Int64?(0), nil, Int64?(0)),
    (nil, nil, nil),
  ])
  internal func `Available capacity falls back to the plain value when important usage is unknown`(
    importantUsage: Int64?, plain: Int?, expected: Int64?
  ) {
    #expect(Volume.availableCapacity(importantUsage: importantUsage, plain: plain) == expected)
  }
}

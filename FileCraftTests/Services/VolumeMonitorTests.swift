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
}

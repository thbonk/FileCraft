/*
 * TranslocationRepairTests.swift
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

import Foundation
import Testing
@testable import FileCraft

internal struct TranslocationRepairTests {

  @Test
  internal func `Translocated paths are recognized as Sparkle recognizes them`() {
    #expect(Translocation.isTranslocatedPath("/private/var/folders/xz/T/AppTranslocation/6E4C2B1A/d/FileCraft.app"))
    #expect(Translocation.isTranslocatedPath("/Applications/FileCraft.app") == false)
  }

  @Test
  internal func `Only the first window offers the repair`() {
    let repair = TranslocationRepair(state: .translocated(original: URL(filePath: "/Applications/FileCraft.app")))

    let first = repair.claimOffer()
    let second = repair.claimOffer()

    #expect(first)
    #expect(second == false)
  }

  @Test
  internal func `A FileCraft that runs in place offers nothing`() {
    let repair = TranslocationRepair(state: .inPlace)

    #expect(repair.claimOffer() == false)
  }
}

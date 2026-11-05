/*
 * OperationSchedulerTests.swift
 * FileCraftTests
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

import Foundation
import Testing
@testable import FileCraft

internal struct OperationSchedulerTests {

  @Test
  internal func `Operations on one volume run one after another, other volumes in parallel`() {
    var scheduler = OperationScheduler()
    let first = UUID()
    let second = UUID()
    let other = UUID()

    let firstStarts = scheduler.enqueue(first, volume: "/")
    let secondStarts = scheduler.enqueue(second, volume: "/")
    let otherStarts = scheduler.enqueue(other, volume: "/Volumes/Backup")
    let nextAfterFirst = scheduler.finish(first)

    #expect(firstStarts)
    #expect(secondStarts == false)
    #expect(otherStarts)
    #expect(nextAfterFirst == second)
    #expect(scheduler.isRunning(second))
  }

  @Test
  internal func `A queued operation that is cancelled does not start the next one`() {
    var scheduler = OperationScheduler()
    let running = UUID()
    let queued = UUID()
    let last = UUID()
    _ = scheduler.enqueue(running, volume: "/")
    _ = scheduler.enqueue(queued, volume: "/")
    _ = scheduler.enqueue(last, volume: "/")

    let nextAfterQueued = scheduler.finish(queued)
    let nextAfterRunning = scheduler.finish(running)

    #expect(nextAfterQueued == nil)
    #expect(nextAfterRunning == last)
  }
}

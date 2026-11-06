/*
 * TagAssignmentTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-11-06.
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

internal struct TagAssignmentTests {

  private let a = URL(filePath: "/tmp/a")
  private let b = URL(filePath: "/tmp/b")

  @Test
  internal func `Tags are on, off or mixed across the items`() {
    let assignment = TagAssignment(tags: [a: ["Red", "Blue"], b: ["Red"]])

    #expect(assignment.state(of: "Red") == .on)
    #expect(assignment.state(of: "Blue") == .mixed)
    #expect(assignment.state(of: "Green") == .off)
  }

  @Test
  internal func `Toggling a mixed tag adds it to the items without it`() {
    var assignment = TagAssignment(tags: [a: ["Blue"], b: []])

    let changed = assignment.toggle("Blue")

    #expect(changed == [b: ["Blue"]])
    #expect(assignment.state(of: "Blue") == .on)
  }

  @Test
  internal func `Toggling a tag all items carry removes it from all`() {
    var assignment = TagAssignment(tags: [a: ["Red", "Blue"], b: ["Red"]])

    let changed = assignment.toggle("Red")

    #expect(changed == [a: ["Blue"], b: []])
    #expect(assignment.state(of: "Red") == .off)
  }
}

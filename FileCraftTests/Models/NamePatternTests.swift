/*
 * NamePatternTests.swift
 * FileCraftTests
 *
 * Created by Thomas Bonk on 2026-11-05.
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

internal struct NamePatternTests {

  @Test
  internal func `A wildcard pattern matches whole names and ignores case`() throws {
    let pattern = try NamePattern("*.jpg", syntax: .wildcard)

    #expect(pattern.matches("Beach.jpg"))
    #expect(pattern.matches("BEACH.JPG"))
    #expect(pattern.matches("photo.jpg.txt") == false)
    #expect(pattern.matches("jpg") == false)
  }

  @Test
  internal func `Question marks and character sets match one character`() throws {
    let single = try NamePattern("IMG_00?.png", syntax: .wildcard)
    let set = try NamePattern("report-[ab].txt", syntax: .wildcard)
    let negated = try NamePattern("report-[!ab].txt", syntax: .wildcard)

    #expect(single.matches("IMG_007.png"))
    #expect(single.matches("IMG_0007.png") == false)
    #expect(set.matches("report-a.txt"))
    #expect(set.matches("report-c.txt") == false)
    #expect(negated.matches("report-c.txt"))
    #expect(negated.matches("report-a.txt") == false)
  }

  @Test
  internal func `Regular expression characters in wildcards match literally`() throws {
    let pattern = try NamePattern("a+b (1).txt", syntax: .wildcard)

    #expect(pattern.matches("a+b (1).txt"))
    #expect(pattern.matches("aab (1)xtxt") == false)
  }

  @Test
  internal func `Regular expressions match anywhere unless anchored`() throws {
    let anywhere = try NamePattern("\\d{4}", syntax: .regularExpression)
    let anchored = try NamePattern("^IMG_\\d+$", syntax: .regularExpression)

    #expect(anywhere.matches("Report 2026 final.pdf"))
    #expect(anchored.matches("img_123"))
    #expect(anchored.matches("IMG_123.jpg") == false)
  }

  @Test
  internal func `Case-sensitive patterns respect case`() throws {
    let pattern = try NamePattern("*.JPG", syntax: .wildcard, isCaseSensitive: true)

    #expect(pattern.matches("A.JPG"))
    #expect(pattern.matches("a.jpg") == false)
  }

  @Test
  internal func `Empty and invalid patterns are rejected`() {
    #expect(throws: NamePattern.PatternError.empty) {
      try NamePattern("", syntax: .wildcard)
    }
    #expect(throws: NamePattern.PatternError.invalid) {
      try NamePattern("(unclosed", syntax: .regularExpression)
    }
  }
}

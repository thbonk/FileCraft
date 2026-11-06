/*
 * FinderReplacementTests.swift
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

/// Uses a fake Finder and fake preferences, so that the tests never quit Finder or change its desktop.
internal struct FinderReplacementTests {

  @Test
  internal func `Finder quits at launch and starts again when FileCraft quits`() async {
    let finder = FakeFinder()
    let replacement = FinderReplacement(finder: finder, desktop: FakeDesktop())

    await replacement.applyAtLaunch(quitsFinder: true, hidesDesktop: false)
    #expect(finder.isRunning == false)

    replacement.applyAtQuit(quitsFinder: true)
    #expect(finder.isRunning)
    #expect(finder.events == ["quit", "launch"])
  }

  @Test
  internal func `With the option off, launch and quit leave Finder alone`() async {
    let finder = FakeFinder()
    let replacement = FinderReplacement(finder: finder, desktop: FakeDesktop())

    await replacement.applyAtLaunch(quitsFinder: false, hidesDesktop: false)
    replacement.applyAtQuit(quitsFinder: false)

    #expect(finder.events.isEmpty)
  }

  @Test
  internal func `Turning the option off starts Finder again`() async {
    let finder = FakeFinder(isRunning: false)

    await FinderReplacement(finder: finder, desktop: FakeDesktop()).setQuitsFinder(false)

    #expect(finder.isRunning)
  }

  @Test
  internal func `Hiding the desktop sets Finder's preference and restarts Finder`() async {
    let finder = FakeFinder()
    let desktop = FakeDesktop()
    let replacement = FinderReplacement(finder: finder, desktop: desktop)

    await replacement.setHidesDesktop(true)
    #expect(desktop.showsDesktop == false)
    #expect(finder.events == ["quit", "launch"])

    await replacement.setHidesDesktop(false)
    #expect(desktop.showsDesktop)
  }

  @Test
  internal func `At launch a desktop that was shown again is hidden, and one the user hid stays hidden`() async {
    let shown = FakeDesktop()
    await FinderReplacement(finder: FakeFinder(), desktop: shown).applyAtLaunch(quitsFinder: false, hidesDesktop: true)
    #expect(shown.showsDesktop == false)

    let hiddenByUser = FakeDesktop(showsDesktop: false)
    await FinderReplacement(finder: FakeFinder(), desktop: hiddenByUser).applyAtLaunch(quitsFinder: false, hidesDesktop: false)
    #expect(hiddenByUser.showsDesktop == false)
  }
}

/// A Finder that only records what happens to it.
private final class FakeFinder: FinderControlling {

  private(set) var isRunning: Bool
  private(set) var events: [String] = []

  init(isRunning: Bool = true) {
    self.isRunning = isRunning
  }

  func quit() async {
    guard isRunning else {
      return
    }
    isRunning = false
    events.append("quit")
  }

  func launch() async {
    launchWithoutWaiting()
  }

  func launchWithoutWaiting() {
    guard isRunning == false else {
      return
    }
    isRunning = true
    events.append("launch")
  }
}

/// Finder's desktop preference in memory.
private final class FakeDesktop: FinderDesktopPreference {

  private(set) var showsDesktop: Bool

  init(showsDesktop: Bool = true) {
    self.showsDesktop = showsDesktop
  }

  func setShowsDesktop(_ showsDesktop: Bool) {
    self.showsDesktop = showsDesktop
  }
}

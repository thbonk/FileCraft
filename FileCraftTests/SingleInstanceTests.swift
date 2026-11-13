/*
 * SingleInstanceTests.swift
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

internal struct SingleInstanceTests {

  // MARK: - Which Process Stays

  @Test
  internal func `The earliest other process stays`() {
    let current = process(500, at: 5)
    let others = [process(450, at: 2), process(400, at: 0), current]

    #expect(SingleInstance.primary(among: others, current: current)?.processIdentifier == 400)
  }

  @Test
  internal func `A process started later does not take over`() {
    let current = process(500, at: 5)

    #expect(SingleInstance.primary(among: [process(600, at: 9), current], current: current) == nil)
  }

  @Test
  internal func `Processes started at the same moment yield to the lower process identifier`() {
    let current = process(500, at: 5)

    #expect(SingleInstance.primary(among: [process(300, at: 5)], current: current)?.processIdentifier == 300)
    #expect(SingleInstance.primary(among: [process(600, at: 5)], current: current) == nil)
  }

  @Test
  internal func `A process without a launch date counts by its process identifier`() {
    let current = process(500, at: 5)

    #expect(SingleInstance.primary(among: [process(300, at: nil)], current: current)?.processIdentifier == 300)
    #expect(SingleInstance.primary(among: [process(600, at: nil)], current: current) == nil)
  }

  @Test
  internal func `The test host and a debugged process never hand over`() {
    #expect(SingleInstance.handsOver(hasPrimary: true, isTestHost: false, isBeingDebugged: false))
    #expect(SingleInstance.handsOver(hasPrimary: false, isTestHost: false, isBeingDebugged: false) == false)
    #expect(SingleInstance.handsOver(hasPrimary: true, isTestHost: true, isBeingDebugged: false) == false)
    #expect(SingleInstance.handsOver(hasPrimary: true, isTestHost: false, isBeingDebugged: true) == false)
  }

  // MARK: - Requests

  @Test
  internal func `Open and reveal requests yield their files`() {
    let files = [URL(filePath: "/Users/Shared/Report.pdf"), URL(filePath: "/Applications/", directoryHint: .isDirectory)]
    let list = NSAppleEventDescriptor.list()
    for (offset, file) in files.enumerated() {
      list.insert(NSAppleEventDescriptor(fileURL: file), at: offset + 1)
    }
    let openDocuments = event(AEEventClass(kCoreEventClass), AEEventID(kAEOpenDocuments), directObject: list)
    let reveal = event(AEEventClass(kAEMiscStandards), AEEventID(kAEMakeObjectsVisible), directObject: list)

    #expect(SingleInstance.urls(in: openDocuments).map(\.path) == files.map(\.path))
    #expect(SingleInstance.urls(in: reveal).map(\.path) == files.map(\.path))
  }

  @Test
  internal func `A URL request yields its URL, and a plain launch none`() {
    let getURL = event(
      SingleInstance.getURLEvent, SingleInstance.getURLEvent,
      directObject: NSAppleEventDescriptor(string: "file:///Users/Shared/"))
    let openApplication = event(AEEventClass(kCoreEventClass), AEEventID(kAEOpenApplication), directObject: nil)

    #expect(SingleInstance.urls(in: getURL) == [URL(string: "file:///Users/Shared/")])
    #expect(SingleInstance.urls(in: openApplication).isEmpty)
  }

  // MARK: - Helpers

  private func process(_ identifier: pid_t, at seconds: TimeInterval?) -> SingleInstance.Process {
    SingleInstance.Process(processIdentifier: identifier, launchDate: seconds.map { Date(timeIntervalSinceReferenceDate: $0) })
  }

  private func event(
    _ eventClass: AEEventClass, _ eventID: AEEventID, directObject: NSAppleEventDescriptor?
  ) -> NSAppleEventDescriptor {
    let event = NSAppleEventDescriptor(
      eventClass: eventClass, eventID: eventID, targetDescriptor: nil,
      returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
    if let directObject {
      event.setParam(directObject, forKeyword: keyDirectObject)
    }
    return event
  }
}

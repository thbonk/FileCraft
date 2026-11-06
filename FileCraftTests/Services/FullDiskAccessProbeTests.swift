/*
 * FullDiskAccessProbeTests.swift
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

internal struct FullDiskAccessProbeTests {

  private let first = URL(filePath: "/protected/first")
  private let second = URL(filePath: "/protected/second")

  @Test
  internal func `The first existing location decides the status`() async {
    #expect(await status([first: .readable, second: .notPermitted]) == .granted)
    #expect(await status([first: .notPermitted, second: .readable]) == .notGranted)
    #expect(await status([first: .missing, second: .readable]) == .granted)
    #expect(await status([first: .missing, second: .missing]) == .unknown)
  }

  @Test
  internal func `Reading reports readable files, folders and missing items`() throws {
    let directory = try TemporaryDirectory()
    let file = try directory.createFile("data.txt", contents: "x")

    #expect(FullDiskAccessProbe.tryReading(file) == .readable)
    #expect(FullDiskAccessProbe.tryReading(directory.url) == .readable)
    #expect(FullDiskAccessProbe.tryReading(directory.url.appending(path: "missing")) == .missing)
  }

  private func status(_ results: [URL: FullDiskAccessProbe.ReadResult]) async -> FullDiskAccessStatus {
    await FullDiskAccessProbe(locations: [first, second], read: { results[$0] ?? .missing }).status()
  }
}

extension FullDiskAccessProbe.ReadResult: Equatable {}

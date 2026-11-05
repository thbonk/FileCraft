/*
 * SidebarItemTests.swift
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

internal struct SidebarItemTests {

  // MARK: - Properties

  private let downloads = Favorite(id: UUID(), reference: FileReference(unresolvedURL: URL(filePath: "/Users/anna/Downloads")))
  private let volume = URL(filePath: "/Volumes/Backup/", directoryHint: .isDirectory)
  private let iCloudDrive = URL(filePath: "/Users/anna/Library/Mobile Documents/com~apple~CloudDocs/", directoryHint: .isDirectory)

  // MARK: - Tests

  @Test
  internal func `The highlighted entry is the favorite, volume or iCloud Drive showing the folder`() {
    #expect(match("/Users/anna/Downloads/") == .favorite(downloads.id))
    #expect(match("/Volumes/Backup") == .volume(volume))
    #expect(match("/Users/anna/Library/Mobile Documents/com~apple~CloudDocs") == .iCloudDrive)
    #expect(match("/Users/anna/Projects") == nil)
  }

  @Test
  internal func `A favorite of a volume root wins over the volume`() {
    let backup = Favorite(id: UUID(), reference: FileReference(unresolvedURL: volume))

    let item = SidebarItem.matching(.folder(reference("/Volumes/Backup")), favorites: [backup], volumes: [volume], iCloudDrive: nil)

    #expect(item == .favorite(backup.id))
  }

  @Test
  internal func `Computer and tags highlight their own entries`() {
    #expect(SidebarItem.matching(.computer, favorites: [downloads], volumes: [volume], iCloudDrive: nil) == .computer)
    #expect(SidebarItem.matching(.tag("Red"), favorites: [], volumes: [], iCloudDrive: nil) == .tag("Red"))
  }

  // MARK: - Helpers

  private func match(_ path: String) -> SidebarItem? {
    SidebarItem.matching(.folder(reference(path)), favorites: [downloads], volumes: [volume], iCloudDrive: iCloudDrive)
  }

  private func reference(_ path: String) -> FileReference {
    FileReference(unresolvedURL: URL(filePath: path))
  }
}

/*
 * OperationPreviewData.swift
 * FileCraft
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

/// Static operations for the previews of the Operations window.
internal enum OperationPreviewData {

  // MARK: - Items

  internal static let report = URL(filePath: "/Users/anna/Documents/Report.pdf")
  internal static let backup = URL(filePath: "/Volumes/Backup")

  internal static let existingReport = ItemSummary(
    url: URL(filePath: "/Volumes/Backup/Report.pdf"),
    isFolder: false,
    kind: "PDF document",
    size: 1_204_000,
    modificationDate: Date(timeIntervalSince1970: 1_790_000_000))

  internal static let newReport = ItemSummary(
    url: report,
    isFolder: false,
    kind: "PDF document",
    size: 1_380_000,
    modificationDate: Date(timeIntervalSince1970: 1_793_000_000))

  internal static let existingFolder = ItemSummary(
    url: URL(filePath: "/Volumes/Backup/Assets"), isFolder: true, kind: "Folder", size: nil, modificationDate: nil)

  internal static let newFolder = ItemSummary(
    url: URL(filePath: "/Users/anna/Documents/Assets"), isFolder: true, kind: "Folder", size: nil, modificationDate: nil)

  // MARK: - Operations

  /// A copy of three items into "Backup" at 40 %.
  internal static var running: FileOperationProgress {
    var progress = FileOperationProgress(
      id: UUID(), kind: .copy, sources: [report, URL(filePath: "/Users/anna/Photos"), URL(filePath: "/Users/anna/Notes.txt")],
      destination: backup)
    progress.state = .running
    progress.totalItems = 40
    progress.processedItems = 16
    progress.totalBytes = 3_400_000_000
    progress.processedBytes = 1_360_000_000
    progress.bytesPerSecond = 45_000_000
    progress.startDate = .now
    return progress
  }

  internal static var paused: FileOperationProgress {
    var progress = FileOperationProgress(id: UUID(), kind: .move, sources: [report], destination: backup)
    progress.state = .paused
    progress.totalItems = 1
    progress.totalBytes = 1_380_000
    progress.processedBytes = 400_000
    return progress
  }

  internal static var queued: FileOperationProgress {
    FileOperationProgress(id: UUID(), kind: .copy, sources: [URL(filePath: "/Users/anna/Movies")], destination: backup)
  }

  internal static var failed: FileOperationProgress {
    var progress = FileOperationProgress(
      id: UUID(), kind: .copy, sources: [URL(filePath: "/Users/anna/Projects")], destination: backup)
    progress.state = .failed
    progress.totalItems = 120
    progress.processedItems = 120
    progress.errors = [
      FileOperationError(url: URL(filePath: "/Users/anna/Projects/secret.key"), reason: "The file “secret.key” couldn’t be opened because you don’t have permission to view it."),
      FileOperationError(url: URL(filePath: "/Users/anna/Projects/movie.mov"), reason: "verification failed"),
    ]
    return progress
  }

  internal static var completed: FileOperationProgress {
    var progress = FileOperationProgress(id: UUID(), kind: .move, sources: [report], destination: backup)
    progress.state = .completed
    progress.totalItems = 1
    progress.processedItems = 1
    return progress
  }
}

/*
 * FileOperation.swift
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

/// What a file operation does.
nonisolated internal enum FileOperationKind: String, Codable, Hashable, Sendable {
  case copy
  case move
  /// Deletes the items without using the Trash, for Delete Immediately and Empty Trash.
  case delete
  /// Puts all items into one new archive in the destination folder.
  case compress
  /// Expands each archive into the destination folder.
  case expand
}

/// What happens when an item with the same name exists at the destination.
nonisolated internal enum ConflictPolicy: Hashable, Sendable {
  /// The user decides in the conflict dialog; an answer for all conflicts applies to the later ones.
  case ask
  /// The existing item moves to the Trash, then the new one takes its place.
  case replace
  /// The new item gets the next free name, such as "report 2.pdf".
  case keepBoth
  case skip
  /// The operation stops; finished items stay.
  case stop
}

/// A copy or move of items into a destination folder.
nonisolated internal struct FileOperationRequest: Hashable, Sendable {
  internal var kind: FileOperationKind
  internal var sources: [URL]
  /// The folder the items are copied or moved into; for a deletion, the folder of the items, which decides the
  /// volume whose queue the operation joins.
  internal var destination: URL
  internal var conflictPolicy: ConflictPolicy = .ask
  /// Compares a checksum of every copied file with its source.
  internal var verifiesCopies = false
  /// Lets APFS clone files instead of copying their data; tests turn it off to watch the data being copied.
  internal var allowsCloning = true
  /// The format of the archive that a compression creates.
  internal var archiveFormat: CompressionFormat = .zip
}

nonisolated internal enum FileOperationState: String, Hashable, Sendable {
  case queued
  /// Counting the items and bytes to process.
  case preparing
  case running
  case paused
  case cancelled
  case completed
  /// Finished, but some items failed.
  case failed

  /// Whether the operation has ended.
  internal var isFinished: Bool {
    self == .cancelled || self == .completed || self == .failed
  }
}

/// An item that an operation could not process.
nonisolated internal struct FileOperationError: Identifiable, Hashable, Sendable {
  internal let id = UUID()
  internal let url: URL
  /// The localized reason, for example "verification failed".
  internal let reason: String
}

// MARK: - Questions

/// A decision in the conflict dialog.
nonisolated internal enum ConflictChoice: String, Hashable, Sendable {
  case replace
  case keepBoth
  case skip
  case stop
  /// Combines two folders; conflicts between their contents are resolved the same way.
  case merge
}

/// A decision in the error dialog.
nonisolated internal enum FailureChoice: String, Hashable, Sendable {
  case skip
  case retry
  /// Retries the item through the privileged helper, after the user authenticated.
  case authenticateAndRetry
  case stop
}

/// The facts about an item that the conflict dialog compares.
nonisolated internal struct ItemSummary: Hashable, Sendable {

  // MARK: - Properties

  internal let url: URL
  /// Whether the item is a folder that can be merged; packages such as applications count as files.
  internal let isFolder: Bool
  /// The localized kind, such as "PDF document".
  internal let kind: String?
  /// The size of a file; nil for folders and packages, whose size the dialog calculates.
  internal let size: Int64?
  internal let modificationDate: Date?

  internal var name: String {
    url.lastPathComponent
  }

  // MARK: - Initialization

  internal init(url: URL, isFolder: Bool, kind: String?, size: Int64?, modificationDate: Date?) {
    self.url = url
    self.isFolder = isFolder
    self.kind = kind
    self.size = size
    self.modificationDate = modificationDate
  }

  /// Reads the facts about the item at `url`; a symbolic link is described itself, not its original.
  internal init(url: URL) {
    let keys: Set<URLResourceKey> = [.isPackageKey, .localizedTypeDescriptionKey, .fileSizeKey, .contentModificationDateKey]
    let values = try? url.resourceValues(forKeys: keys)
    let isDirectory = FileCopier.isDirectory(url)
    self.init(
      url: url,
      isFolder: isDirectory && values?.isPackage != true,
      kind: values?.localizedTypeDescription,
      size: isDirectory ? nil : values?.fileSize.map(Int64.init),
      modificationDate: values?.contentModificationDate)
  }
}

/// A question that an operation waits on until the user answers it.
nonisolated internal struct OperationQuestion: Identifiable, Hashable, Sendable {

  internal enum Topic: Hashable, Sendable {
    /// `existing` at the destination has the name of `source`.
    case conflict(source: ItemSummary, existing: ItemSummary)
    /// Processing `item` failed for the localized `reason`; with `isPermissionError`, Authenticate and Retry can
    /// overcome it through the privileged helper.
    case failure(item: URL, reason: String, isPermissionError: Bool)
  }

  internal let id: UUID
  internal let topic: Topic

  internal init(id: UUID = UUID(), topic: Topic) {
    self.id = id
    self.topic = topic
  }
}

/// The user's answer to an `OperationQuestion`.
nonisolated internal enum OperationAnswer: Hashable, Sendable {
  case conflict(ConflictChoice, appliesToAll: Bool)
  case failure(FailureChoice, appliesToAll: Bool)
}

// MARK: - Progress

/// The state of one operation at one moment, as the engine reports it.
nonisolated internal struct FileOperationProgress: Identifiable, Hashable, Sendable {
  internal let id: UUID
  internal let kind: FileOperationKind
  internal let sources: [URL]
  internal let destination: URL
  internal var state: FileOperationState = .queued
  internal var totalItems = 0
  internal var processedItems = 0
  internal var totalBytes: Int64 = 0
  internal var processedBytes: Int64 = 0
  /// The name of the item being processed.
  internal var currentItemName: String?
  /// The bytes processed per second while running.
  internal var bytesPerSecond: Double?
  internal var errors: [FileOperationError] = []
  /// The items the operation created at the destination, for selecting them and for undo.
  internal var results: [URL] = []
  /// From each source to the new item it became, for undoing a move; merged folders are left out.
  internal var transfers: [ItemMove] = []
  /// The question the operation waits on.
  internal var question: OperationQuestion?
  /// When the operation began copying or moving, after preparing.
  internal var startDate: Date?

  /// The share of the work done, between 0 and 1.
  internal var fractionCompleted: Double {
    if totalBytes > 0 {
      return min(Double(processedBytes) / Double(totalBytes), 1)
    }
    return totalItems > 0 ? min(Double(processedItems) / Double(totalItems), 1) : 0
  }

  /// The estimated seconds until the operation finishes, while it runs.
  internal var estimatedSecondsRemaining: Double? {
    guard state == .running, question == nil, let bytesPerSecond, bytesPerSecond > 0 else {
      return nil
    }
    return Double(max(totalBytes - processedBytes, 0)) / bytesPerSecond
  }
}

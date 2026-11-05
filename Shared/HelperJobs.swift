/*
 * HelperJobs.swift
 * Shared
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

import Darwin
import Foundation
import Synchronization

/// The progress and cancellation of one running job, shared between its thread and the requests about it.
nonisolated internal final class HelperJobContext: Sendable {

  private struct State {
    var completedItems = 0
    var completedBytes: Int64 = 0
    var currentFileBytes: Int64 = 0
    var isCancelled = false
  }

  private let state = Mutex(State())

  internal var isCancelled: Bool {
    state.withLock { $0.isCancelled }
  }

  internal var processed: (items: Int, bytes: Int64) {
    state.withLock { ($0.completedItems, $0.completedBytes + $0.currentFileBytes) }
  }

  internal func cancel() {
    state.withLock { $0.isCancelled = true }
  }

  internal func setCurrentFileBytes(_ bytes: Int64) {
    state.withLock { $0.currentFileBytes = bytes }
  }

  internal func finishItem(bytes: Int64) {
    state.withLock {
      $0.completedItems += 1
      $0.completedBytes += bytes
      $0.currentFileBytes = 0
    }
  }
}

/// The jobs of the helper: copies, moves and deletions that run on threads of their own, report progress and can
/// be cancelled. A finished job is kept for a minute, so that the app can read its result.
nonisolated internal final class HelperJobs: Sendable {

  // MARK: - Types

  private struct Record {
    let context = HelperJobContext()
    var isFinished = false
    var failure: HelperFailure?
    var finishedAt: Date?
  }

  // MARK: - Properties

  /// How long a finished job stays available.
  internal static let retention: TimeInterval = 60

  private let records = Mutex<[UUID: Record]>([:])

  internal init() {}

  // MARK: - Jobs

  /// Starts `job` and returns its identifier.
  internal func start(_ job: HelperJob) -> UUID {
    let id = UUID()
    let context = records.withLock { records -> HelperJobContext in
      let record = Record()
      records[id] = record
      return record.context
    }
    Thread.detachNewThread { [self] in
      var failure: HelperFailure?
      do throws(HelperFailure) {
        try HelperFileSystem.run(job, context: context)
      } catch {
        failure = error
      }
      records.withLock { records in
        records[id]?.isFinished = true
        records[id]?.failure = failure
        records[id]?.finishedAt = .now
      }
    }
    return id
  }

  /// The progress of the job `id`, or nil for an unknown or long finished job.
  internal func status(of id: UUID, now: Date = .now) -> HelperJobStatus? {
    records.withLock { records in
      records = records.filter { $0.value.finishedAt.map { now.timeIntervalSince($0) < Self.retention } ?? true }
      guard let record = records[id] else {
        return nil
      }
      let processed = record.context.processed
      let wasCancelled = record.context.isCancelled || record.failure == .posix(ECANCELED)
      return HelperJobStatus(
        processedItems: processed.items,
        processedBytes: processed.bytes,
        isFinished: record.isFinished,
        wasCancelled: record.isFinished && wasCancelled,
        failure: wasCancelled ? nil : record.failure)
    }
  }

  /// Cancels the job `id`; a copy in progress is removed. Returns false for an unknown job.
  internal func cancel(_ id: UUID) -> Bool {
    records.withLock { records in
      guard let record = records[id] else {
        return false
      }
      record.context.cancel()
      return true
    }
  }
}

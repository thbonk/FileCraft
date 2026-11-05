/*
 * FileOperationEngine.swift
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

/// Runs copy and move operations in the background (design decision D10): one operation at a time per destination
/// volume, different volumes in parallel. Progress is reported through `updates()`.
///
/// The copying itself blocks, and pausing holds it, so each operation works on a thread of its own instead of
/// occupying a thread of the cooperative pool.
internal actor FileOperationEngine {

  // MARK: - Types

  private struct Record {
    let request: FileOperationRequest
    let control = OperationControl()
    var progress: FileOperationProgress
    var lastSample: (date: Date, bytes: Int64)?
    /// Whether the operation got its turn on its volume and began.
    var hasStarted = false
    /// Whether the sources are measured, which ends the preparing phase.
    var isMeasured = false

    /// The state the operation returns to when it is resumed.
    var resumedState: FileOperationState {
      guard hasStarted else {
        return .queued
      }
      return isMeasured ? .running : .preparing
    }
  }

  // MARK: - Properties

  /// The engine of the app.
  internal static let shared = FileOperationEngine()

  /// How often progress is reported while operations run.
  private static let progressInterval = Duration.milliseconds(100)

  private var records: [UUID: Record] = [:]
  /// The operations in the order they were enqueued.
  private var order: [UUID] = []
  private var scheduler = OperationScheduler()
  private var observers: [UUID: AsyncStream<[FileOperationProgress]>.Continuation] = [:]
  private var finishWaiters: [UUID: [CheckedContinuation<FileOperationProgress, Never>]] = [:]

  /// All operations, oldest first.
  internal var snapshot: [FileOperationProgress] {
    order.compactMap { records[$0]?.progress }
  }

  // MARK: - Observing

  /// The operations whenever they change, starting with their current state.
  internal func updates() -> AsyncStream<[FileOperationProgress]> {
    let (stream, continuation) = AsyncStream.makeStream(of: [FileOperationProgress].self, bufferingPolicy: .bufferingNewest(1))
    let id = UUID()
    observers[id] = continuation
    continuation.onTermination = { _ in
      Task {
        await self.removeObserver(id)
      }
    }
    continuation.yield(snapshot)
    return stream
  }

  /// Waits until the operation `id` has finished and returns its final state.
  internal func waitUntilFinished(_ id: UUID) async -> FileOperationProgress? {
    guard let progress = records[id]?.progress else {
      return nil
    }
    if progress.state.isFinished {
      return progress
    }
    return await withCheckedContinuation { continuation in
      finishWaiters[id, default: []].append(continuation)
    }
  }

  // MARK: - Controlling

  /// Adds an operation; it starts when its destination volume is free.
  internal func enqueue(_ request: FileOperationRequest) async -> UUID {
    let id = UUID()
    let progress = FileOperationProgress(id: id, kind: request.kind, sources: request.sources, destination: request.destination)
    records[id] = Record(request: request, progress: progress)
    order.append(id)
    let volume = await Self.volumeKey(of: request.destination)
    if scheduler.enqueue(id, volume: volume) {
      start(id)
    }
    publish()
    return id
  }

  /// Pauses the operation. A queued operation that is paused keeps its place, prepares when its turn comes and
  /// then waits before copying anything.
  internal func pause(_ id: UUID) {
    guard let record = records[id], record.progress.state.isFinished == false, record.progress.state != .paused else {
      return
    }
    record.control.pause()
    records[id]?.progress.state = .paused
    records[id]?.progress.bytesPerSecond = nil
    records[id]?.lastSample = nil
    publish()
  }

  internal func resume(_ id: UUID) {
    guard let record = records[id], record.progress.state == .paused else {
      return
    }
    record.control.resume()
    records[id]?.progress.state = record.resumedState
    publish()
  }

  /// Stops the operation; a partially copied item is removed. An operation that has not started finishes at once.
  internal func cancel(_ id: UUID) {
    guard let record = records[id], record.progress.state.isFinished == false else {
      return
    }
    record.control.cancel()
    if record.hasStarted == false {
      finish(id, as: .cancelled)
    }
  }

  /// Passes the user's answer to the question `questionID` that operation `id` waits on.
  internal func answer(_ answer: OperationAnswer, to questionID: UUID, of id: UUID) {
    guard let record = records[id], record.progress.question?.id == questionID else {
      return
    }
    record.control.answer(answer, to: questionID)
    records[id]?.progress.question = nil
    publish()
  }

  /// Cancels every operation that has not finished and waits until all of them have, for quitting.
  internal func cancelAllAndWait() async {
    let active = order.filter { records[$0]?.progress.state.isFinished == false }
    for id in active {
      cancel(id)
    }
    for id in active {
      _ = await waitUntilFinished(id)
    }
  }

  /// Removes finished operations from the list.
  internal func removeFinished() {
    order.removeAll { records[$0]?.progress.state.isFinished == true }
    records = records.filter { order.contains($0.key) }
    publish()
  }

  // MARK: - Running

  private func start(_ id: UUID) {
    Task {
      await run(id)
    }
  }

  private func run(_ id: UUID) async {
    // An operation cancelled while it waited has already finished.
    guard let record = records[id], record.progress.state.isFinished == false else {
      return
    }
    guard record.control.isCancelled == false else {
      finish(id, as: .cancelled)
      return
    }
    records[id]?.hasStarted = true
    if record.progress.state != .paused {
      records[id]?.progress.state = .preparing
    }
    publish()
    if let problem = OperationSafety.problem(in: record.request) {
      records[id]?.progress.errors.append(problem)
      finish(id, as: .failed)
      return
    }
    let totals = await Self.measure(record.request.sources)
    records[id]?.isMeasured = true
    records[id]?.progress.totalItems = totals.reduce(0) { $0 + $1.items }
    records[id]?.progress.totalBytes = totals.reduce(0) { $0 + $1.bytes }
    records[id]?.progress.startDate = .now
    if records[id]?.progress.state == .preparing {
      records[id]?.progress.state = .running
    }
    publish()

    let monitor = Task {
      while Task.isCancelled == false {
        try? await Task.sleep(for: Self.progressInterval)
        refresh(id)
      }
    }
    let request = record.request
    let control = record.control
    await Self.runOnOwnThread {
      FileOperationWorker.perform(request, totals: totals, control: control)
    }
    // The monitor's last refresh must not come after the final state.
    monitor.cancel()
    await monitor.value
    refresh(id)
    let errors = records[id]?.progress.errors ?? []
    finish(id, as: control.isCancelled ? .cancelled : (errors.isEmpty ? .completed : .failed))
  }

  /// Copies the worker's counters into the progress and estimates the speed.
  private func refresh(_ id: UUID) {
    guard var record = records[id], record.progress.state.isFinished == false else {
      return
    }
    let counters = record.control.snapshot
    record.progress.processedItems = min(counters.processedItems, max(record.progress.totalItems, counters.processedItems))
    record.progress.processedBytes = counters.processedBytes
    record.progress.currentItemName = counters.currentItemName
    record.progress.errors = counters.errors
    record.progress.results = counters.results
    record.progress.transfers = counters.transfers
    let question = record.control.pendingQuestion
    record.progress.question = question
    if question != nil {
      // Waiting for an answer is no slowdown of the copy.
      record.progress.bytesPerSecond = nil
      record.lastSample = nil
    } else if record.progress.state == .running {
      let now = Date.now
      if let sample = record.lastSample, now.timeIntervalSince(sample.date) > 0 {
        let instant = Double(counters.processedBytes - sample.bytes) / now.timeIntervalSince(sample.date)
        let previous = record.progress.bytesPerSecond ?? instant
        record.progress.bytesPerSecond = max(0, previous * 0.7 + instant * 0.3)
      }
      record.lastSample = (now, counters.processedBytes)
    }
    records[id] = record
    publish()
  }

  private func finish(_ id: UUID, as state: FileOperationState) {
    guard var record = records[id], record.progress.state.isFinished == false else {
      return
    }
    record.progress.state = state
    record.progress.bytesPerSecond = nil
    record.progress.currentItemName = nil
    record.progress.question = nil
    records[id] = record
    publish()
    for waiter in finishWaiters.removeValue(forKey: id) ?? [] {
      waiter.resume(returning: record.progress)
    }
    if let next = scheduler.finish(id) {
      start(next)
    }
  }

  private func publish() {
    let snapshot = snapshot
    for observer in observers.values {
      observer.yield(snapshot)
    }
  }

  private func removeObserver(_ id: UUID) {
    observers[id] = nil
  }

  // MARK: - Helpers

  /// Runs blocking work on a thread of its own and waits for it.
  private static func runOnOwnThread(_ work: @escaping @Sendable () -> Void) async {
    await withCheckedContinuation { continuation in
      Thread.detachNewThread {
        work()
        continuation.resume()
      }
    }
  }

  /// The number of items and bytes of each source, folders counted with everything inside them.
  @concurrent
  private static func measure(_ sources: [URL]) async -> [SourceTotals] {
    var totals: [SourceTotals] = []
    for source in sources {
      if FileCopier.isDirectory(source), let size = try? await FolderSizeCalculator.calculate(source) {
        totals.append(SourceTotals(items: size.itemCount + 1, bytes: size.logicalBytes))
      } else {
        totals.append(SourceTotals(items: 1, bytes: FileCopier.fileSize(atPath: source.path(percentEncoded: false))))
      }
    }
    return totals
  }

  /// Identifies the volume of `url`, so that operations on it run one after another.
  @concurrent
  private static func volumeKey(of url: URL) async -> String {
    (try? url.resourceValues(forKeys: [.volumeURLKey]).volume)?.path(percentEncoded: false) ?? "/"
  }
}

/// Checks a request before anything happens.
nonisolated internal enum OperationSafety {

  /// Why `request` must not run, or nil. A folder can never be copied or moved into itself or one of its folders.
  internal static func problem(in request: FileOperationRequest) -> FileOperationError? {
    guard request.kind == .copy || request.kind == .move else {
      return nil
    }
    let destination = request.destination.comparablePath
    for source in request.sources where FileCopier.isDirectory(source) {
      let path = source.comparablePath
      if destination == path || destination.hasPrefix(path + "/") {
        return FileOperationError(url: source, reason: String(localized: "A folder can’t be copied or moved into itself."))
      }
    }
    return nil
  }
}

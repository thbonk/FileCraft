/*
 * OperationScheduler.swift
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

/// Decides which operations may run: one at a time per volume, volumes in parallel.
nonisolated internal struct OperationScheduler: Sendable {

  // MARK: - Properties

  /// The waiting and running operations of each volume; the first one of a queue runs.
  private var queues: [String: [UUID]] = [:]

  // MARK: - Scheduling

  /// Adds `id` to the queue of `volume`.
  ///
  /// - Returns: Whether the operation can start right away.
  internal mutating func enqueue(_ id: UUID, volume: String) -> Bool {
    queues[volume, default: []].append(id)
    return queues[volume]?.first == id
  }

  /// Removes `id` from its queue.
  ///
  /// - Returns: The operation of the same volume that can start now, if any.
  internal mutating func finish(_ id: UUID) -> UUID? {
    guard let volume = queues.first(where: { $0.value.contains(id) })?.key, var queue = queues[volume] else {
      return nil
    }
    let wasRunning = queue.first == id
    queue.removeAll { $0 == id }
    queues[volume] = queue.isEmpty ? nil : queue
    return wasRunning ? queue.first : nil
  }

  /// Whether `id` is the running operation of its volume.
  internal func isRunning(_ id: UUID) -> Bool {
    queues.values.contains { $0.first == id }
  }
}

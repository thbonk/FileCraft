/*
 * OperationControl.swift
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

import CryptoKit
import Foundation
import Synchronization

/// The state a running operation shares between the engine and the thread doing the work: pause and cancel
/// requests one way, progress the other way.
nonisolated internal final class OperationControl: Sendable {

  // MARK: - Types

  internal struct Counters: Sendable {
    /// Items and bytes of the sources that are completely done.
    internal var completedItems = 0
    internal var completedBytes: Int64 = 0
    /// Items and bytes already done inside the source in progress.
    internal var sourceItems = 0
    internal var sourceBytes: Int64 = 0
    /// Bytes copied of the file in progress.
    internal var fileBytes: Int64 = 0
    internal var currentItemName: String?
    internal var errors: [FileOperationError] = []
    internal var results: [URL] = []
    /// From each source to the new item it became, for undo; merged folders are left out.
    internal var transfers: [ItemMove] = []

    internal var processedItems: Int {
      completedItems + sourceItems
    }

    internal var processedBytes: Int64 {
      completedBytes + sourceBytes + fileBytes
    }
  }

  private struct Flags {
    var isPaused = false
    var isCancelled = false
  }

  /// A question of the working thread and, once given, the user's answer.
  private struct Exchange {
    var question: OperationQuestion?
    var answer: OperationAnswer?
  }

  // MARK: - Properties

  private let flags = Mutex(Flags())
  private let counters = Mutex(Counters())
  private let exchange = Mutex(Exchange())

  internal var isCancelled: Bool {
    flags.withLock { $0.isCancelled }
  }

  internal var isPaused: Bool {
    flags.withLock { $0.isPaused }
  }

  // MARK: - Requests

  internal func pause() {
    flags.withLock { $0.isPaused = true }
  }

  internal func resume() {
    flags.withLock { $0.isPaused = false }
  }

  internal func cancel() {
    flags.withLock { $0.isCancelled = true }
  }

  /// Blocks the working thread while the operation is paused.
  ///
  /// - Returns: false when the operation was cancelled.
  internal func waitWhilePaused() -> Bool {
    while true {
      let state = flags.withLock { $0 }
      if state.isCancelled {
        return false
      }
      if state.isPaused == false {
        return true
      }
      Thread.sleep(forTimeInterval: 0.05)
    }
  }

  // MARK: - Questions

  /// The question the working thread waits on, until it is answered.
  internal var pendingQuestion: OperationQuestion? {
    exchange.withLock { $0.answer == nil ? $0.question : nil }
  }

  /// Asks the user about `topic` and blocks the working thread until the answer arrives through
  /// `answer(_:to:)`.
  ///
  /// - Returns: The answer, or nil when the operation was cancelled meanwhile.
  internal func ask(_ topic: OperationQuestion.Topic) -> OperationAnswer? {
    let question = OperationQuestion(topic: topic)
    exchange.withLock { $0 = Exchange(question: question) }
    defer {
      exchange.withLock { $0 = Exchange() }
    }
    while true {
      if isCancelled {
        return nil
      }
      if let answer = exchange.withLock({ $0.answer }) {
        return answer
      }
      Thread.sleep(forTimeInterval: 0.05)
    }
  }

  /// Passes the user's answer to the question `id`; an answer to another question is ignored.
  internal func answer(_ answer: OperationAnswer, to id: UUID) {
    exchange.withLock {
      if $0.question?.id == id {
        $0.answer = answer
      }
    }
  }

  // MARK: - Progress

  internal var snapshot: Counters {
    counters.withLock { $0 }
  }

  internal func update(_ change: (inout Counters) -> Void) {
    counters.withLock { change(&$0) }
  }
}

/// Compares files by their SHA-256 checksums, for Verify Copied Files.
nonisolated internal enum FileVerifier {

  /// Whether the regular files at both paths have the same contents; false when one cannot be read.
  internal static func contentsMatch(_ firstPath: String, _ secondPath: String) -> Bool {
    guard let first = digest(ofFileAt: firstPath), let second = digest(ofFileAt: secondPath) else {
      return false
    }
    return first == second
  }

  private static func digest(ofFileAt path: String) -> SHA256.Digest? {
    guard let handle = FileHandle(forReadingAtPath: path) else {
      return nil
    }
    defer {
      try? handle.close()
    }
    var hasher = SHA256()
    while let chunk = try? handle.read(upToCount: 1 << 20), chunk.isEmpty == false {
      hasher.update(data: chunk)
    }
    return hasher.finalize()
  }
}

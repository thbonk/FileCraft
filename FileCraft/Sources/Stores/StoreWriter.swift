/*
 * StoreWriter.swift
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

/// Reads a store's file and writes it off the main actor in the order the changes were made: every write waits
/// for the previous one, so the file always ends with the newest contents.
internal final class StoreWriter {

  // MARK: - Properties

  private let storage: JSONFileStorage
  private var pendingWrite: Task<Void, Never>?

  // MARK: - Initialization

  internal init(storage: JSONFileStorage) {
    self.storage = storage
  }

  // MARK: - Access

  internal func read() async -> Data? {
    await storage.read()
  }

  internal func write(_ data: Data) {
    let previousWrite = pendingWrite
    let storage = storage
    pendingWrite = Task {
      await previousWrite?.value
      try? await storage.write(data)
    }
  }

  /// Waits until every write so far has finished.
  internal func waitForPendingWrites() async {
    await pendingWrite?.value
  }
}

/*
 * PrivilegedRunner.swift
 * FileCraft
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

import Foundation
import Synchronization

/// Runs privileged commands and jobs for "Authenticate and Retry", "Authenticate to View" and the inspector
/// (task 10.9): the helper is installed and allowed first, the user authenticates, then the helper acts. Jobs report
/// their progress and stop when the operation is cancelled (task 10.7).
nonisolated internal struct PrivilegedRunner: Sendable {

  // MARK: - Types

  internal enum RunnerError: LocalizedError, Hashable, Sendable {
    /// The user did not install or allow the helper.
    case helperNotReady
    case helper(HelperFailure)

    internal var errorDescription: String? {
      switch self {
      case .helperNotReady:
        String(localized: "FileCraft’s helper is not allowed to run.")
      case .helper(.protectedLocation):
        String(localized: "macOS protects this location, so it can’t be changed.")
      case .helper(.notAuthorized):
        String(localized: "FileCraft is not authorized to make this change.")
      case .helper(.posix(let code)):
        POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO).localizedDescription
      case .helper:
        String(localized: "The helper could not complete the operation.")
      }
    }
  }

  // MARK: - Properties

  internal var client: PrivilegedHelperClient = .shared
  /// Asks the user to install and allow the helper when needed; false when the user cancelled.
  internal var ensureReady: @Sendable () async -> Bool = { await HelperApprovalModel.shared.ensureReady() }
  /// The external form of the authorization for the next request.
  internal var authorize: @Sendable () async throws -> Data = {
    try await HelperAuthorization.shared.externalForm(prompt: String(localized: "FileCraft wants to change protected files."))
  }
  internal var pollInterval = Duration.milliseconds(100)

  // MARK: - Running

  /// Sends a privileged command and returns its result.
  internal func send(_ command: HelperCommand) async throws -> HelperResult {
    let authorization = try await prepare()
    return try await send(command, authorization: authorization)
  }

  /// Runs `job` until it finished, reporting each status; once `isCancelled` says so, the helper stops it.
  ///
  /// - Throws: `CancellationError` when the job was cancelled, `RunnerError` when it failed.
  internal func run(
    _ job: HelperJob,
    progress: @Sendable (HelperJobStatus) -> Void,
    isCancelled: @Sendable () -> Bool
  ) async throws {
    let authorization = try await prepare()
    guard case .jobStarted(let id) = try await send(.startJob(job), authorization: authorization) else {
      throw RunnerError.helper(.invalidRequest)
    }
    var hasCancelled = false
    while true {
      try? await Task.sleep(for: pollInterval)
      if isCancelled(), hasCancelled == false {
        hasCancelled = true
        _ = try? await send(.cancelJob(id: id), authorization: authorization)
      }
      guard case .jobStatus(let status) = try await send(.jobStatus(id: id), authorization: authorization) else {
        throw RunnerError.helper(.unknownJob)
      }
      progress(status)
      guard status.isFinished else {
        continue
      }
      if status.wasCancelled {
        throw CancellationError()
      }
      if let failure = status.failure {
        throw RunnerError.helper(failure)
      }
      return
    }
  }

  /// Runs `job` from an operation's thread, which waits; progress goes into `control`, and cancelling `control`
  /// stops the job in the helper.
  internal func runBlocking(_ job: HelperJob, control: OperationControl) throws {
    let outcome = Outcome()
    let runner = self
    Task.detached {
      do {
        try await runner.run(job) { status in
          control.update {
            $0.fileBytes = status.processedBytes
          }
        } isCancelled: {
          control.isCancelled
        }
        outcome.set(.success(()))
      } catch {
        outcome.set(.failure(error))
      }
    }
    while true {
      if let result = outcome.result {
        control.update { $0.fileBytes = 0 }
        try result.get()
        return
      }
      Thread.sleep(forTimeInterval: 0.05)
    }
  }

  // MARK: - Private

  private func prepare() async throws -> Data {
    guard await ensureReady() else {
      throw RunnerError.helperNotReady
    }
    return try await authorize()
  }

  private func send(_ command: HelperCommand, authorization: Data) async throws -> HelperResult {
    do {
      return try await client.send(command, authorization: authorization)
    } catch PrivilegedHelperClient.ClientError.refused(let failure) {
      throw RunnerError.helper(failure)
    } catch PrivilegedHelperClient.ClientError.needsApproval {
      throw RunnerError.helperNotReady
    }
  }
}

/// The result of an asynchronous run, handed to the thread that waits for it.
nonisolated private final class Outcome: Sendable {

  private let value = Mutex<Result<Void, any Error>?>(nil)

  var result: Result<Void, any Error>? {
    value.withLock { $0 }
  }

  func set(_ result: Result<Void, any Error>) {
    value.withLock { $0 = result }
  }
}

/*
 * HelperProtocol.swift
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

import Foundation

/// The names that FileCraft and its privileged helper share (design decision D11). This folder is compiled into
/// both targets, so everything here is explicitly nonisolated.
nonisolated internal enum HelperIdentity {

  /// The launchd label and Mach service of the helper.
  internal static let machServiceName = "de.meandmymac.FileCraft.Helper"
  /// The property list in `Contents/Library/LaunchDaemons` that `SMAppService.daemon(plistName:)` registers.
  internal static let plistName = "de.meandmymac.FileCraft.Helper.plist"
  /// The code-signing identifier of the helper, which the app requires of its peer.
  internal static let helperIdentifier = "de.meandmymac.FileCraft.Helper"
  /// The code-signing identifier of the app, which the helper requires of its peer.
  internal static let appIdentifier = "de.meandmymac.FileCraft"
  /// The authorization right every privileged request needs.
  internal static let rightName = "de.meandmymac.FileCraft.helper.file-operations"
  /// How long the right stays valid after the user authenticated, in seconds.
  internal static let rightTimeout = 300
  /// The version of the request and response format; both sides refuse other versions.
  internal static let protocolVersion = 2
}

/// A request to the privileged helper. Every request carries the protocol version; privileged commands also carry
/// the external form of the caller's authorization.
nonisolated internal struct HelperRequest: Codable, Hashable, Sendable {

  internal var version = HelperIdentity.protocolVersion
  /// The 32 bytes of an `AuthorizationExternalForm`, for commands that need the right.
  internal var authorization: Data?
  internal var command: HelperCommand

  internal init(command: HelperCommand, authorization: Data? = nil, version: Int = HelperIdentity.protocolVersion) {
    self.command = command
    self.authorization = authorization
    self.version = version
  }
}

/// What the helper is asked to do. Only typed file operations exist; the helper never runs other programs,
/// scripts or applications.
nonisolated internal enum HelperCommand: Codable, Hashable, Sendable {
  /// Answers with the helper's protocol version; needs no authorization.
  case ping
  /// The items in the folder at `path`, for Authenticate to View.
  case list(path: String)
  case createFolder(path: String)
  /// Renames the item at `path` within its folder, never replacing an existing item.
  case rename(path: String, newName: String)
  case setOwner(path: String, owner: UInt32, group: UInt32)
  /// Sets the permission bits of the item at `path`; a symbolic link is changed itself.
  case setMode(path: String, mode: UInt16)
  /// Sets the file flags, such as the locked flag, of the item at `path`.
  case setFlags(path: String, flags: UInt32)
  /// Starts a copy, move or deletion that reports progress and can be cancelled.
  case startJob(HelperJob)
  case jobStatus(id: UUID)
  case cancelJob(id: UUID)

  /// Whether the command needs the authorization right.
  internal var requiresAuthorization: Bool {
    self != .ping
  }

  /// The operation's name for the log, without paths.
  internal var logName: String {
    switch self {
    case .ping:
      "ping"
    case .list:
      "list"
    case .createFolder:
      "create folder"
    case .rename:
      "rename"
    case .setOwner:
      "set owner"
    case .setMode:
      "set mode"
    case .setFlags:
      "set flags"
    case .startJob(let job):
      "start \(job.logName)"
    case .jobStatus:
      "job status"
    case .cancelJob:
      "cancel job"
    }
  }
}

/// A long-running privileged operation on one item. Destinations are exact paths that must not exist.
nonisolated internal enum HelperJob: Codable, Hashable, Sendable {
  case copy(source: String, destination: String)
  case move(source: String, destination: String)
  case delete(path: String)

  internal var paths: [String] {
    switch self {
    case .copy(let source, let destination), .move(let source, let destination):
      [source, destination]
    case .delete(let path):
      [path]
    }
  }

  internal var logName: String {
    switch self {
    case .copy:
      "copy"
    case .move:
      "move"
    case .delete:
      "delete"
    }
  }
}

/// An item of a folder that the helper listed.
nonisolated internal struct HelperListedItem: Codable, Hashable, Sendable {
  internal var name: String
  internal var isDirectory: Bool
  internal var isSymbolicLink: Bool
  internal var size: Int64
  internal var modificationDate: Date
}

/// The progress of a job.
nonisolated internal struct HelperJobStatus: Codable, Hashable, Sendable {
  internal var processedItems = 0
  internal var processedBytes: Int64 = 0
  internal var isFinished = false
  internal var wasCancelled = false
  internal var failure: HelperFailure?
}

/// The helper's answer.
nonisolated internal struct HelperResponse: Codable, Hashable, Sendable {
  /// The helper's protocol version.
  internal var version = HelperIdentity.protocolVersion
  internal var result: HelperResult
}

nonisolated internal enum HelperResult: Codable, Hashable, Sendable {
  case pong
  /// The command succeeded.
  case done
  case listing([HelperListedItem])
  case jobStarted(UUID)
  case jobStatus(HelperJobStatus)
  case failure(HelperFailure)
}

/// Why the helper refused or failed a request.
nonisolated internal enum HelperFailure: Error, Codable, Hashable, Sendable {
  /// The request had another protocol version than the helper.
  case versionMismatch(helperVersion: Int)
  /// The request lacked a valid authorization for the right.
  case notAuthorized
  case invalidRequest
  /// The path is not absolute, contains "." or "..", or changed while it was resolved.
  case invalidPath
  /// The location is protected by System Integrity Protection.
  case protectedLocation
  /// A file system call failed with this POSIX error code.
  case posix(Int32)
  case unknownJob
}

/// Answers requests: checks the protocol version and the authorization, then runs the command. The helper uses it
/// with the real authorization check; tests use it in the app's process on temporary folders.
nonisolated internal struct HelperRequestHandler: Sendable {

  /// Whether the external authorization form grants the right.
  internal let isAuthorized: @Sendable (Data?) -> Bool
  internal var jobs = HelperJobs()
  /// Records the operation, its paths (private in the log) and the outcome.
  internal var log: @Sendable (_ operation: String, _ paths: [String], _ outcome: String) -> Void = { _, _, _ in }

  internal func handle(_ request: HelperRequest) -> HelperResponse {
    guard request.version == HelperIdentity.protocolVersion else {
      return HelperResponse(result: .failure(.versionMismatch(helperVersion: HelperIdentity.protocolVersion)))
    }
    if request.command.requiresAuthorization, isAuthorized(request.authorization) == false {
      log(request.command.logName, [], "not authorized")
      return HelperResponse(result: .failure(.notAuthorized))
    }
    let result: HelperResult
    do throws(HelperFailure) {
      result = try run(request.command)
    } catch {
      result = .failure(error)
    }
    log(request.command.logName, Self.paths(of: request.command), Self.outcome(of: result))
    return HelperResponse(result: result)
  }

  // MARK: - Private

  private func run(_ command: HelperCommand) throws(HelperFailure) -> HelperResult {
    switch command {
    case .ping:
      return .pong
    case .list(let path):
      return .listing(try HelperFileSystem.list(path))
    case .createFolder(let path):
      try HelperFileSystem.createFolder(path)
    case .rename(let path, let newName):
      try HelperFileSystem.rename(path, to: newName)
    case .setOwner(let path, let owner, let group):
      try HelperFileSystem.setOwner(path, owner: owner, group: group)
    case .setMode(let path, let mode):
      try HelperFileSystem.setMode(path, mode: mode)
    case .setFlags(let path, let flags):
      try HelperFileSystem.setFlags(path, flags: flags)
    case .startJob(let job):
      for path in job.paths {
        try HelperFileSystem.validate(path)
      }
      return .jobStarted(jobs.start(job))
    case .jobStatus(let id):
      guard let status = jobs.status(of: id) else {
        throw .unknownJob
      }
      return .jobStatus(status)
    case .cancelJob(let id):
      guard jobs.cancel(id) else {
        throw .unknownJob
      }
    }
    return .done
  }

  private static func paths(of command: HelperCommand) -> [String] {
    switch command {
    case .ping, .jobStatus, .cancelJob:
      []
    case .list(let path), .createFolder(let path), .rename(let path, _), .setOwner(let path, _, _),
      .setMode(let path, _), .setFlags(let path, _):
      [path]
    case .startJob(let job):
      job.paths
    }
  }

  private static func outcome(of result: HelperResult) -> String {
    if case .failure(let failure) = result {
      return "failed: \(failure)"
    }
    return "succeeded"
  }
}

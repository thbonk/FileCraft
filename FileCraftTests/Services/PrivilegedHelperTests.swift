/*
 * PrivilegedHelperTests.swift
 * FileCraftTests
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
import Testing
@testable import FileCraft

/// The protocol, the client and the approval flow of the privileged helper, against a mock registrar and a mock
/// transport that runs the helper's request handler in this process. Nothing is registered with launchd.
internal struct PrivilegedHelperTests {

  // MARK: - Protocol

  @Test
  internal func `Requests and responses survive encoding`() throws {
    let request = HelperRequest(command: .ping, authorization: Data(repeating: 7, count: 32))
    let response = HelperResponse(result: .failure(.versionMismatch(helperVersion: 3)))

    let decodedRequest = try JSONDecoder().decode(HelperRequest.self, from: JSONEncoder().encode(request))
    let decodedResponse = try JSONDecoder().decode(HelperResponse.self, from: JSONEncoder().encode(response))

    #expect(decodedRequest == request)
    #expect(decodedResponse == response)
  }

  @Test
  internal func `The helper answers a ping and refuses another protocol version`() {
    let handler = HelperRequestHandler(isAuthorized: { _ in false })

    let ping = handler.handle(HelperRequest(command: .ping))
    let otherVersion = handler.handle(HelperRequest(command: .ping, version: HelperIdentity.protocolVersion + 1))

    #expect(ping.result == .pong)
    #expect(otherVersion.result == .failure(.versionMismatch(helperVersion: HelperIdentity.protocolVersion)))
  }

  @Test
  internal func `An authorization is reused for at most five minutes`() {
    let obtained = Date(timeIntervalSince1970: 1_000)
    let reuse = AuthorizationReuse(obtainedAt: obtained)

    #expect(reuse.isValid(at: obtained + 299))
    #expect(reuse.isValid(at: obtained + 300) == false)
    #expect(reuse.isValid(at: obtained - 1) == false)
  }

  // MARK: - Client

  @Test
  internal func `The client registers the helper and asks for approval before sending`() async {
    let registrar = MockRegistrar(status: .notRegistered, statusAfterRegistering: .requiresApproval)
    let client = PrivilegedHelperClient(registrar: registrar, transport: MockTransport())

    await #expect(throws: PrivilegedHelperClient.ClientError.needsApproval) {
      try await client.send(.ping)
    }
    #expect(registrar.registrations == 1)
  }

  @Test
  internal func `A helper of another protocol version is registered again and asked once more`() async throws {
    let registrar = MockRegistrar(status: .enabled)
    let transport = MockTransport(helperVersions: [HelperIdentity.protocolVersion + 1, HelperIdentity.protocolVersion])
    let client = PrivilegedHelperClient(registrar: registrar, transport: transport)

    let result = try await client.send(.ping)

    #expect(result == .pong)
    #expect(registrar.unregistrations == 1)
    #expect(registrar.registrations == 1)
    #expect(transport.requestCount == 2)
  }

  // MARK: - Approval

  @Test
  internal func `The helper is explained before it is registered, then waits for the approval`() async {
    let registrar = MockRegistrar(status: .notRegistered, statusAfterRegistering: .requiresApproval)
    let model = HelperApprovalModel(client: PrivilegedHelperClient(registrar: registrar, transport: MockTransport()), openSettings: {})

    let waiting = Task { await model.ensureReady() }
    await waitUntil { model.phase != nil }
    let explained = model.phase == .install && registrar.registrations == 0
    model.install()
    let askedForApproval = model.phase == .approval
    model.recheck()
    let stillWaiting = model.phase == .approval
    registrar.setStatus(.enabled)
    model.recheck()
    let isReady = await waiting.value

    #expect(explained)
    #expect(askedForApproval)
    #expect(stillWaiting)
    #expect(isReady)
    #expect(model.phase == nil)
  }

  @Test
  internal func `A helper reported as not found before its first registration is still installed`() async throws {
    let registrar = MockRegistrar(status: .notFound, statusAfterRegistering: .requiresApproval, registrationThrows: true)
    let client = PrivilegedHelperClient(registrar: registrar, transport: MockTransport())
    let model = HelperApprovalModel(client: client, openSettings: {})

    let waiting = Task { await model.ensureReady() }
    await waitUntil { model.phase != nil }
    let offersInstall = model.phase == .install
    model.install()
    let asksForApproval = model.phase == .approval
    model.cancel()
    _ = await waiting.value

    #expect(offersInstall)
    #expect(asksForApproval)
    #expect(registrar.registrations == 1)
    #expect(try client.registerIfNeeded() == .requiresApproval)
  }

  @Test
  internal func `Cancelling the approval tells the waiting action`() async {
    let model = HelperApprovalModel(
      client: PrivilegedHelperClient(registrar: MockRegistrar(status: .requiresApproval), transport: MockTransport()),
      openSettings: {})

    let waiting = Task { await model.ensureReady() }
    await waitUntil { model.phase != nil }
    model.cancel()

    #expect(await waiting.value == false)
  }

  // MARK: - Runner

  @Test
  internal func `A job runs through the helper until it finished and reports its progress`() async throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFile("a.txt", contents: "abc")
    let destination = directory.url.appending(path: "b.txt")
    let statuses = StatusLog()

    try await runner().run(
      .copy(source: source.path(percentEncoded: false), destination: destination.path(percentEncoded: false)),
      progress: { statuses.append($0) },
      isCancelled: { false })

    #expect(try String(contentsOf: destination, encoding: .utf8) == "abc")
    #expect(statuses.last?.isFinished == true)
    #expect(statuses.last?.processedBytes == 3)
  }

  @Test
  internal func `Helper failures and a refused approval become runner errors`() async throws {
    let directory = try TemporaryDirectory()
    let missing = directory.url.appending(path: "missing.txt").path(percentEncoded: false)
    var notReady = runner()
    notReady.ensureReady = { false }

    await #expect(throws: PrivilegedRunner.RunnerError.helper(.posix(ENOENT))) {
      try await runner().run(.delete(path: missing), progress: { _ in }, isCancelled: { false })
    }
    await #expect(throws: PrivilegedRunner.RunnerError.helperNotReady) {
      try await notReady.send(.createFolder(path: missing))
    }
    #expect(PrivilegedRunner.RunnerError.helper(.protectedLocation).errorDescription?.isEmpty == false)
  }

  // MARK: - Inspector

  @Test
  internal func `Only permission and Locked edits go through the helper`() {
    let url = URL(filePath: "/tmp/a.txt")

    #expect(InspectorModel.canApplyThroughHelper(.mode(url, from: 0o644, to: 0o600)))
    #expect(InspectorModel.canApplyThroughHelper(.attribute(url, .locked, from: false, to: true)))
    #expect(InspectorModel.canApplyThroughHelper(.attribute(url, .hidden, from: false, to: true)) == false)
    #expect(InspectorModel.canApplyThroughHelper(.batch([.mode(url, from: 0o644, to: 0o600), .tags(url, from: [], to: ["Red"])])) == false)
  }

  // MARK: - Helpers

  /// A runner whose helper runs in this process; installing and authenticating always succeed.
  private func runner() -> PrivilegedRunner {
    var runner = PrivilegedRunner(client: PrivilegedHelperClient(registrar: MockRegistrar(status: .enabled), transport: MockTransport()))
    runner.ensureReady = { true }
    runner.authorize = { Data(repeating: 1, count: 32) }
    runner.pollInterval = .milliseconds(10)
    return runner
  }

  private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<200 where condition() == false {
      await Task.yield()
      try? await Task.sleep(for: .milliseconds(5))
    }
  }
}

// MARK: - Mocks

/// A launch daemon registration in memory.
nonisolated private final class MockRegistrar: HelperRegistrar {

  private struct State {
    var status: HelperStatus
    var statusAfterRegistering: HelperStatus
    var registrations = 0
    var unregistrations = 0
  }

  private let state: Mutex<State>

  private let registrationThrows: Bool

  /// - Parameter registrationThrows: Whether `register()` throws after changing the status, as `SMAppService` does
  ///   for a daemon that waits for approval.
  init(status: HelperStatus, statusAfterRegistering: HelperStatus = .enabled, registrationThrows: Bool = false) {
    state = Mutex(State(status: status, statusAfterRegistering: statusAfterRegistering))
    self.registrationThrows = registrationThrows
  }

  var status: HelperStatus {
    state.withLock { $0.status }
  }

  var registrations: Int {
    state.withLock { $0.registrations }
  }

  var unregistrations: Int {
    state.withLock { $0.unregistrations }
  }

  func setStatus(_ status: HelperStatus) {
    state.withLock { $0.status = status }
  }

  func register() throws {
    state.withLock {
      $0.registrations += 1
      $0.status = $0.statusAfterRegistering
    }
    if registrationThrows {
      throw POSIXError(.EPERM)
    }
  }

  func unregister() async throws {
    state.withLock {
      $0.unregistrations += 1
      $0.status = .notRegistered
    }
  }
}

/// Runs the helper's request handler in this process; each request can see another helper version.
nonisolated private final class MockTransport: HelperTransport {

  private let state: Mutex<(versions: [Int], count: Int)>

  init(helperVersions: [Int] = []) {
    state = Mutex((helperVersions, 0))
  }

  var requestCount: Int {
    state.withLock { $0.count }
  }

  /// One handler for all requests, so that jobs started by one request are found by the next.
  private let handler = HelperRequestHandler(isAuthorized: { _ in true })

  func send(_ request: HelperRequest) async throws -> HelperResponse {
    let helperVersion = state.withLock { state -> Int in
      state.count += 1
      return state.versions.isEmpty ? HelperIdentity.protocolVersion : state.versions.removeFirst()
    }
    guard helperVersion == HelperIdentity.protocolVersion else {
      return HelperResponse(version: helperVersion, result: .failure(.versionMismatch(helperVersion: helperVersion)))
    }
    return handler.handle(request)
  }
}

nonisolated private final class StatusLog: Sendable {

  private let statuses = Mutex<[HelperJobStatus]>([])

  var last: HelperJobStatus? {
    statuses.withLock { $0.last }
  }

  func append(_ status: HelperJobStatus) {
    statuses.withLock { $0.append(status) }
  }
}

nonisolated private final class Counter: Sendable {

  private let count = Mutex(0)

  var value: Int {
    count.withLock { $0 }
  }

  func increment() {
    count.withLock { $0 += 1 }
  }
}

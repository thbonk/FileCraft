/*
 * DirectoryWatcher.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-10-30.
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

import CoreServices
import Dispatch
import Foundation
import Synchronization

/// A change reported for a watched folder.
nonisolated internal struct DirectoryChange: Hashable, Sendable {
  /// The names of direct children that were created, modified, renamed or deleted.
  internal let changedNames: Set<String>
  /// Whether the folder must be reloaded completely, for example because events were dropped.
  internal let requiresFullReload: Bool
}

/// Watches folders with FSEvents.
nonisolated internal enum DirectoryWatcher {

  /// Returns a stream of changes to the direct children of `directory`.
  ///
  /// FSEvents coalesces events that arrive within `latency`. Watching stops when the consumer stops iterating.
  internal static func changes(in directory: URL, latency: Duration = .milliseconds(250)) -> AsyncStream<DirectoryChange> {
    let (stream, continuation) = AsyncStream.makeStream(
      of: DirectoryChange.self,
      bufferingPolicy: .bufferingNewest(32))
    let session = WatchSession(directoryPath: normalizedPath(of: directory), continuation: continuation)
    guard session.start(latency: latency) else {
      continuation.finish()
      return stream
    }
    continuation.onTermination = { _ in
      session.stop()
    }
    return stream
  }

  /// FSEvents reports canonical paths without a trailing slash, for example "/private/var/…" for "/var/…".
  ///
  /// `resolvingSymlinksInPath()` would strip "/private" again, so the canonical path resource value is used.
  internal static func normalizedPath(of url: URL) -> String {
    let canonicalPath = try? url.resourceValues(forKeys: [.canonicalPathKey]).canonicalPath
    let path = canonicalPath ?? url.standardizedFileURL.path(percentEncoded: false)
    return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
  }
}

/// Owns one FSEvents stream and forwards its events into an `AsyncStream`.
///
/// FSEvents delivers callbacks on a private serial queue, and the stream is stopped on that queue as well,
/// so a callback never runs after the stream was released.
nonisolated private final class WatchSession: Sendable {

  // MARK: - Properties

  private let directoryPath: String
  private let continuation: AsyncStream<DirectoryChange>.Continuation
  private let queue = DispatchQueue(label: "de.meandmymac.FileCraft.DirectoryWatcher")
  private let eventStream = Mutex<FSEventStreamRef?>(nil)

  private static let reloadFlags = FSEventStreamEventFlags(
    kFSEventStreamEventFlagMustScanSubDirs
      | kFSEventStreamEventFlagUserDropped
      | kFSEventStreamEventFlagKernelDropped
      | kFSEventStreamEventFlagRootChanged)

  // MARK: - Initialization

  internal init(directoryPath: String, continuation: AsyncStream<DirectoryChange>.Continuation) {
    self.directoryPath = directoryPath
    self.continuation = continuation
  }

  // MARK: - Lifecycle

  /// Creates and starts the FSEvents stream; returns false when FSEvents refuses the path.
  internal func start(latency: Duration) -> Bool {
    let seconds = Double(latency.components.seconds) + Double(latency.components.attoseconds) / 1e18
    let directoryPath = directoryPath
    let queue = queue
    // Everything the stream is created from lives inside the lock, so the stream never leaves
    // the mutex's isolation region.
    return eventStream.withLock { storedStream -> Bool in
      // The stream keeps the session alive until it is released; the release callback balances this retain.
      var context = FSEventStreamContext(
        version: 0,
        info: Unmanaged.passRetained(self).toOpaque(),
        retain: nil,
        release: { info in
          guard let info else {
            return
          }
          Unmanaged<WatchSession>.fromOpaque(info).release()
        },
        copyDescription: nil)
      let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
        guard let info else {
          return
        }
        let session = Unmanaged<WatchSession>.fromOpaque(info).takeUnretainedValue()
        let eventPaths = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as? [String] ?? []
        let eventFlags = Array(UnsafeBufferPointer(start: flags, count: count))
        session.handle(paths: eventPaths, flags: eventFlags)
      }
      let flags = FSEventStreamCreateFlags(
        kFSEventStreamCreateFlagUseCFTypes
          | kFSEventStreamCreateFlagFileEvents
          | kFSEventStreamCreateFlagWatchRoot
          | kFSEventStreamCreateFlagNoDefer)
      guard
        let stream = FSEventStreamCreate(
          kCFAllocatorDefault,
          callback,
          &context,
          [directoryPath] as CFArray,
          FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
          seconds,
          flags)
      else {
        Unmanaged.passUnretained(self).release()
        return false
      }
      FSEventStreamSetDispatchQueue(stream, queue)
      guard FSEventStreamStart(stream) else {
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        return false
      }
      storedStream = stream
      return true
    }
  }

  /// Stops and releases the FSEvents stream on the delivery queue.
  internal func stop() {
    queue.async {
      self.eventStream.withLock { stream in
        guard let activeStream = stream else {
          return
        }
        FSEventStreamStop(activeStream)
        FSEventStreamInvalidate(activeStream)
        FSEventStreamRelease(activeStream)
        stream = nil
      }
    }
  }

  // MARK: - Events

  private func handle(paths: [String], flags: [FSEventStreamEventFlags]) {
    var changedNames = Set<String>()
    var requiresFullReload = false
    for (path, flag) in zip(paths, flags) {
      let normalized = path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
      if flag & Self.reloadFlags != 0 || normalized == directoryPath {
        requiresFullReload = true
        continue
      }
      let item = normalized as NSString
      if item.deletingLastPathComponent == directoryPath {
        changedNames.insert(item.lastPathComponent)
      }
    }
    if requiresFullReload || changedNames.isEmpty == false {
      continuation.yield(DirectoryChange(changedNames: changedNames, requiresFullReload: requiresFullReload))
    }
  }
}

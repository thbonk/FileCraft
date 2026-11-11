/*
 * VolumeMonitor.swift
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

import AppKit
import Foundation

/// A change in the set of mounted volumes.
nonisolated internal enum VolumeEvent: Hashable, Sendable {
  case mounted(URL)
  case unmounted(URL)
  case renamed(URL)
}

/// Lists mounted volumes and reports mount, unmount and rename events.
nonisolated internal struct VolumeMonitor: Sendable {

  // MARK: - Properties

  private static let resourceKeys: [URLResourceKey] = [
    .volumeLocalizedNameKey,
    .volumeTotalCapacityKey,
    .volumeAvailableCapacityForImportantUsageKey,
    .volumeAvailableCapacityKey,
    .volumeIsEjectableKey,
    .volumeIsRemovableKey,
    .volumeIsInternalKey,
    .volumeIsLocalKey,
    .volumeIsRootFileSystemKey,
  ]

  // MARK: - Volumes

  /// Returns the visible mounted volumes.
  @concurrent
  internal func mountedVolumes() async -> [Volume] {
    let urls = FileManager.default.mountedVolumeURLs(
      includingResourceValuesForKeys: Self.resourceKeys,
      options: [.skipHiddenVolumes]) ?? []
    return urls.compactMap(Self.makeVolume)
  }

  // MARK: - Events

  /// Returns a stream of volume events. Observation stops when the consumer stops iterating.
  internal func events() -> AsyncStream<VolumeEvent> {
    let (stream, continuation) = AsyncStream.makeStream(of: VolumeEvent.self, bufferingPolicy: .bufferingNewest(32))
    let task = Task {
      await withDiscardingTaskGroup { group in
        group.addTask {
          await Self.forward(NSWorkspace.didMountNotification, as: VolumeEvent.mounted, to: continuation)
        }
        group.addTask {
          await Self.forward(NSWorkspace.didUnmountNotification, as: VolumeEvent.unmounted, to: continuation)
        }
        group.addTask {
          await Self.forward(NSWorkspace.didRenameVolumeNotification, as: VolumeEvent.renamed, to: continuation)
        }
      }
      continuation.finish()
    }
    continuation.onTermination = { _ in
      task.cancel()
    }
    return stream
  }

  // MARK: - Private

  private static func forward(
    _ name: Notification.Name,
    as makeEvent: @Sendable (URL) -> VolumeEvent,
    to continuation: AsyncStream<VolumeEvent>.Continuation
  ) async {
    for await notification in NSWorkspace.shared.notificationCenter.notifications(named: name) {
      guard let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else {
        continue
      }
      continuation.yield(makeEvent(url))
    }
  }

  private static func makeVolume(at url: URL) -> Volume? {
    guard let values = try? url.resourceValues(forKeys: Set(resourceKeys)) else {
      return nil
    }
    return Volume(
      url: url,
      name: values.volumeLocalizedName ?? url.lastPathComponent,
      totalCapacity: values.volumeTotalCapacity.map(Int64.init),
      availableCapacity: Volume.availableCapacity(
        importantUsage: values.volumeAvailableCapacityForImportantUsage, plain: values.volumeAvailableCapacity),
      isEjectable: values.volumeIsEjectable ?? false,
      isRemovable: values.volumeIsRemovable ?? false,
      isInternal: values.volumeIsInternal ?? true,
      isLocal: values.volumeIsLocal ?? true,
      isRootFileSystem: values.volumeIsRootFileSystem ?? false)
  }
}

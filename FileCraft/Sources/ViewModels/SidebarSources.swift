/*
 * SidebarSources.swift
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
import Observation

/// The mounted volumes and the tags that the sidebars of all windows list.
///
/// Both load once when the app starts and arrive in a single update, so that the first sidebar appears complete:
/// a SwiftUI `List` whose sections change during its first layout passes changes its outline view from inside a
/// delegate call, which AppKit reports as a reentrant operation. Volumes stay current with mount, unmount and
/// rename events.
@Observable
internal final class SidebarSources {

  // MARK: - Properties

  /// The sources of the app.
  internal static let shared = SidebarSources()

  /// The mounted volumes, startup volume first.
  internal private(set) var volumes: [Volume] = []
  internal private(set) var tags: [String] = []
  /// Whether volumes and tags have been loaded once; the sidebar waits for it.
  internal private(set) var isLoaded = false

  @ObservationIgnored private var observation: Task<Void, Never>?

  // MARK: - Initialization

  internal init() {}

  /// Sources with fixed contents that never touch the system, for previews.
  internal init(previewVolumes: [Volume], tags: [String]) {
    volumes = previewVolumes
    self.tags = tags
    isLoaded = true
    observation = Task {}
  }

  // MARK: - Loading

  /// Loads the volumes and tags and keeps the volumes current; later calls do nothing.
  internal func start() {
    guard observation == nil else {
      return
    }
    observation = Task {
      await observeVolumesAndLoadTags()
    }
  }

  // MARK: - Private

  private func observeVolumesAndLoadTags() async {
    let monitor = VolumeMonitor()
    // Subscribe before the first load, so that a volume mounted meanwhile is not missed.
    let events = monitor.events()
    async let loadedTags = TagLibrary.userTags()
    let loadedVolumes = Self.sorted(await monitor.mountedVolumes())
    let tags = await loadedTags
    volumes = loadedVolumes
    self.tags = tags
    isLoaded = true
    for await _ in events {
      volumes = Self.sorted(await monitor.mountedVolumes())
    }
  }

  private static func sorted(_ volumes: [Volume]) -> [Volume] {
    volumes.sorted { lhs, rhs in
      if lhs.isRootFileSystem != rhs.isRootFileSystem {
        return lhs.isRootFileSystem
      }
      return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
  }
}

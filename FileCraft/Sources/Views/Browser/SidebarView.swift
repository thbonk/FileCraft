/*
 * SidebarView.swift
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
import SwiftUI

/// The sidebar of a browser window: Favorites, Locations, iCloud and Tags.
///
/// A click shows an entry in the active tab and ⌘-click in a new tab; a file favorite opens with its default
/// application. The entry of the active tab's location is highlighted.
internal struct SidebarView: View {

  // MARK: - Types

  /// The keys of the sections' expansion state, shared by all windows.
  private enum ExpansionKey {
    static let favorites = "sidebar.isFavoritesExpanded"
    static let locations = "sidebar.isLocationsExpanded"
    static let iCloud = "sidebar.isICloudExpanded"
    static let tags = "sidebar.isTagsExpanded"
  }

  /// A failed eject; without a message the volume was busy.
  private struct EjectFailure {
    let volumeName: String
    let message: String?
  }

  // MARK: - Properties

  internal let window: BrowserWindowModel
  internal let favorites: FavoritesStore
  /// The volumes and tags, loaded once for all windows.
  internal let sources: SidebarSources

  @AppStorage(SettingsKeys.showsFavorites.name) private var showsFavorites = SettingsKeys.showsFavorites.defaultValue
  @AppStorage(SettingsKeys.showsLocations.name) private var showsLocations = SettingsKeys.showsLocations.defaultValue
  @AppStorage(SettingsKeys.showsICloud.name) private var showsICloud = SettingsKeys.showsICloud.defaultValue
  @AppStorage(SettingsKeys.showsTags.name) private var showsTags = SettingsKeys.showsTags.defaultValue
  @AppStorage(SettingsKeys.showsVolumeUsage.name) private var showsVolumeUsage = SettingsKeys.showsVolumeUsage.defaultValue
  @AppStorage(SettingsKeys.sizeUnits.name) private var sizeUnits = SettingsKeys.sizeUnits.defaultValue
  @AppStorage(ExpansionKey.favorites) private var isFavoritesExpanded = true
  @AppStorage(ExpansionKey.locations) private var isLocationsExpanded = true
  @AppStorage(ExpansionKey.iCloud) private var isICloudExpanded = true
  @AppStorage(ExpansionKey.tags) private var isTagsExpanded = true
  @Environment(\.locale) private var locale
  @State private var unavailableFavorite: Favorite?
  @State private var ejectFailure: EjectFailure?
  /// The tag that could not be added to some dropped items.
  @State private var failedTag: String?

  private static let iCloudDrive = StandardLocation.iCloudDrive.url()
  /// Whether iCloud Drive is turned on; checked once per launch.
  private static let isICloudDriveAvailable = StandardLocation.isICloudDriveAvailable()

  private var volumes: [Volume] {
    sources.volumes
  }

  private var tags: [String] {
    sources.tags
  }

  // MARK: - Body

  internal var body: some View {
    // The list starts once all entries are known: sections that change during the list's first layout passes
    // make SwiftUI update the outline view from inside a delegate call, which AppKit reports as reentrant.
    if favorites.isLoaded && sources.isLoaded {
      sidebarList
    } else {
      List {}
    }
  }

  private var sidebarList: some View {
    List(selection: selection) {
      if showsFavorites {
        favoritesSection
      }
      if showsLocations {
        locationsSection
      }
      if showsICloud, Self.isICloudDriveAvailable {
        Section("iCloud", isExpanded: $isICloudExpanded) {
          Label("iCloud Drive", systemImage: "icloud")
            .tag(SidebarItem.iCloudDrive)
            .contextMenu {
              openInNewTabButton(.iCloudDrive)
            }
        }
      }
      if showsTags, tags.isEmpty == false {
        tagsSection
      }
    }
    .alert(unavailableTitle, isPresented: isShowingUnavailableFavorite, presenting: unavailableFavorite) { favorite in
      Button("Remove from Sidebar", role: .destructive) {
        favorites.remove(favorite.id)
      }
      Button("Cancel", role: .cancel) {}
    } message: { _ in
      Text("The item may have been deleted, or it is on a volume that is not connected.")
    }
    .alert(ejectFailureTitle, isPresented: isShowingEjectFailure, presenting: ejectFailure) { _ in
      Button("OK") {}
    } message: { failure in
      if let message = failure.message {
        Text(verbatim: message)
      } else {
        Text("Quit the applications that use the volume, then try again.")
      }
    }
    .alert(Text("Some items could not get the tag “\(failedTag ?? "")”."), isPresented: isShowingTagFailure) {
      Button("OK") {}
    }
  }

  // MARK: - Sections

  private var favoritesSection: some View {
    Section("Favorites", isExpanded: $isFavoritesExpanded) {
      ForEach(favorites.favorites) { favorite in
        FavoriteRow(favorite: favorite, isAvailable: favorites.unavailableIDs.contains(favorite.id) == false)
          // Dropping onto a folder moves or copies into it; dropping between rows adds favorites.
          .fileDropTarget(FileCopier.isDirectory(favorite.url) ? favorite.url : nil, tab: window.activeTab)
          .tag(SidebarItem.favorite(favorite.id))
          .contextMenu {
            openInNewTabButton(.favorite(favorite.id))
            Button("Remove from Sidebar") {
              favorites.remove(favorite.id)
            }
          }
      }
      .onMove { source, destination in
        favorites.move(fromOffsets: source, toOffset: destination)
      }
      .dropDestination(for: URL.self) { urls, index in
        Task {
          await favorites.add(urls, at: index)
        }
      }
    }
  }

  private var locationsSection: some View {
    Section("Locations", isExpanded: $isLocationsExpanded) {
      Label(ComputerName.current, systemImage: Location.computer.systemImage)
        .tag(SidebarItem.computer)
        .contextMenu {
          openInNewTabButton(.computer)
        }
      ForEach(volumes) { volume in
        VolumeRow(volume: volume, showsUsage: showsVolumeUsage, formatter: ByteSizeFormatter(units: sizeUnits, locale: locale)) {
          eject(volume)
        }
        .fileDropTarget(volume.url, tab: window.activeTab)
        .tag(SidebarItem.volume(volume.url))
        .contextMenu {
          openInNewTabButton(.volume(volume.url))
          if volume.canEject {
            Button("Eject") {
              eject(volume)
            }
          }
        }
      }
    }
  }

  private var tagsSection: some View {
    Section("Tags", isExpanded: $isTagsExpanded) {
      ForEach(tags, id: \.self) { tag in
        TagRow(name: tag) { urls in
          addTag(tag, to: urls)
        }
        .tag(SidebarItem.tag(tag))
        .contextMenu {
          openInNewTabButton(.tag(tag))
        }
      }
    }
  }

  private func openInNewTabButton(_ item: SidebarItem) -> some View {
    Button("Open in New Tab") {
      open(item, inNewTab: true)
    }
  }

  // MARK: - Selection

  /// The highlighted entry follows the active tab; choosing an entry shows it, in a new tab while ⌘ is held.
  private var selection: Binding<SidebarItem?> {
    Binding {
      highlightedItem
    } set: { item in
      // The list also reports the highlight following the active tab; only a different entry is a choice.
      guard let item, item != highlightedItem else {
        return
      }
      open(item, inNewTab: NSEvent.modifierFlags.contains(.command))
    }
  }

  private var highlightedItem: SidebarItem? {
    SidebarItem.matching(
      window.activeTab.location,
      favorites: favorites.favorites,
      volumes: volumes.map(\.url),
      iCloudDrive: Self.iCloudDrive)
  }

  private func open(_ item: SidebarItem, inNewTab: Bool) {
    switch item {
    case .favorite(let id):
      Task {
        switch await favorites.target(of: id) {
        case .folder(let reference):
          window.show(.folder(reference), inNewTab: inNewTab)
        case .file(let url):
          WorkspaceActions.open(url)
        case .unavailable:
          unavailableFavorite = favorites.favorites.first { $0.id == id }
        }
      }
    case .computer:
      window.show(.computer, inNewTab: inNewTab)
    case .volume(let url):
      showFolder(url, inNewTab: inNewTab)
    case .iCloudDrive:
      if let url = Self.iCloudDrive {
        showFolder(url, inNewTab: inNewTab)
      }
    case .tag(let name):
      window.show(.tag(name), inNewTab: inNewTab)
    }
  }

  private func showFolder(_ url: URL, inNewTab: Bool) {
    guard let reference = try? FileReference(url: url) else {
      return
    }
    window.show(.folder(reference), inNewTab: inNewTab)
  }

  // MARK: - Volumes and Tags

  private func eject(_ volume: Volume) {
    Task {
      switch await VolumeActions.eject(volume.url) {
      case .ejected:
        // The unmount event removes the volume and sends tabs showing it home.
        break
      case .busy:
        ejectFailure = EjectFailure(volumeName: volume.name, message: nil)
      case .failed(let message):
        ejectFailure = EjectFailure(volumeName: volume.name, message: message)
      }
    }
  }

  private func addTag(_ tag: String, to urls: [URL]) {
    Task {
      if await TagLibrary.addTag(tag, to: urls).isEmpty == false {
        failedTag = tag
      }
    }
  }

  // MARK: - Alerts

  private var unavailableTitle: Text {
    Text("“\(unavailableFavorite?.name ?? "")” is not available.")
  }

  private var ejectFailureTitle: Text {
    guard let ejectFailure else {
      return Text(verbatim: "")
    }
    return ejectFailure.message == nil
      ? Text("“\(ejectFailure.volumeName)” can't be ejected because it is in use.")
      : Text("“\(ejectFailure.volumeName)” could not be ejected.")
  }

  private var isShowingUnavailableFavorite: Binding<Bool> {
    Binding {
      unavailableFavorite != nil
    } set: { isPresented in
      if isPresented == false {
        unavailableFavorite = nil
      }
    }
  }

  private var isShowingEjectFailure: Binding<Bool> {
    Binding {
      ejectFailure != nil
    } set: { isPresented in
      if isPresented == false {
        ejectFailure = nil
      }
    }
  }

  private var isShowingTagFailure: Binding<Bool> {
    Binding {
      failedTag != nil
    } set: { isPresented in
      if isPresented == false {
        failedTag = nil
      }
    }
  }
}

// MARK: - Rows

/// A favorite with its icon; dimmed while its item is unavailable.
private struct FavoriteRow: View {

  let favorite: Favorite
  let isAvailable: Bool

  var body: some View {
    Label {
      Text(verbatim: favorite.name)
    } icon: {
      FileIcon(url: favorite.url)
    }
    .opacity(isAvailable ? 1 : 0.45)
    .help(Text(verbatim: favorite.reference.lastKnownPath))
  }
}

/// A volume with its capacity as help tag, an optional usage bar and an eject button.
private struct VolumeRow: View {

  let volume: Volume
  let showsUsage: Bool
  let formatter: ByteSizeFormatter
  let eject: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      Label {
        VStack(alignment: .leading, spacing: 2) {
          Text(verbatim: volume.name)
            .lineLimit(1)
          if showsUsage, let usedFraction {
            ProgressView(value: usedFraction)
              .controlSize(.mini)
              .accessibilityLabel(Text("Used Space"))
          }
        }
      } icon: {
        FileIcon(url: volume.url)
      }
      Spacer(minLength: 0)
      if volume.canEject {
        Button(action: eject) {
          Image(systemName: "eject")
        }
        .buttonStyle(.borderless)
        .help(Text("Eject"))
        .accessibilityLabel(Text("Eject “\(volume.name)”"))
      }
    }
    .help(capacity)
  }

  private var usedFraction: Double? {
    guard let total = volume.totalCapacity, total > 0, let available = volume.availableCapacity else {
      return nil
    }
    return Double(total - available) / Double(total)
  }

  private var capacity: Text {
    guard let total = volume.totalCapacity, let available = volume.availableCapacity else {
      return Text(verbatim: volume.name)
    }
    return Text("\(formatter.string(for: available)) of \(formatter.string(for: total)) available")
  }
}

/// A tag with its color; items dropped on it get the tag.
private struct TagRow: View {

  let name: String
  let addTag: ([URL]) -> Void

  @State private var isTargeted = false

  var body: some View {
    Label {
      Text(verbatim: name)
    } icon: {
      Circle()
        .fill(TagColors.color(for: name))
        .frame(width: 10, height: 10)
        .accessibilityHidden(true)
    }
    .dropDestination(for: URL.self) { urls, _ in
      addTag(urls)
      return true
    } isTargeted: { isTargeted in
      self.isTargeted = isTargeted
    }
    .background {
      if isTargeted {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.accentColor.opacity(0.2))
      }
    }
  }
}

#Preview("English") {
  SidebarView(
    window: .preview(in: .english),
    favorites: FavoritesStore(previewFavorites: FavoritesStore.standardFolders),
    sources: SidebarSources(previewVolumes: PreviewFixtures.volumes, tags: PreviewFixtures.tagNames(in: .english)))
    .frame(width: 220, height: 480)
}

#Preview("German") {
  SidebarView(
    window: .preview(in: .german),
    favorites: FavoritesStore(previewFavorites: FavoritesStore.standardFolders),
    sources: SidebarSources(previewVolumes: PreviewFixtures.volumes, tags: PreviewFixtures.tagNames(in: .german)))
    .frame(width: 220, height: 480)
    .environment(\.locale, Locale(identifier: "de"))
}

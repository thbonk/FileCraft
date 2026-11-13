/*
 * AppDelegate.swift
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

import AppKit

/// The application delegate, for what SwiftUI has no API for (design decision D9): the confirmation before quitting
/// while file operations run, and the Dock menu. The confirmation itself is a SwiftUI alert in the Operations window.
internal final class AppDelegate: NSObject, NSApplicationDelegate {

  // MARK: - Properties

  /// The number of recent folders the Dock menu lists.
  internal static let dockFolderLimit = 5

  /// Opens a browser window; browser windows set it when they appear, because only SwiftUI can open them.
  internal static var openBrowserWindow: (() -> Void)?

  /// The recent folders, most recent first; tests replace it.
  internal var recentFolders: () -> [FileReference] = { RecentsStore.shared.folders }

  // MARK: - Launching

  /// A process that hands over to an earlier FileCraft receives the requests that launched it.
  internal func applicationWillFinishLaunching(_ notification: Notification) {
    InstanceHandover.receiveRequests()
  }

  internal func applicationDidFinishLaunching(_ notification: Notification) {
    InstanceHandover.finish()
  }

  // MARK: - Dock Menu

  /// New Window and the most recent folders.
  internal func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let menu = NSMenu()
    let newWindow = NSMenuItem(title: String(localized: "New Window"), action: #selector(openNewWindow(_:)), keyEquivalent: "")
    newWindow.target = self
    menu.addItem(newWindow)
    let folders = Array(recentFolders().prefix(Self.dockFolderLimit))
    if folders.isEmpty == false {
      menu.addItem(.separator())
    }
    for folder in folders {
      let item = NSMenuItem(
        title: FileManager.default.displayName(atPath: folder.lastKnownPath), action: #selector(openRecentFolder(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = folder.lastKnownPath
      let icon = NSWorkspace.shared.icon(forFile: folder.lastKnownPath)
      icon.size = NSSize(width: 16, height: 16)
      item.image = icon
      menu.addItem(item)
    }
    return menu
  }

  @objc private func openNewWindow(_ sender: NSMenuItem) {
    NSApp.activate()
    Self.openBrowserWindow?()
  }

  /// Opens the folder in a new tab of the frontmost browser window, or in a new window when none is open.
  @objc private func openRecentFolder(_ sender: NSMenuItem) {
    guard let path = sender.representedObject as? String, let folder = recentFolders().first(where: { $0.lastKnownPath == path })
    else {
      return
    }
    NSApp.activate()
    let location = Location.folder(folder)
    if let window = BrowserWindowModel.mostRecentlyActive {
      window.show(location, inNewTab: true)
    } else {
      NewWindowQueue.push(location)
      Self.openBrowserWindow?()
    }
  }

  // MARK: - Quitting

  /// Defers quitting while operations run or are paused, until the user decided in the Operations window.
  internal func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    let operations = OperationQueueModel.shared
    guard operations.isBusy else {
      return .terminateNow
    }
    operations.confirmQuit { shouldQuit in
      sender.reply(toApplicationShouldTerminate: shouldQuit)
    }
    return .terminateLater
  }

  /// An authorization for the privileged helper never outlives FileCraft.
  internal func applicationWillTerminate(_ notification: Notification) {
    // A process that handed over never started anything; Finder belongs to the earlier FileCraft.
    guard InstanceHandover.isActive == false else {
      return
    }
    HelperAuthorization.shared.reset()
    FinderReplacement().applyAtQuit(quitsFinder: SettingsStore().value(for: SettingsKeys.quitsFinderOnLaunch))
  }
}

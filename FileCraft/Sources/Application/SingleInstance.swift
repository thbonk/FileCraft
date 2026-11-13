/*
 * SingleInstance.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-13.
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
import OSLog

/// Keeps FileCraft to one process.
///
/// For requests that only name FileCraft's bundle identifier, such as "Show in Finder" in other applications while
/// FileCraft is the file viewer, Launch Services starts its preferred copy of FileCraft even while another copy runs
/// from a different place: a build from Xcode, a downloaded release, a copy in /Applications. The process that started
/// later hands its requests to the earlier one and quits.
nonisolated internal enum SingleInstance {

  /// 'GURL', the event class and identifier of a URL request (Carbon's `kInternetEventClass` and `kAEGetURL`, which
  /// Swift does not see through AppKit).
  internal static let getURLEvent: OSType = 0x4755_524C

  /// A running FileCraft process.
  internal struct Process: Equatable {
    internal let processIdentifier: pid_t
    /// When Launch Services launched the process, if it did.
    internal let launchDate: Date?
  }

  /// The process that keeps running instead of `current`: the earliest of the other processes that started before
  /// `current`, or nil when `current` started first. Processes started at the same moment, or without a launch date,
  /// yield to the lower process identifier, so that two copies started together never both quit.
  internal static func primary(among processes: [Process], current: Process) -> Process? {
    processes
      .filter { $0.processIdentifier != current.processIdentifier && startedBefore($0, current) }
      .min { startedBefore($0, $1) }
  }

  /// Whether this process hands over to an earlier one. The test host must keep running while the user's FileCraft
  /// runs, and so must a process under a debugger, which a developer started on purpose, for example from Xcode.
  internal static func handsOver(hasPrimary: Bool, isTestHost: Bool, isBeingDebugged: Bool) -> Bool {
    hasPrimary && isTestHost == false && isBeingDebugged == false
  }

  /// The files and URLs of an open, reveal or URL request: the direct object, a file reference, a list of them or a
  /// URL string.
  internal static func urls(in event: NSAppleEventDescriptor) -> [URL] {
    guard let object = event.paramDescriptor(forKeyword: keyDirectObject) else {
      return []
    }
    let items: [NSAppleEventDescriptor]
    if object.descriptorType == typeAEList {
      items = object.numberOfItems > 0 ? (1...object.numberOfItems).compactMap { object.atIndex($0) } : []
    } else {
      items = [object]
    }
    return items.compactMap { item in
      // Text would also coerce to a file URL, read as an HFS path, so it is taken as a URL string instead.
      if [typeUTF8Text, typeUnicodeText, typeChar].contains(item.descriptorType) {
        return item.stringValue.flatMap(URL.init(string:)).flatMap { $0.scheme == nil ? nil : $0 }
      }
      return item.coerce(toDescriptorType: typeFileURL)?.fileURLValue
    }
  }

  private static func startedBefore(_ first: Process, _ second: Process) -> Bool {
    if let firstDate = first.launchDate, let secondDate = second.launchDate, firstDate != secondDate {
      return firstDate < secondDate
    }
    return first.processIdentifier < second.processIdentifier
  }
}

/// The handover of a FileCraft process that started after another one: it shows no Dock icon and no windows, starts
/// none of FileCraft's services, leaves the saved windows alone, passes the requests it receives to the earlier
/// process and quits.
internal enum InstanceHandover {

  // MARK: - Properties

  /// The earlier process this one hands over to, once `beginIfNeeded()` found one.
  internal private(set) static var primary: NSRunningApplication?

  internal static var isActive: Bool {
    primary != nil
  }

  private static var requests: [URL] = []
  private static let receiver = RequestReceiver()
  private static let logger = Logger(subsystem: "de.meandmymac.FileCraft", category: "SingleInstance")
  /// How long the process waits for the requests that launched it before it passes them on.
  private static let requestWait: Duration = .milliseconds(500)

  // MARK: - Handing Over

  /// Starts the handover when another FileCraft started earlier. Call it first at launch, before any service starts.
  internal static func beginIfNeeded() {
    let current = NSRunningApplication.current
    let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
      .filter { $0.isTerminated == false }
    let processes = others.map { SingleInstance.Process(processIdentifier: $0.processIdentifier, launchDate: $0.launchDate) }
    let found = SingleInstance.primary(
      among: processes,
      current: SingleInstance.Process(processIdentifier: current.processIdentifier, launchDate: current.launchDate))
    let primary = found.flatMap { found in others.first { $0.processIdentifier == found.processIdentifier } }
    guard
      SingleInstance.handsOver(
        hasPrimary: primary != nil, isTestHost: AppEnvironment.isTestHost, isBeingDebugged: AppEnvironment.isBeingDebugged)
    else {
      return
    }
    Self.primary = primary
    // Notice level, so that the system log keeps it for later diagnosis.
    logger.notice("FileCraft runs already as process \(primary?.processIdentifier ?? 0); this process hands over and quits")
    // No Dock icon, and no restoring or saving of window state, which belongs to the earlier process.
    NSApplication.shared.setActivationPolicy(.prohibited)
    let defaults = UserDefaults.standard
    var arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
    arguments["ApplePersistenceIgnoreState"] = true
    defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
  }

  /// Receives the open, reveal and URL requests that launched the process. Call it before launching finishes.
  internal static func receiveRequests() {
    guard isActive else {
      return
    }
    let manager = NSAppleEventManager.shared()
    let selector = #selector(RequestReceiver.handle(_:withReplyEvent:))
    let requests: [(AEEventClass, AEEventID)] = [
      (AEEventClass(kCoreEventClass), AEEventID(kAEOpenDocuments)),
      (AEEventClass(kAEMiscStandards), AEEventID(kAEMakeObjectsVisible)),
      (SingleInstance.getURLEvent, SingleInstance.getURLEvent),
    ]
    for (eventClass, eventID) in requests {
      manager.setEventHandler(receiver, andSelector: selector, forEventClass: eventClass, andEventID: eventID)
    }
  }

  /// Passes the received requests to the earlier process, or only activates it, and quits.
  internal static func finish() {
    guard let primary else {
      return
    }
    Task {
      try? await Task.sleep(for: requestWait)
      if requests.isEmpty == false, let application = primary.bundleURL {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try? await NSWorkspace.shared.open(requests, withApplicationAt: application, configuration: configuration)
      } else {
        primary.activate()
      }
      NSApplication.shared.terminate(nil)
    }
  }

  fileprivate static func receive(_ event: NSAppleEventDescriptor) {
    requests.append(contentsOf: SingleInstance.urls(in: event))
  }
}

/// The Apple Event handler of the handover, which `NSAppleEventManager` needs as an Objective-C object.
private final class RequestReceiver: NSObject {

  @objc func handle(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
    InstanceHandover.receive(event)
  }
}

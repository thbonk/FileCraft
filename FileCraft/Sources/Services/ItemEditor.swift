/*
 * ItemEditor.swift
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
import Foundation
import UniformTypeIdentifiers

/// An attribute the inspector turns on and off.
nonisolated internal enum ItemAttribute: String, CaseIterable, Hashable, Sendable {
  /// The user immutable flag.
  case locked
  case hidden
  case hiddenExtension
}

/// Changes items for the inspector, off the caller's actor. Permission changes that need administrator rights fail
/// here; task 10.9 routes them through the privileged helper.
nonisolated internal enum ItemEditor {

  // MARK: - Tags and Attributes

  @concurrent
  internal static func setTags(_ tags: [String], of url: URL) async throws {
    var url = url
    var values = URLResourceValues()
    values.tagNames = tags
    try url.setResourceValues(values)
  }

  @concurrent
  internal static func set(_ attribute: ItemAttribute, to isOn: Bool, of url: URL) async throws {
    var url = url
    var values = URLResourceValues()
    switch attribute {
    case .locked:
      values.isUserImmutable = isOn
    case .hidden:
      values.isHidden = isOn
    case .hiddenExtension:
      values.hasHiddenExtension = isOn
    }
    try url.setResourceValues(values)
  }

  /// The Locked attribute of each of `urls`.
  @concurrent
  internal static func lockedStates(of urls: [URL]) async -> [URL: Bool] {
    let states = urls.map { url in
      (url, (try? url.resourceValues(forKeys: [.isUserImmutableKey]).isUserImmutable) ?? false)
    }
    return Dictionary(states) { first, _ in first }
  }

  // MARK: - Permissions

  @concurrent
  internal static func setMode(_ mode: UInt16, of url: URL) async throws {
    try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: mode)], ofItemAtPath: url.path(percentEncoded: false))
  }

  /// The mode changes that apply the permissions `folderMode` of `folder` to every item inside it, like
  /// `chmod -R u=rwX,g=rX,o=rX`: read and write come from the folder, execute only for folders and for files that
  /// are executable already. Each item keeps its setuid, setgid and sticky bits.
  @concurrent
  internal static func enclosedModeChanges(in folder: URL, applying folderMode: UInt16) async -> [InspectorEdit] {
    enclosedModeChangesSynchronously(in: folder, applying: folderMode)
  }

  /// Directory enumerators cannot be iterated in async code, so the walk is synchronous.
  private static func enclosedModeChangesSynchronously(in folder: URL, applying folderMode: UInt16) -> [InspectorEdit] {
    let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
    guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys, options: []) else {
      return []
    }
    var edits: [InspectorEdit] = []
    for case let url as URL in enumerator {
      guard
        let values = try? url.resourceValues(forKeys: Set(keys)),
        values.isSymbolicLink != true,
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)),
        let current = (attributes[.posixPermissions] as? NSNumber)?.uint16Value
      else {
        continue
      }
      let mode = enclosedMode(current: current, isDirectory: values.isDirectory == true, folderMode: folderMode)
      if mode != current {
        edits.append(.mode(url, from: current, to: mode))
      }
    }
    return edits
  }

  /// The mode of an enclosed item after Apply to Enclosed Items; see `enclosedModeChanges(in:applying:)`.
  internal static func enclosedMode(current: UInt16, isDirectory: Bool, folderMode: UInt16) -> UInt16 {
    let readWrite = folderMode & 0o666
    let isExecutable = isDirectory || current & 0o111 != 0
    let execute = isExecutable ? folderMode & 0o111 : 0
    return readWrite | execute | current & 0o7000
  }

  // MARK: - Open With

  /// The application that opens `url`, and the default application of its type.
  @concurrent
  internal static func applications(for url: URL, type: UTType?) async -> (current: URL?, typeDefault: URL?) {
    let workspace = NSWorkspace.shared
    return (workspace.urlForApplication(toOpen: url), type.flatMap(workspace.urlForApplication(toOpen:)))
  }

  /// Makes `application` open the item at `url`.
  @concurrent
  internal static func setApplication(_ application: URL, forItemAt url: URL) async throws {
    try await NSWorkspace.shared.setDefaultApplication(at: application, toOpenFileAt: url)
  }

  /// Makes `application` the default for all items of `type`, as Change All does.
  @concurrent
  internal static func setApplication(_ application: URL, forType type: UTType) async throws {
    try await NSWorkspace.shared.setDefaultApplication(at: application, toOpen: type)
  }
}

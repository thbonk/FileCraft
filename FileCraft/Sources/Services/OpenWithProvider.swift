/*
 * OpenWithProvider.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-10-31.
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

/// An application offered in File > Open With.
nonisolated internal struct ApplicationChoice: Identifiable, Hashable, Sendable {
  internal let url: URL
  internal let name: String
  /// Whether this is the default application of the first item.
  internal let isDefault: Bool

  internal var id: URL {
    url
  }
}

/// Finds the applications that can open items, through Launch Services (`NSWorkspace`, design decision D9).
nonisolated internal enum OpenWithProvider {

  /// The number of items whose applications are compared; larger selections use their first items.
  internal static let itemLimit = 20

  /// The applications that can open every one of `urls`: the default application of the first item first, then
  /// the others by name. An application installed twice is listed once.
  internal static func applications(toOpen urls: [URL]) -> [ApplicationChoice] {
    let items = urls.prefix(itemLimit)
    guard let first = items.first else {
      return []
    }
    let workspace = NSWorkspace.shared
    var candidates = workspace.urlsForApplications(toOpen: first).map(\.standardizedFileURL)
    for url in items.dropFirst() {
      let supported = Set(workspace.urlsForApplications(toOpen: url).map(\.standardizedFileURL))
      candidates = candidates.filter(supported.contains)
    }
    let defaultApplication = workspace.urlForApplication(toOpen: first)?.standardizedFileURL
    var seenIdentifiers = Set<String>()
    let choices = candidates.compactMap { url -> ApplicationChoice? in
      let identifier = Bundle(url: url)?.bundleIdentifier ?? url.path(percentEncoded: false)
      guard seenIdentifiers.insert(identifier).inserted else {
        return nil
      }
      let name = FileManager.default.displayName(atPath: url.path(percentEncoded: false))
      return ApplicationChoice(url: url, name: (name as NSString).deletingPathExtension, isDefault: url == defaultApplication)
    }
    let named = disambiguatingNames(choices) { url in
      Bundle(url: url)?.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    return named.sorted { lhs, rhs in
      if lhs.isDefault != rhs.isDefault {
        return lhs.isDefault
      }
      return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
  }

  /// Tells apart applications that show the same name, as Finder does: by their version, "Pages (14.4)", or, when
  /// the versions do not differ, by the file name of those whose file name is not the shared name.
  ///
  /// - Parameter version: The version of the application at a URL, if it has one.
  internal static func disambiguatingNames(_ choices: [ApplicationChoice], version: (URL) -> String?) -> [ApplicationChoice] {
    let sharedNames = Set(Dictionary(grouping: choices, by: \.name).filter { $0.value.count > 1 }.keys)
    guard sharedNames.isEmpty == false else {
      return choices
    }
    let versions = Dictionary(uniqueKeysWithValues: choices.filter { sharedNames.contains($0.name) }.map { ($0.url, version($0.url)) })
    return choices.map { choice in
      guard sharedNames.contains(choice.name) else {
        return choice
      }
      let namesakes = choices.filter { $0.name == choice.name }
      let namesakeVersions = namesakes.compactMap { versions[$0.url] ?? nil }
      if namesakeVersions.count == namesakes.count, Set(namesakeVersions).count == namesakes.count,
        let ownVersion = versions[choice.url] ?? nil
      {
        return ApplicationChoice(url: choice.url, name: "\(choice.name) (\(ownVersion))", isDefault: choice.isDefault)
      }
      let fileName = choice.url.deletingPathExtension().lastPathComponent
      guard fileName != choice.name else {
        return choice
      }
      return ApplicationChoice(url: choice.url, name: "\(choice.name) (\(fileName))", isDefault: choice.isDefault)
    }
  }

  /// Looks the applications up off the caller's actor, for menus that are built ahead of time.
  @concurrent
  internal static func loadApplications(toOpen urls: [URL]) async -> [ApplicationChoice] {
    applications(toOpen: urls)
  }
}

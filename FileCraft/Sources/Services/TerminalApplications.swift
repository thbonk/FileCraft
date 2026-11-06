/*
 * TerminalApplications.swift
 * FileCraft
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

import AppKit

/// An application that Open in Terminal can use.
internal struct TerminalApplication: Identifiable, Hashable {
  internal let bundleIdentifier: String
  internal let name: String

  internal var id: String {
    bundleIdentifier
  }
}

/// Finds the terminal applications installed on this Mac.
internal enum TerminalApplications {

  /// The terminals FileCraft knows, Terminal first.
  internal static let knownBundleIdentifiers = [
    "com.apple.Terminal",
    "com.googlecode.iterm2",
    "dev.warp.Warp-Stable",
    "com.mitchellh.ghostty",
    "net.kovidgoyal.kitty",
    "com.github.wez.wezterm",
    "org.alacritty",
  ]

  /// The installed known terminals, followed by `selected` when it is another application.
  internal static func installed(including selected: String, workspace: NSWorkspace = .shared) -> [TerminalApplication] {
    var identifiers = knownBundleIdentifiers
    if identifiers.contains(selected) == false {
      identifiers.append(selected)
    }
    return identifiers.compactMap { identifier in
      guard let url = workspace.urlForApplication(withBundleIdentifier: identifier) else {
        return nil
      }
      return TerminalApplication(bundleIdentifier: identifier, name: displayName(of: url))
    }
  }

  /// The name of the application at `url` without its extension.
  internal static func displayName(of url: URL) -> String {
    (FileManager.default.displayName(atPath: url.path(percentEncoded: false)) as NSString).deletingPathExtension
  }
}

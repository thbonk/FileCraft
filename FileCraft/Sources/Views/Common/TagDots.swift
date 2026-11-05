/*
 * TagDots.swift
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

/// Up to three overlapping dots in the colors of an item's tags. The tag names appear as help tag and
/// accessibility label, so the information does not depend on color alone.
internal struct TagDots: View {

  // MARK: - Properties

  internal let tagNames: [String]

  // MARK: - Body

  internal var body: some View {
    let names = tagNames.formatted(.list(type: .and))
    HStack(spacing: -3) {
      ForEach(tagNames.prefix(3), id: \.self) { name in
        Circle()
          .fill(TagColors.color(for: name))
          .frame(width: 9, height: 9)
          .overlay {
            Circle().strokeBorder(.background, lineWidth: 1)
          }
      }
    }
    .help(Text(names))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(names))
  }
}

/// The colors of Finder tags.
internal enum TagColors {

  /// The color of a standard Finder tag such as "Red", or gray for other tags.
  internal static func color(for name: String) -> Color {
    let workspace = NSWorkspace.shared
    guard
      let index = workspace.fileLabels.firstIndex(of: name),
      index > 0,
      workspace.fileLabelColors.indices.contains(index)
    else {
      return .gray
    }
    return Color(nsColor: workspace.fileLabelColors[index])
  }
}

#Preview {
  TagDots(tagNames: NSWorkspace.shared.fileLabels.dropFirst().prefix(3).map(\.self))
    .padding()
}

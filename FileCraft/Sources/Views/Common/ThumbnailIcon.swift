/*
 * ThumbnailIcon.swift
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

import SwiftUI

/// An item's icon that a Quick Look thumbnail replaces once it is ready.
internal struct ThumbnailIcon: View {

  // MARK: - Properties

  internal let item: FileItem
  internal let size: CGFloat
  internal let showsPreview: Bool

  @Environment(\.displayScale) private var displayScale
  @State private var thumbnail: CGImage?

  // MARK: - Body

  internal var body: some View {
    Group {
      if let thumbnail {
        Image(decorative: thumbnail, scale: displayScale)
          .resizable()
          .interpolation(.high)
          .aspectRatio(contentMode: .fit)
      } else {
        FileIcon(url: item.url, size: size)
      }
    }
    .frame(width: size, height: size)
    .overlay(alignment: .bottomLeading) {
      if item.isAliasFile || item.isSymbolicLink {
        LinkBadge(size: max(8, size / 6))
      }
    }
    .task(id: ThumbnailKey(id: item.id, size: size, showsPreview: showsPreview, modificationDate: item.modificationDate)) {
      guard showsPreview, item.isDirectory == false else {
        thumbnail = nil
        return
      }
      thumbnail = await ThumbnailService.shared.thumbnail(
        for: item.url,
        size: CGSize(width: size, height: size),
        scale: displayScale,
        modificationDate: item.modificationDate)
    }
  }
}

/// Identifies one thumbnail request; a change restarts it.
nonisolated private struct ThumbnailKey: Hashable {
  let id: String
  let size: CGFloat
  let showsPreview: Bool
  let modificationDate: Date?
}

#Preview {
  HStack(spacing: 16) {
    ForEach(PreviewFixtures.items(in: .english).prefix(4)) { item in
      ThumbnailIcon(item: item, size: 64, showsPreview: false)
    }
  }
  .padding()
}

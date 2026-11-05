/*
 * FileIcon.swift
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

/// The icon macOS shows for a file, folder or volume.
internal struct FileIcon: View {

  // MARK: - Properties

  internal let url: URL
  internal var size: CGFloat = 16

  // MARK: - Body

  internal var body: some View {
    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
      .resizable()
      .interpolation(.high)
      .frame(width: size, height: size)
      .accessibilityHidden(true)
  }
}

#Preview {
  HStack(spacing: 16) {
    FileIcon(url: URL(filePath: "/Applications", directoryHint: .isDirectory), size: 32)
    FileIcon(url: PreviewFixtures.homeFolder.appending(path: "Report.pdf"), size: 32)
  }
  .padding()
}

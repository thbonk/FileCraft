/*
 * QuickLookPreview.swift
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

import QuickLookUI
import SwiftUI

/// An inline Quick Look preview, used by the preview column and the inspector.
///
/// SwiftUI only offers the Quick Look panel, so this wraps `QLPreviewView` (AppKit interop approved in
/// design decision D9).
internal struct QuickLookPreview: NSViewRepresentable {

  // MARK: - Properties

  internal let url: URL

  // MARK: - NSViewRepresentable

  internal func makeNSView(context: Context) -> QLPreviewView {
    guard let view = QLPreviewView(frame: .zero, style: .normal) else {
      return QLPreviewView()
    }
    view.autostarts = true
    // `dismantleNSView` closes the view. With `shouldCloseWithWindow`, the view would also close itself when
    // SwiftUI removes it from the window first, and Quick Look aborts on the second close.
    view.shouldCloseWithWindow = false
    view.previewItem = url as NSURL
    return view
  }

  internal func updateNSView(_ view: QLPreviewView, context: Context) {
    if (view.previewItem as? NSURL) as URL? != url {
      view.previewItem = url as NSURL
    }
  }

  internal static func dismantleNSView(_ view: QLPreviewView, coordinator: ()) {
    view.close()
  }
}

#Preview {
  QuickLookPreview(url: URL(filePath: "/System/Library/CoreServices/Finder.app"))
    .frame(width: 300, height: 220)
}

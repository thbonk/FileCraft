/*
 * ContentAreaView.swift
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

import SwiftUI

/// The detail area of a browser window: one or two panes and, below them, the shelf.
internal struct ContentAreaView: View {

  // MARK: - Properties

  @Bindable internal var window: BrowserWindowModel
  internal var shelf: ShelfStore = .shared

  // MARK: - Body

  internal var body: some View {
    VStack(spacing: 0) {
      panes
      if window.layout.isShelfVisible {
        SplitDivider(axis: .vertical) { delta in
          let range = WindowLayout.shelfHeightRange
          window.layout.shelfHeight = min(max(window.layout.shelfHeight - delta, range.lowerBound), range.upperBound)
        }
        ShelfView(shelf: shelf, window: window)
          .frame(height: window.layout.shelfHeight)
      }
    }
  }

  // MARK: - Private

  @ViewBuilder
  private var panes: some View {
    if window.isDualPaneVisible, let secondaryPane = window.secondaryPane {
      PaneSplitView(
        axis: window.layout.paneLayout == .sideBySide ? .horizontal : .vertical,
        fraction: $window.layout.paneSplitFraction,
        fractionRange: WindowLayout.paneSplitFractionRange
      ) {
        paneView(window.primaryPane)
      } second: {
        paneView(secondaryPane)
      }
    } else {
      paneView(window.primaryPane)
    }
  }

  private func paneView(_ pane: PaneModel) -> some View {
    PaneView(pane: pane, window: window)
  }
}

#Preview {
  let window = BrowserWindowModel.preview(in: .english)
  window.layout.isShelfVisible = true

  return ContentAreaView(
    window: window,
    shelf: ShelfStore(previewItems: [PreviewFixtures.homeFolder.appending(path: "Report.pdf")]))
    .frame(width: 700, height: 480)
}

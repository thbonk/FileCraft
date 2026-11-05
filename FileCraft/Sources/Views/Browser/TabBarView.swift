/*
 * TabBarView.swift
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

import SwiftUI

/// The tabs of one pane. Tabs share the width and scroll when there are many; dragging reorders them, and
/// dropping a tab on the other pane's bar moves it there with its history.
internal struct TabBarView: View {

  // MARK: - Properties

  internal let pane: PaneModel
  internal let window: BrowserWindowModel

  private static let minimumTabWidth: CGFloat = 120

  // MARK: - Body

  internal var body: some View {
    HStack(spacing: 0) {
      ScrollView(.horizontal) {
        HStack(spacing: 0) {
          ForEach(pane.tabs) { tab in
            tabItem(for: tab)
          }
        }
      }
      .scrollIndicators(.never)
      .dropDestination(for: TabDragItem.self) { items, _ in
        return moveTab(items, before: nil)
      }
      Divider()
      newTabButton
    }
    .frame(height: 28)
    .background(.bar)
  }

  // MARK: - Private

  private func tabItem(for tab: TabModel) -> some View {
    let tabCount = pane.tabs.count
    let canMoveToOtherPane = window.otherPane(of: pane) != nil && (tabCount > 1 || pane === window.secondaryPane)
    return TabItemView(
      tab: tab,
      isCurrent: tab === pane.currentTab,
      canCloseOthers: tabCount > 1,
      canMoveToOtherPane: canMoveToOtherPane
    ) { action in
      perform(action, on: tab)
    }
    .containerRelativeFrame(.horizontal) { length, _ in
      max(length / CGFloat(max(tabCount, 1)), Self.minimumTabWidth)
    }
    .draggable(TabDragItem(tabID: tab.id)) {
      Label(tab.title, systemImage: tab.location.systemImage)
        .padding(6)
    }
    .dropDestination(for: TabDragItem.self) { items, _ in
      return moveTab(items, before: tab)
    }
  }

  private var newTabButton: some View {
    Button {
      window.newTab(in: pane)
    } label: {
      Image(systemName: "plus")
        .frame(width: 28, height: 26)
        .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .help(Text("New Tab"))
    .accessibilityLabel(Text("New Tab"))
  }

  private func perform(_ action: TabItemView.Action, on tab: TabModel) {
    switch action {
    case .select:
      pane.select(tab)
      window.activate(pane)
    case .close:
      window.closeTab(tab)
    case .closeOthers:
      window.closeOtherTabs(than: tab)
    case .moveToOtherPane:
      if let otherPane = window.otherPane(of: pane) {
        window.moveTab(withID: tab.id, to: otherPane, before: nil)
      }
    }
  }

  private func moveTab(_ items: [TabDragItem], before target: TabModel?) -> Bool {
    guard let item = items.first else {
      return false
    }
    window.moveTab(withID: item.tabID, to: pane, before: target)
    return true
  }
}

/// One tab: close button on hover, icon and name, the full path as help tag.
private struct TabItemView: View {

  enum Action {
    case select
    case close
    case closeOthers
    case moveToOtherPane
  }

  let tab: TabModel
  let isCurrent: Bool
  let canCloseOthers: Bool
  let canMoveToOtherPane: Bool
  let perform: (Action) -> Void

  @State private var isHovered = false

  var body: some View {
    HStack(spacing: 4) {
      Button {
        perform(.close)
      } label: {
        Image(systemName: "xmark")
          .font(.caption2.weight(.semibold))
          .frame(width: 16, height: 16)
          .contentShape(Rectangle())
      }
      .buttonStyle(.borderless)
      // Hidden by opacity, so that the name does not shift when the pointer enters the tab.
      .opacity(isHovered ? 1 : 0)
      .help(Text("Close Tab"))
      .accessibilityLabel(Text("Close Tab"))
      Group {
        if let folderURL = tab.folderURL {
          FileIcon(url: folderURL)
        } else {
          Image(systemName: tab.location.systemImage)
        }
      }
      .accessibilityHidden(true)
      Text(verbatim: tab.title)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: 16)
    }
    .padding(.horizontal, 6)
    .frame(maxHeight: .infinity)
    .background(isCurrent ? AnyShapeStyle(.background) : AnyShapeStyle(Color.clear))
    .overlay(alignment: .trailing) {
      Divider()
    }
    .contentShape(Rectangle())
    .onHover { isHovered = $0 }
    .onTapGesture {
      perform(.select)
    }
    .help(Text(verbatim: tab.folderURL?.path(percentEncoded: false) ?? tab.title))
    .accessibilityAddTraits(isCurrent ? [.isSelected, .isButton] : .isButton)
    .contextMenu {
      Button("Close Tab") {
        perform(.close)
      }
      Button("Close Other Tabs") {
        perform(.closeOthers)
      }
      .disabled(canCloseOthers == false)
      Button("Move to Other Pane") {
        perform(.moveToOtherPane)
      }
      .disabled(canMoveToOtherPane == false)
    }
  }
}

#Preview("English") {
  let window = BrowserWindowModel.preview(in: .english)
  window.newTab(location: .currentLocation)

  return TabBarView(pane: window.primaryPane, window: window)
    .frame(width: 520)
}

#Preview("German") {
  let window = BrowserWindowModel.preview(in: .german)
  window.newTab(location: .currentLocation)

  return TabBarView(pane: window.primaryPane, window: window)
    .frame(width: 520)
    .environment(\.locale, Locale(identifier: "de"))
}

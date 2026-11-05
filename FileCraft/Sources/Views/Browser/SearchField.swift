/*
 * SearchField.swift
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
import SwiftUI

/// The toolbar search field of a browser window, acting on the active tab.
///
/// It wraps `NSSearchField`, because SwiftUI's searchable field has no menu: the field's magnifying glass menu offers
/// the search scopes and the recent searches with their scope and criteria.
internal struct SearchToolbarField: View {

  // MARK: - Properties

  internal let window: BrowserWindowModel

  // MARK: - Body

  internal var body: some View {
    let tab = window.activeTab
    SearchField(
      text: tab.searchFieldText,
      scope: tab.searchParameters.scope,
      canSearchSubfolders: tab.canSearchSubfolders,
      recentSearches: window.recents?.searches ?? [],
      focusRequest: window.searchFocusRequest,
      actions: SearchField.Actions(
        changeText: { tab.setSearchText($0) },
        commit: { tab.commitSearch() },
        changeScope: { tab.setSearchScope($0) },
        repeatSearch: { tab.repeatSearch($0) },
        clearRecentSearches: { window.recents?.clearSearches() })
    )
    .frame(minWidth: 140, idealWidth: 220, maxWidth: 280)
  }
}

/// An `NSSearchField` showing `text`, with a menu of scopes and recent searches.
internal struct SearchField: NSViewRepresentable {

  // MARK: - Types

  /// What the field reports back.
  internal struct Actions {
    let changeText: (String) -> Void
    let commit: () -> Void
    let changeScope: (SearchScope) -> Void
    let repeatSearch: (SearchParameters) -> Void
    let clearRecentSearches: () -> Void
  }

  // MARK: - Properties

  internal let text: String
  internal let scope: SearchScope
  internal let canSearchSubfolders: Bool
  internal let recentSearches: [SearchParameters]
  /// The field takes keyboard focus whenever this value changes.
  internal let focusRequest: Int
  internal let actions: Actions

  // MARK: - NSViewRepresentable

  internal func makeCoordinator() -> Coordinator {
    Coordinator(field: self)
  }

  internal func makeNSView(context: Context) -> NSSearchField {
    let field = NSSearchField()
    field.delegate = context.coordinator
    field.target = context.coordinator
    field.action = #selector(Coordinator.searchStringDidChange(_:))
    field.sendsSearchStringImmediately = true
    field.sendsWholeSearchString = false
    field.maximumRecents = 0
    field.controlSize = .regular
    context.coordinator.lastFocusRequest = focusRequest
    return field
  }

  internal func updateNSView(_ field: NSSearchField, context: Context) {
    let coordinator = context.coordinator
    coordinator.field = self
    if field.stringValue != text {
      field.stringValue = text
    }
    field.placeholderString = String(localized: Self.placeholder(for: scope))
    let menuState = MenuState(scope: scope, canSearchSubfolders: canSearchSubfolders, recentSearches: recentSearches)
    if coordinator.menuState != menuState {
      coordinator.menuState = menuState
      field.searchMenuTemplate = coordinator.makeMenu(for: menuState)
    }
    if coordinator.lastFocusRequest != focusRequest {
      coordinator.lastFocusRequest = focusRequest
      field.window?.makeFirstResponder(field)
    }
  }

  // MARK: - Private

  private static func placeholder(for scope: SearchScope) -> LocalizedStringResource {
    switch scope {
    case .thisFolder:
      "Filter This Folder"
    case .subfolders:
      "Search Subfolders"
    case .thisMac:
      "Search This Mac"
    }
  }

  /// What the menu shows; the menu is rebuilt only when it changes.
  fileprivate struct MenuState: Equatable {
    let scope: SearchScope
    let canSearchSubfolders: Bool
    let recentSearches: [SearchParameters]
  }

  // MARK: - Coordinator

  internal final class Coordinator: NSObject, NSSearchFieldDelegate {

    var field: SearchField
    var lastFocusRequest = 0
    fileprivate var menuState: MenuState?

    init(field: SearchField) {
      self.field = field
    }

    @objc func searchStringDidChange(_ sender: NSSearchField) {
      field.actions.changeText(sender.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
      if commandSelector == #selector(NSResponder.insertNewline(_:)) {
        field.actions.commit()
      }
      return false
    }

    @objc func chooseScope(_ sender: NSMenuItem) {
      guard let scope = sender.representedObject as? String, let searchScope = SearchScope(rawValue: scope) else {
        return
      }
      field.actions.changeScope(searchScope)
    }

    @objc func repeatSearch(_ sender: NSMenuItem) {
      guard let state = menuState, state.recentSearches.indices.contains(sender.tag) else {
        return
      }
      field.actions.repeatSearch(state.recentSearches[sender.tag])
    }

    @objc func clearRecentSearches(_ sender: NSMenuItem) {
      field.actions.clearRecentSearches()
    }

    fileprivate func makeMenu(for state: MenuState) -> NSMenu {
      let menu = NSMenu()
      menu.autoenablesItems = false
      menu.addItem(.sectionHeader(title: String(localized: "Search In")))
      for scope in SearchScope.allCases {
        let item = NSMenuItem(title: String(localized: scope.title), action: #selector(chooseScope(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = scope.rawValue
        item.state = scope == state.scope ? .on : .off
        item.isEnabled = scope != .subfolders || state.canSearchSubfolders
        menu.addItem(item)
      }
      menu.addItem(.separator())
      menu.addItem(.sectionHeader(title: String(localized: "Recent Searches")))
      if state.recentSearches.isEmpty {
        let item = NSMenuItem(title: String(localized: "No Recent Searches"), action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
      } else {
        for (index, search) in state.recentSearches.enumerated() {
          let item = NSMenuItem(title: Self.title(of: search), action: #selector(repeatSearch(_:)), keyEquivalent: "")
          item.target = self
          item.tag = index
          item.isEnabled = search.scope != .subfolders || state.canSearchSubfolders
          menu.addItem(item)
        }
        menu.addItem(.separator())
        let clear = NSMenuItem(
          title: String(localized: "Clear Recent Searches"), action: #selector(clearRecentSearches(_:)), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
      }
      return menu
    }

    /// For example "“README” in Subfolders +2", where the number counts the criteria.
    private static func title(of search: SearchParameters) -> String {
      let scope = String(localized: search.scope.title)
      var title =
        search.text.isEmpty
        ? scope
        : String(localized: "“\(search.text)” in \(scope)", comment: "A recent search: search text and scope")
      let criteria = search.effectiveCriteria.count
      if criteria > 0 {
        title += " +\(criteria)"
      }
      return title
    }
  }
}

#Preview {
  let window = BrowserWindowModel.preview(in: .english)
  return SearchToolbarField(window: window)
    .padding()
}

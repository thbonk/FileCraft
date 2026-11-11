/*
 * FileViewContainer.swift
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

import QuickLook
import SwiftUI
import UniformTypeIdentifiers

/// The file view of a tab in its view mode, or the empty, loading or error state of its folder. It also hosts
/// the Quick Look panel, whose preview follows the selection of every view mode.
internal struct FileViewContainer: View {

  // MARK: - Properties

  internal let tab: TabModel

  // MARK: - Body

  internal var body: some View {
    content
      .quickLookPreview(quickLookURL, in: tab.quickLookURL == nil ? [] : tab.quickLookURLs)
      .focusedValue(\.focusedFileTab, tab)
      .modifier(FilePasteboardSupport(tab: tab))
      // Items dropped between the items, onto the view's background, go into the tab's folder.
      .fileDropTarget(tab.folderURL, tab: tab)
      .onChange(of: tab.selection) {
        tab.selectionDidChange()
      }
      .task(id: tab.selection) {
        await tab.refreshOpenWithApplications()
      }
      .fileImporter(
        isPresented: isChoosingApplication,
        allowedContentTypes: [.application],
        allowsMultipleSelection: false
      ) { result in
        if case .success(let applications) = result, let application = applications.first,
          let urls = tab.applicationChoiceRequest
        {
          WorkspaceActions.open(urls, withApplicationAt: application)
        }
        tab.applicationChoiceRequest = nil
      } onCancellation: {
        tab.applicationChoiceRequest = nil
      }
      .fileDialogDefaultDirectory(URL(filePath: "/Applications", directoryHint: .isDirectory))
      .alert(Text("The original item can't be found."), isPresented: isShowingBrokenAlias, presenting: tab.brokenAlias) { _ in
        Button("Delete Alias", role: .destructive) {
          Task {
            await tab.deleteBrokenAlias()
          }
        }
        Button("Cancel", role: .cancel) {
          tab.brokenAlias = nil
        }
      } message: { alias in
        Text("The original of “\(alias.localizedName)” no longer exists. You can move the alias to the Trash.")
      }
      .alert(tab.failureMessage.map { Text($0) } ?? Text(verbatim: ""), isPresented: isShowingFailure) {
        Button("OK") {
          tab.failureMessage = nil
        }
      }
      .onChange(of: tab.listing.items) {
        tab.listingDidChange()
      }
      .onChange(of: tab.viewSettings.viewMode) { _, mode in
        if mode == .columns {
          tab.showSelectionInColumns()
        }
      }
  }

  // MARK: - Private

  @ViewBuilder
  private var content: some View {
    switch tab.listing.state {
    case .failed(let failure):
      FolderFailureView(failure: failure) {
        Task { await tab.authenticateToView() }
      }
    default:
      // An empty folder keeps its file view, which takes keyboard focus and offers Paste, drops and the background
      // menu; the message lies on top without taking clicks.
      fileView
        .overlay {
          if tab.listing.items.isEmpty {
            if tab.listing.state == .loading {
              DelayedProgressView()
            } else if tab.listing.state == .loaded {
              ContentUnavailableView("Folder Is Empty", systemImage: "folder")
                .allowsHitTesting(false)
            }
          }
        }
    }
  }

  @ViewBuilder
  private var fileView: some View {
    switch tab.viewSettings.viewMode {
    case .icons:
      IconFileView(tab: tab)
    case .list:
      ListFileView(tab: tab)
    case .columns:
      ColumnFileView(tab: tab)
    }
  }

  private var quickLookURL: Binding<URL?> {
    Binding {
      tab.quickLookURL
    } set: { url in
      tab.quickLookDidMove(to: url)
    }
  }

  /// Presents the application panel of Open With > Other…; the completion handlers end the request, so that
  /// they still see the items when the panel closes.
  private var isChoosingApplication: Binding<Bool> {
    Binding {
      tab.applicationChoiceRequest != nil
    } set: { _ in
    }
  }

  private var isShowingBrokenAlias: Binding<Bool> {
    Binding {
      tab.brokenAlias != nil
    } set: { isPresented in
      if isPresented == false {
        tab.brokenAlias = nil
      }
    }
  }

  private var isShowingFailure: Binding<Bool> {
    Binding {
      tab.failureMessage != nil
    } set: { isPresented in
      if isPresented == false {
        tab.failureMessage = nil
      }
    }
  }
}

/// Explains why a folder cannot be shown and offers what helps.
internal struct FolderFailureView: View {

  // MARK: - Properties

  internal let failure: LoadFailure
  /// Lists the folder through the privileged helper, for Authenticate to View.
  internal var authenticateToView: (() -> Void)?

  @Environment(\.openURL) private var openURL

  private static let fullDiskAccessSettings =
    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    ?? URL(filePath: "/System/Applications/System Settings.app")

  // MARK: - Body

  internal var body: some View {
    switch failure.kind {
    case .noPermission:
      ContentUnavailableView {
        Label("No Access to This Folder", systemImage: "lock")
      } description: {
        Text("FileCraft needs Full Disk Access to show this folder.")
      } actions: {
        Button("Open Privacy & Security Settings") {
          openURL(Self.fullDiskAccessSettings)
        }
        if let authenticateToView {
          Button("Authenticate to View", action: authenticateToView)
        }
      }
    case .notFound:
      ContentUnavailableView {
        Label("Folder Not Found", systemImage: "questionmark.folder")
      } description: {
        Text("The folder no longer exists.")
      }
    case .other:
      ContentUnavailableView {
        Label("Cannot Open Folder", systemImage: "exclamationmark.triangle")
      } description: {
        Text(failure.message)
      }
    }
  }
}

/// A progress indicator that appears only when loading takes longer than 300 ms.
internal struct DelayedProgressView: View {

  // MARK: - Properties

  @State private var isVisible = false

  // MARK: - Body

  internal var body: some View {
    Color.clear
      .overlay {
        if isVisible {
          ProgressView()
        }
      }
      .task {
        try? await Task.sleep(for: .milliseconds(300))
        isVisible = true
      }
  }
}

/// Edit > Cut, Copy and Paste for the items of a file view. A text field with focus keeps these commands for its
/// text. Pasting the items cut last moves them; anything else, also from other applications, is copied.
private struct FilePasteboardSupport: ViewModifier {

  let tab: TabModel

  func body(content: Content) -> some View {
    content
      .copyable(tab.selectedItems.map(\.url))
      .cuttable(for: URL.self) {
        let urls = tab.selectedItems.map(\.url)
        FileClipboard.shared.markCut(urls)
        return urls
      }
      .pasteDestination(for: URL.self, action: paste, validator: fileURLs)
  }

  private func paste(_ urls: [URL]) {
    guard let commands = tab.pane?.window?.fileCommands else {
      return
    }
    Task { await commands.paste(urls) }
  }

  /// The file references among `urls`; none when the location is not a folder, which rejects the paste.
  private func fileURLs(_ urls: [URL]) -> [URL] {
    tab.folderURL == nil ? [] : urls.filter(\.isFileURL)
  }
}

#Preview("Permission Error") {
  FolderFailureView(failure: LoadFailure(kind: .noPermission, message: ""))
    .frame(width: 420, height: 300)
}

#Preview("Not Found, German") {
  FolderFailureView(failure: LoadFailure(kind: .notFound, message: ""))
    .frame(width: 420, height: 300)
    .environment(\.locale, Locale(identifier: "de"))
}

#Preview("List") {
  FileViewContainer(tab: .preview(in: .english))
    .frame(width: 600, height: 320)
}

#Preview("Icons, German") {
  let tab = TabModel.preview(in: .german)
  tab.viewSettings.viewMode = .icons

  return FileViewContainer(tab: tab)
    .frame(width: 600, height: 320)
    .environment(\.locale, Locale(identifier: "de"))
}

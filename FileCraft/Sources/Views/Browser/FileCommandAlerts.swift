/*
 * FileCommandAlerts.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-04.
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

/// The alerts and sheets of a window's file commands: the destination of Copy To… and Move To…, the confirmations
/// before deleting or emptying the Trash, items that cannot be moved to the Trash, a Trash that needs Full Disk
/// Access, and failures.
internal struct FileCommandAlerts: ViewModifier {

  // MARK: - Properties

  @Bindable internal var commands: FileCommandModel
  internal var helperApproval: HelperApprovalModel = .shared

  // MARK: - Body

  internal func body(content: Content) -> some View {
    content
      .sheet(isPresented: isAskingForHelperApproval) {
        HelperApprovalSheet(model: helperApproval)
      }
      .sheet(item: $commands.destinationRequest) { request in
        TransferDestinationSheet(
          kind: request.kind,
          itemCount: request.urls.count,
          otherPaneFolder: commands.otherPaneFolder,
          recentFolders: RecentsStore.shared.folders.map { URL(filePath: $0.lastKnownPath, directoryHint: .isDirectory) }
        ) { folder in
          commands.destinationRequest = nil
          if let folder {
            Task { await commands.transfer(request.urls, to: folder, kind: request.kind) }
          }
        }
      }
      .alert(deleteTitle, isPresented: isConfirmingDelete) {
        Button("Delete", role: .destructive) {
          let urls = commands.deleteConfirmation
          commands.deleteConfirmation = []
          Task { await commands.deleteImmediately(urls) }
        }
        Button("Cancel", role: .cancel) {
          commands.deleteConfirmation = []
        }
      } message: {
        Text("You can’t undo this action.")
      }
      .alert(trashFailureTitle, isPresented: isShowingTrashFailures) {
        Button("Delete Immediately", role: .destructive) {
          let urls = commands.trashFailures
          commands.trashFailures = []
          Task { await commands.deleteImmediately(urls) }
        }
        Button("Cancel", role: .cancel) {
          commands.trashFailures = []
        }
      } message: {
        Text("You can’t undo this action.")
      }
      .alert("Are you sure you want to permanently erase the items in the Trash?", isPresented: $commands.isConfirmingEmptyTrash) {
        Button("Empty Trash", role: .destructive) {
          Task { await commands.emptyTrash() }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("You can’t undo this action.")
      }
      .alert("FileCraft can’t read the Trash.", isPresented: $commands.needsFullDiskAccessToEmptyTrash) {
        Button("Open System Settings") {
          WorkspaceActions.openFullDiskAccessSettings()
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("To empty the Trash, allow Full Disk Access for FileCraft in System Settings > Privacy & Security.")
      }
      .alert(failureTitle, isPresented: isShowingFailure, presenting: commands.failure) { _ in
        Button("OK") {
          commands.failure = nil
        }
      } message: { failure in
        if let message = failure.message {
          Text(verbatim: message)
        }
      }
  }

  // MARK: - Titles

  private var deleteTitle: Text {
    let urls = commands.deleteConfirmation
    if urls.count == 1, let url = urls.first {
      return Text("Are you sure you want to delete “\(url.lastPathComponent)” immediately?")
    }
    return Text("Are you sure you want to delete these \(urls.count) items immediately?")
  }

  private var trashFailureTitle: Text {
    let urls = commands.trashFailures
    if urls.count == 1, let url = urls.first {
      return Text("“\(url.lastPathComponent)” can’t be moved to the Trash. Do you want to delete it immediately?")
    }
    return Text("\(urls.count) items can’t be moved to the Trash. Do you want to delete them immediately?")
  }

  private var failureTitle: Text {
    commands.failure.map { Text($0.title) } ?? Text(verbatim: "")
  }

  // MARK: - Bindings

  /// The helper's approval appears in the window the user works in.
  private var isAskingForHelperApproval: Binding<Bool> {
    Binding {
      helperApproval.isPresented && BrowserWindowModel.mostRecentlyActive === commands.window
    } set: { isPresented in
      if isPresented == false {
        helperApproval.cancel()
      }
    }
  }

  private var isConfirmingDelete: Binding<Bool> {
    Binding {
      commands.deleteConfirmation.isEmpty == false
    } set: { isPresented in
      if isPresented == false {
        commands.deleteConfirmation = []
      }
    }
  }

  private var isShowingTrashFailures: Binding<Bool> {
    Binding {
      commands.trashFailures.isEmpty == false
    } set: { isPresented in
      if isPresented == false {
        commands.trashFailures = []
      }
    }
  }

  private var isShowingFailure: Binding<Bool> {
    Binding {
      commands.failure != nil
    } set: { isPresented in
      if isPresented == false {
        commands.failure = nil
      }
    }
  }
}

// MARK: - Previews

#Preview("Delete, English") {
  let commands = FileCommandModel()
  commands.deleteConfirmation = [URL(filePath: "/Users/anna/Documents/Report.pdf")]
  return Color.clear
    .frame(width: 400, height: 240)
    .modifier(FileCommandAlerts(commands: commands))
}

#Preview("Trash failure, German") {
  let commands = FileCommandModel()
  commands.trashFailures = [URL(filePath: "/Volumes/Share/a.txt"), URL(filePath: "/Volumes/Share/b.txt")]
  return Color.clear
    .frame(width: 400, height: 240)
    .modifier(FileCommandAlerts(commands: commands))
    .environment(\.locale, Locale(identifier: "de"))
}

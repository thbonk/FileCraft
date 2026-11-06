/*
 * OperationsSettingsPanes.swift
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

import SwiftUI

// MARK: - File Operations

/// The File Operations pane: warnings, copy verification and the Operations window.
internal struct FileOperationsSettingsPane: View {

  @AppStorage(SettingsKeys.warnsBeforeEmptyingTrash.name)
  private var warnsBeforeEmptyingTrash = SettingsKeys.warnsBeforeEmptyingTrash.defaultValue
  @AppStorage(SettingsKeys.warnsBeforeChangingExtension.name)
  private var warnsBeforeChangingExtension = SettingsKeys.warnsBeforeChangingExtension.defaultValue
  @AppStorage(SettingsKeys.verifiesCopies.name) private var verifiesCopies = SettingsKeys.verifiesCopies.defaultValue
  @AppStorage(SettingsKeys.showsOperationsAutomatically.name)
  private var showsOperationsAutomatically = SettingsKeys.showsOperationsAutomatically.defaultValue

  var body: some View {
    SettingsPaneForm(pane: .fileOperations) {
      Section {
        Toggle("Warn before emptying the Trash", isOn: $warnsBeforeEmptyingTrash)
        Toggle("Warn before changing an extension", isOn: $warnsBeforeChangingExtension)
      }
      Section {
        Toggle(isOn: $verifiesCopies) {
          Text("Verify copies")
          Text("Compares each copied file with its original, which takes longer.")
        }
        Toggle(isOn: $showsOperationsAutomatically) {
          Text("Show the Operations window automatically")
          Text("Opens the window when an operation takes longer than five seconds.")
        }
      }
    }
  }
}

// MARK: - Compression

/// The Compression pane: format, destination and what happens after compressing and expanding.
internal struct CompressionSettingsPane: View {

  @AppStorage(SettingsKeys.compressionFormat.name) private var compressionFormat = SettingsKeys.compressionFormat.defaultValue
  @AppStorage(SettingsKeys.archiveDestination.name) private var archiveDestination = SettingsKeys.archiveDestination.defaultValue
  @AppStorage(SettingsKeys.archiveDestinationPath.name) private var archiveDestinationPath = SettingsKeys.archiveDestinationPath.defaultValue
  @AppStorage(SettingsKeys.selectsResult.name) private var selectsResult = SettingsKeys.selectsResult.defaultValue
  @AppStorage(SettingsKeys.expandsArchivesInFileCraft.name)
  private var expandsArchivesInFileCraft = SettingsKeys.expandsArchivesInFileCraft.defaultValue
  @AppStorage(SettingsKeys.trashesArchiveAfterExpanding.name)
  private var trashesArchiveAfterExpanding = SettingsKeys.trashesArchiveAfterExpanding.defaultValue

  var body: some View {
    SettingsPaneForm(pane: .compression) {
      Section {
        Picker("Compress as:", selection: $compressionFormat) {
          ForEach(CompressionFormat.allCases, id: \.self) { format in
            Text(verbatim: format.title).tag(format)
          }
        }
        Picker("Save archives and expanded items in:", selection: $archiveDestination) {
          Text("The Folder of the Original").tag(ArchiveDestination.sameFolder)
          Text("Other Folder").tag(ArchiveDestination.chosenFolder)
        }
        if archiveDestination == .chosenFolder {
          SettingsFolderChooser(path: $archiveDestinationPath)
        }
      }
      Section {
        Toggle("Select the result", isOn: $selectsResult)
        Toggle("Expand archives in FileCraft when opened", isOn: $expandsArchivesInFileCraft)
        Toggle("Move the archive to the Trash after expanding", isOn: $trashesArchiveAfterExpanding)
      }
    }
  }
}

#Preview("File Operations") {
  FileOperationsSettingsPane()
    .frame(width: 600)
}

#Preview("Compression") {
  CompressionSettingsPane()
    .frame(width: 600)
}

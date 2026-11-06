/*
 * SystemSettingsPanes.swift
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
import UniformTypeIdentifiers

// MARK: - Default File Viewer

/// "Use FileCraft as default file viewer", shared by the Integration settings and the welcome window. Changing it sets
/// the system's file viewer preference at once and shows why that failed, if it did.
internal struct DefaultFileViewerToggle: View {

  @AppStorage(SettingsKeys.usesFileCraftAsFileViewer.name)
  private var usesFileCraftAsFileViewer = SettingsKeys.usesFileCraftAsFileViewer.defaultValue
  @State private var fileViewerError: FileViewerError?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Toggle(isOn: $usesFileCraftAsFileViewer) {
        Text("Use FileCraft as default file viewer")
        Text("“Show in Finder” in other applications shows files in FileCraft. Applications that are already running must be restarted first. Folders that other applications open, as with “open” in Terminal, still open in Finder.")
      }
      if let fileViewerError {
        VStack(alignment: .leading, spacing: 2) {
          Text(verbatim: fileViewerError.localizedDescription)
            .foregroundStyle(.red)
          Text(verbatim: fileViewerError.details)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
      }
    }
    .onChange(of: usesFileCraftAsFileViewer) { _, usesFileCraft in
      do throws(FileViewerError) {
        fileViewerError = nil
        try DefaultFileViewer().apply(usesFileCraft: usesFileCraft)
      } catch {
        fileViewerError = error
      }
    }
  }
}

// MARK: - Integration

/// The Integration pane: the terminal, FileCraft as the default file viewer and the shelf.
internal struct IntegrationSettingsPane: View {

  /// The picker's tag for Other…, which lets the user choose any application.
  private static let otherTerminalTag = ""

  @AppStorage(SettingsKeys.terminalBundleIdentifier.name)
  private var terminalBundleIdentifier = SettingsKeys.terminalBundleIdentifier.defaultValue
  @AppStorage(SettingsKeys.removesShelfItemsAfterDrag.name)
  private var removesShelfItemsAfterDrag = SettingsKeys.removesShelfItemsAfterDrag.defaultValue
  @AppStorage(SettingsKeys.quitsFinderOnLaunch.name) private var quitsFinderOnLaunch = SettingsKeys.quitsFinderOnLaunch.defaultValue
  @AppStorage(SettingsKeys.hidesFinderDesktop.name) private var hidesFinderDesktop = SettingsKeys.hidesFinderDesktop.defaultValue
  @State private var isConfirmingQuitFinder = false

  @State private var isChoosingTerminal = false

  var body: some View {
    SettingsPaneForm(pane: .integration) {
      Section {
        Picker("Open in Terminal uses:", selection: terminal) {
          ForEach(TerminalApplications.installed(including: terminalBundleIdentifier)) { application in
            Text(verbatim: application.name).tag(application.bundleIdentifier)
          }
          Divider()
          Text("Other…").tag(Self.otherTerminalTag)
        }
      }
      Section {
        DefaultFileViewerToggle()
      }
      Section {
        Toggle("Remove items from the shelf after dragging them out", isOn: $removesShelfItemsAfterDrag)
      }
      Section("Finder") {
        Toggle(isOn: quitsFinder) {
          Text("Quit Finder when FileCraft launches")
          Text("Finder starts again when FileCraft quits.")
        }
        Toggle(isOn: $hidesFinderDesktop) {
          Text("Hide Finder's desktop")
          Text("The desktop shows no icons, also while FileCraft is not running. Turn this off before you remove FileCraft.")
        }
      }
    }
    .alert("Quit Finder when FileCraft launches?", isPresented: $isConfirmingQuitFinder) {
      Button("Turn On") {
        quitsFinderOnLaunch = true
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Some system features, such as Time Machine, may not work correctly while Finder is not running.")
    }
    .onChange(of: quitsFinderOnLaunch) { _, quitsFinder in
      Task {
        await FinderReplacement().setQuitsFinder(quitsFinder)
      }
    }
    .onChange(of: hidesFinderDesktop) { _, hidesDesktop in
      Task {
        await FinderReplacement().setHidesDesktop(hidesDesktop)
      }
    }
    .fileImporter(isPresented: $isChoosingTerminal, allowedContentTypes: [.application]) { result in
      if case .success(let url) = result, let identifier = Bundle(url: url)?.bundleIdentifier {
        terminalBundleIdentifier = identifier
      }
    }

  }

  /// Turning the option on asks first, because some system features need Finder.
  private var quitsFinder: Binding<Bool> {
    Binding {
      quitsFinderOnLaunch
    } set: { isOn in
      if isOn, quitsFinderOnLaunch == false {
        isConfirmingQuitFinder = true
      } else {
        quitsFinderOnLaunch = isOn
      }
    }
  }

  private var terminal: Binding<String> {
    Binding {
      terminalBundleIdentifier
    } set: { identifier in
      if identifier == Self.otherTerminalTag {
        isChoosingTerminal = true
      } else {
        terminalBundleIdentifier = identifier
      }
    }
  }
}

// MARK: - Helper

/// The Helper pane: the privileged helper's status, Install Helper, Remove Helper and Open System Settings.
internal struct HelperSettingsPane: View {

  @State private var model = HelperSettingsModel()

  var body: some View {
    SettingsPaneForm(pane: .helper) {
      Section {
        LabeledContent("Status:") {
          statusLabel
        }
        Text("The helper performs file operations that need administrator rights. macOS asks you to allow it in System Settings once.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      Section {
        HStack {
          Button("Install Helper") {
            model.install()
          }
          .disabled(model.canInstall == false)
          Button("Remove Helper") {
            Task { await model.remove() }
          }
          .disabled(model.canRemove == false)
          Spacer()
          Button("Open System Settings") {
            model.openSystemSettings()
          }
        }
      }
    }
    .task {
      // The user approves the helper in System Settings; the status changes when FileCraft becomes active again.
      for await _ in NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification) {
        model.refresh()
      }
    }
  }

  @ViewBuilder
  private var statusLabel: some View {
    switch model.status {
    case .notInstalled:
      Label("Not installed", systemImage: "circle")
        .foregroundStyle(.secondary)
    case .waitingForApproval:
      Label("Waiting for approval", systemImage: "clock")
        .foregroundStyle(.orange)
    case .enabled:
      Label("Enabled", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    case .error(let message):
      Label {
        Text("Error: \(message)")
      } icon: {
        Image(systemName: "exclamationmark.triangle.fill")
      }
      .foregroundStyle(.red)
    }
  }
}

// MARK: - Advanced

/// The Advanced pane: size units, Reset Warnings and Reset All Settings.
internal struct AdvancedSettingsPane: View {

  @AppStorage(SettingsKeys.sizeUnits.name) private var sizeUnits = SettingsKeys.sizeUnits.defaultValue

  @State private var isConfirmingReset = false
  @State private var hasResetWarnings = false

  var body: some View {
    SettingsPaneForm(pane: .advanced) {
      Section {
        Picker("Size units:", selection: $sizeUnits) {
          Text("Decimal (1 KB = 1,000 bytes)").tag(SizeUnits.decimal)
          Text("Binary (1 KiB = 1,024 bytes)").tag(SizeUnits.binary)
        }
      }
      Section {
        LabeledContent {
          Button("Reset Warnings") {
            SettingsStore().resetWarnings()
            hasResetWarnings = true
          }
        } label: {
          Text("Shows all warnings again that you turned off.")
          if hasResetWarnings {
            Text("All warnings are shown again.")
          }
        }
        LabeledContent {
          Button("Reset All Settings…", role: .destructive) {
            isConfirmingReset = true
          }
        } label: {
          Text("Restores the defaults of all settings, including the view defaults.")
        }
      }
    }
    .alert("Reset all settings?", isPresented: $isConfirmingReset) {
      Button("Reset All Settings", role: .destructive) {
        Self.resetAllSettings()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("All settings return to their defaults. Favorites, the shelf and presets stay.")
    }
  }

  /// Resets every preference and the system state that follows from some of them.
  private static func resetAllSettings() {
    let settings = SettingsStore()
    let wasFileViewer = settings.value(for: SettingsKeys.usesFileCraftAsFileViewer)
    let quitFinder = settings.value(for: SettingsKeys.quitsFinderOnLaunch)
    let hidDesktop = settings.value(for: SettingsKeys.hidesFinderDesktop)
    settings.resetAll()
    settings.applyWindowRestoration()
    if wasFileViewer {
      try? DefaultFileViewer().apply(usesFileCraft: false)
    }
    Task {
      if hidDesktop {
        await FinderReplacement().setHidesDesktop(false, restartsFinder: quitFinder == false)
      }
      if quitFinder {
        await FinderReplacement().setQuitsFinder(false)
      }
    }
  }
}

#Preview("Integration") {
  IntegrationSettingsPane()
    .frame(width: 600)
}

#Preview("Helper") {
  HelperSettingsPane()
    .frame(width: 600)
}

#Preview("Advanced") {
  AdvancedSettingsPane()
    .frame(width: 600)
}

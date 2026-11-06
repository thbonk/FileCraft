/*
 * WelcomeView.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-06.
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

/// The welcome window: Welcome, Full Disk Access and Default File Viewer. Done, Skip and closing the window complete
/// onboarding, so that the window no longer opens at launch.
internal struct WelcomeView: View {

  // MARK: - Properties

  internal static let windowID = "welcome"

  @State private var model: WelcomeModel
  @Environment(\.dismissWindow) private var dismissWindow

  // MARK: - Initialization

  internal init(model: WelcomeModel = WelcomeModel()) {
    _model = State(initialValue: model)
  }

  // MARK: - Body

  internal var body: some View {
    VStack(spacing: 0) {
      Group {
        switch model.step {
        case .welcome:
          WelcomeStep()
        case .fullDiskAccess:
          FullDiskAccessStep(status: model.fullDiskAccess)
        case .defaultFileViewer:
          DefaultFileViewerStep()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(28)
      Divider()
      HStack {
        Button("Skip") {
          finish()
        }
        .disabled(model.isLastStep)
        Spacer()
        Text("Step \(model.step.rawValue + 1) of \(WelcomeModel.Step.allCases.count)")
          .font(.callout)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Back") {
          model.goBack()
        }
        .disabled(model.isFirstStep)
        if model.isLastStep {
          Button("Done") {
            finish()
          }
          .keyboardShortcut(.defaultAction)
        } else {
          Button("Continue") {
            model.goForward()
          }
          .keyboardShortcut(.defaultAction)
        }
      }
      .padding(16)
    }
    .frame(width: 560, height: 420)
    .onAppear {
      model.restart()
    }
    // Closing the window counts as skipping.
    .onDisappear {
      model.complete()
    }
    .task {
      // The user grants Full Disk Access in System Settings; the status changes when FileCraft becomes active again.
      await model.refreshFullDiskAccess()
      for await _ in NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification) {
        await model.refreshFullDiskAccess()
      }
    }
  }

  // MARK: - Private

  private func finish() {
    model.complete()
    dismissWindow(id: Self.windowID)
  }
}

// MARK: - Steps

private struct WelcomeStep: View {

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 16) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .frame(width: 72, height: 72)
          .accessibilityHidden(true)
        Text("Welcome to FileCraft")
          .font(.largeTitle.weight(.semibold))
      }
      Text("FileCraft browses, organizes and manages your files with tabs, two panes, a shelf, batch renaming and more.")
      Text("Two settings help FileCraft work best. You can change both later in Settings.")
        .foregroundStyle(.secondary)
    }
  }
}

private struct FullDiskAccessStep: View {

  let status: FullDiskAccessStatus

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("Full Disk Access", systemImage: "externaldrive.badge.checkmark")
        .font(.title2.weight(.semibold))
      Text("macOS protects some folders, such as Mail, Messages, Safari and Time Machine backups. A file manager needs Full Disk Access to show and manage them.")
      Text("FileCraft works without it too; protected folders then show a hint instead of their contents.")
        .foregroundStyle(.secondary)
      LabeledContent("Status:") {
        statusLabel
      }
      Button("Open Privacy & Security Settings") {
        WorkspaceActions.openFullDiskAccessSettings()
      }
      Text("Turn on FileCraft in the Full Disk Access list, then return to FileCraft.")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var statusLabel: some View {
    switch status {
    case .granted:
      Label("Granted", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    case .notGranted:
      Label("Not granted", systemImage: "xmark.circle.fill")
        .foregroundStyle(.orange)
    case .unknown:
      Label("Unknown", systemImage: "questionmark.circle")
        .foregroundStyle(.secondary)
    }
  }
}

private struct DefaultFileViewerStep: View {

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("Default File Viewer", systemImage: "folder.badge.gearshape")
        .font(.title2.weight(.semibold))
      Text("FileCraft can take Finder's place when other applications show files, for example with “Show in Finder”.")
      Form {
        DefaultFileViewerToggle()
      }
      .formStyle(.grouped)
      .scrollDisabled(true)
    }
  }
}

#Preview("Welcome") {
  // Previews keep the onboarding state in their own defaults.
  WelcomeView(model: WelcomeModel(settings: SettingsStore(defaults: UserDefaults(suiteName: "FileCraftPreview") ?? .standard)))
}

#Preview("Full Disk Access") {
  FullDiskAccessStep(status: .notGranted)
    .padding()
    .frame(width: 560)
}

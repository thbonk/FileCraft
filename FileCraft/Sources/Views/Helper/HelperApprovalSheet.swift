/*
 * HelperApprovalSheet.swift
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

/// Explains FileCraft's helper before installing it, then how to allow it in System Settings (privileged helper
/// spec). FileCraft checks again when it becomes active and continues the waiting action.
internal struct HelperApprovalSheet: View {

  // MARK: - Properties

  internal let model: HelperApprovalModel

  @Environment(\.appearsActive) private var appearsActive

  // MARK: - Body

  internal var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "lock.shield")
          .font(.largeTitle)
          .foregroundStyle(.tint)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 6) {
          title
            .font(.headline)
          message
            .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
      }
      HStack {
        Spacer()
        Button("Cancel", role: .cancel) {
          model.cancel()
        }
        .keyboardShortcut(.cancelAction)
        switch model.phase {
        case .install:
          Button("Install Helper") {
            model.install()
          }
          .keyboardShortcut(.defaultAction)
        case .approval:
          Button("Open System Settings") {
            model.openSystemSettings()
          }
          .keyboardShortcut(.defaultAction)
        case .failure, nil:
          EmptyView()
        }
      }
    }
    .padding(20)
    .frame(width: 460)
    .onChange(of: appearsActive) { _, isActive in
      if isActive {
        model.recheck()
      }
    }
  }

  // MARK: - Parts

  private var title: Text {
    switch model.phase {
    case .install, nil:
      Text("Install FileCraft’s Helper")
    case .approval, .failure:
      Text("Allow FileCraft’s Helper")
    }
  }

  private var message: Text {
    switch model.phase {
    case .install, nil:
      Text("To change protected files, FileCraft installs a helper that runs with administrator rights. It performs only the file operations you start, after you authenticate as an administrator. macOS then asks you to allow the helper in System Settings.")
    case .approval:
      Text("To change protected files, FileCraft uses a helper that runs with administrator rights. Turn on FileCraft in System Settings > General > Login Items & Extensions, then return to FileCraft.")
    case .failure(let reason):
      Text(verbatim: reason)
    }
  }
}

// MARK: - Previews

#Preview("Install, English") {
  HelperApprovalSheet(model: HelperApprovalModel(openSettings: {}))
}

#Preview("Install, German") {
  HelperApprovalSheet(model: HelperApprovalModel(openSettings: {}))
    .environment(\.locale, Locale(identifier: "de"))
}

/*
 * TranslocationRepairAlert.swift
 * FileCraft
 *
 * Created by Thomas Bonk on 2026-11-13.
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

/// Offers, in the first browser window, to let a translocated FileCraft run in place again so that it can update
/// itself; without its own location known, it explains how to do that in Finder.
internal struct TranslocationRepairAlert: ViewModifier {

  // MARK: - Properties

  internal var repair: TranslocationRepair = .shared

  @State private var isOffering = false
  @State private var failure: String?

  // MARK: - Body

  internal func body(content: Content) -> some View {
    content
      .onAppear {
        if repair.claimOffer() {
          isOffering = true
        }
      }
      .alert(Text("FileCraft Can’t Update Itself"), isPresented: $isOffering) {
        if case .translocated(original: .some) = repair.state {
          Button("Fix and Relaunch") {
            do {
              try repair.repairAndRelaunch()
            } catch {
              failure = error.localizedDescription
            }
          }
          Button("Not Now", role: .cancel) {}
        } else {
          Button("OK", role: .cancel) {}
        }
      } message: {
        if case .translocated(original: let original?) = repair.state {
          Text(
            "macOS runs FileCraft from a temporary copy, because FileCraft was moved without Finder after it was downloaded. FileCraft can fix this and relaunch from “\(original.comparablePath)”.",
            comment: "Translocation alert; the value is the path of FileCraft's own location.")
        } else {
          Text(
            "macOS runs FileCraft from a temporary copy, because FileCraft was moved without Finder after it was downloaded. To fix this, quit FileCraft, drag it out of the Applications folder and back in Finder, and open it again.",
            comment: "Translocation alert when FileCraft's own location is unknown.")
        }
      }
      .alert(Text("FileCraft Couldn’t Be Fixed"), isPresented: isShowingFailure) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(verbatim: failure ?? "")
      }
  }

  // MARK: - Private

  private var isShowingFailure: Binding<Bool> {
    Binding {
      failure != nil
    } set: { isPresented in
      if isPresented == false {
        failure = nil
      }
    }
  }
}

#Preview("Translocated") {
  Text(verbatim: "FileCraft")
    .frame(width: 400, height: 200)
    .modifier(TranslocationRepairAlert(repair: TranslocationRepair(state: .translocated(original: URL(filePath: "/Applications/FileCraft.app")))))
}

#Preview("Location Unknown, German") {
  Text(verbatim: "FileCraft")
    .frame(width: 400, height: 200)
    .modifier(TranslocationRepairAlert(repair: TranslocationRepair(state: .translocated(original: nil))))
    .environment(\.locale, Locale(identifier: "de"))
}

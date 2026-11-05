/*
 * TabDragItem.swift
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

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

extension UTType {
  /// A browser tab dragged between tab bars, declared in the app's Info.plist.
  nonisolated internal static let fileCraftTab = UTType(exportedAs: "de.meandmymac.filecraft.tab")
}

/// The payload of a dragged tab. The identifier is only meaningful inside the window the tab belongs to, so the
/// type never leaves FileCraft.
nonisolated internal struct TabDragItem: Codable, Hashable, Sendable, Transferable {

  internal let tabID: UUID

  internal static var transferRepresentation: some TransferRepresentation {
    CodableRepresentation(contentType: .fileCraftTab)
  }
}

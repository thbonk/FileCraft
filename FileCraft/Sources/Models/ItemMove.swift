/*
 * ItemMove.swift
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

import Foundation

/// An item that went from one location to another, for example into the Trash, so that undo can move it back.
nonisolated internal struct ItemMove: Hashable, Sendable {

  internal let from: URL
  internal let to: URL

  /// The move back.
  internal var reversed: ItemMove {
    ItemMove(from: to, to: from)
  }
}

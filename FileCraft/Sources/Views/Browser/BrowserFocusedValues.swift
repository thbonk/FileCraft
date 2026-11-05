/*
 * BrowserFocusedValues.swift
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

import SwiftUI

extension FocusedValues {
  /// The model of the key browser window. Menu commands act on its active pane.
  @Entry internal var browserWindow: BrowserWindowModel?
  /// The tab whose file view, or a view inside it, has keyboard focus. Commands whose shortcuts also edit text,
  /// such as ⌘⌫, act only then, so that they never trash files while a text field has focus.
  @Entry internal var focusedFileTab: TabModel?
}

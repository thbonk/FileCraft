#  # Development Guidelines
## Project Context
- **Target OS:** iOS 17.0+ (oder iOS 18+)
- **Primary Tech Stack:** Swift 6, SwiftUI, Swift Testing
- **Architecture:** MVVM
- **Dependency Manager:** Swift Package Manager (SPM) - No Third-Party-Dependencies without acknowledgement!
- **Approved exception:** Sparkle 2 for software updates (design decision D16 of `add-ui-specification`), added to the app target only and pinned to an exact version. Review Sparkle's release notes before raising the version, and raise the pin in `release.yml` to the same version.

## File Header
All source files shall have the following file header.
```swift
/*
 * <file name>
 * <package name>
 *
 * Created by <author> on <yyyy-mm-dd>.
 * Copyright <yyyy> Thomas Bonk <thomas@meandmymac.de>
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
```
## UI & SwiftUI Standards
- **Exclusively SwiftUI:** Do not use UIKit components (`UIViewRepresentable`) by default unless explicitly requested or required.
- **State Management:** 
  - Use the modern `@Observable` macro instead of the deprecated `ObservableObject`.
  - Keep UI-related state local using `@State` or `@Binding`.
- **Navigation:** Exclusively use `NavigationStack` or `NavigationSplitView` with value-based routing. `NavigationView` is strictly forbidden.
- **Previews:** Every SwiftUI view MUST include a `#Preview` block with static mock data. No live network or database requests inside previews.
- **Adaptability:** All views must natively support Dynamic Type (font sizing) and Dark Mode.

## Swift 6 & Concurrency
- **Strict Concurrency:** Adhere strictly to Swift 6 data-race safety rules.
- **MainActor:** Consistently annotate UI-related components (Views, ViewModels) with `@MainActor`.
- **Structured Concurrency:** Prefer `async let` and Task Groups for parallel operations.
- **View Lifecycle:** Bind asynchronous tasks to the view's lifecycle using `.task { ... }`. Avoid unbound `Task { ... }` blocks that strongly capture `self`.
- **Anti-Pattern:** Do not use Grand Central Dispatch (`DispatchQueue.main.async`, etc.). Use Swift Concurrency (`await`) instead.

## Coding Style & Safety
- **Value Types:** Prefer structs (value types) over classes (reference types) whenever possible.
- **Safety First:** Force unwrapping (`!`) and force casts (`as!`) are banned in production code. Use `if let`, `guard let`, or fallback default values.
- **Access Control:** Assign explicit access levels (`private`, `fileprivate`, `internal`, `public`).
- **Documentation:** All public interfaces and complex functions must feature concise Markdown documentation comments (`///`).

## Development Workflow Commands
When modifying code, use the following CLI commands for verification:
- **Build Project:** `xcodebuild -project [YourProject].xcodeproj -scheme [YourScheme] -destination 'platform=macOS' -quiet`
- **Run Tests:** `xcodebuild test -project [YourProject].xcodeproj -scheme [YourScheme] -destination 'platform=macOS'`

## Planner Mode Process
Before creating or modifying code files:
1. **Reflect** deeply on the proposed change.
2. **Create a plan** in the console outlining which files are affected.
3. **Confirm** the approach before writing code.

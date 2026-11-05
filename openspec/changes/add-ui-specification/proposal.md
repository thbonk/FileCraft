## Why

FileCraft aims to replace Finder with Path Finder–class features but is still a "Hello, world" template. A complete, testable UI specification is needed before implementation starts. Path Finder 26.1.10 was analyzed statically to map its feature landscape; FileCraft's design is its own and reuses no Path Finder assets.

## What Changes

- Define the browser window: customizable toolbar, sidebar, path bar, status bar, inspector, shelf, tabs and an optional dual-pane layout.
- Define icon, list and column views with sorting, grouping, view options, Quick Look, drag and drop and keyboard-first operation.
- Define file operations with a background queue, conflict resolution and undo.
- Define privileged file operations through a helper daemon registered with **SMAppService**; the deprecated SMJobBless API is not used.
- Define batch rename, filter and search, settings, menus, shortcuts, context menus and Full Disk Access onboarding.
- Localize the entire UI in English (development language) and German.
- Add software updates through Sparkle (approved third-party exception) with a signed appcast.
- Adjust the project: bundle identifier `de.meandmymac.FileCraft`, macOS-only target (minimum macOS 27.0), App Sandbox off (Developer ID with Hardened Runtime), German region, Swift Testing and helper targets.

## Capabilities

### New Capabilities

- `browser-window`: window composition, toolbar, bars, layout toggles, state restoration
- `file-views`: icon, list and column views; sorting, grouping, view options, selection, Quick Look, drag and drop
- `navigation`: history, standard locations, Go to Folder, path bar, recent folders, open and reveal
- `sidebar`: favorites, locations, tags
- `tabs-and-dual-pane`: tabs per pane, dual-pane layout, active pane, cross-pane commands
- `inspector`: inspector panel, Get Info windows, permissions, tags, Open With
- `shelf`: app-wide holding area for file references
- `file-operations`: file commands, operation queue, progress, conflicts, undo
- `privileged-helper`: SMAppService helper daemon and authenticated privileged operations
- `batch-rename`: rule-based multi-item rename with live preview
- `search-and-filter`: quick filter, search, select by pattern
- `settings`: settings window, persisted preferences and software updates
- `menus-and-shortcuts`: menu bar, context menus, keyboard shortcuts
- `onboarding`: first launch and Full Disk Access guidance
- `localization`: English and German localization
- `appearance-and-accessibility`: original assets, system appearance, accessibility

### Modified Capabilities

None; no specs exist yet.

## Non-goals

- Visual, naming or behavioral parity with Path Finder, and reuse of any Path Finder asset, string or code.
- Deferred to follow-up changes (see the design's roadmap): compare and sync, duplicates, disk usage, terminal, Git status, saved searches, network connections and more.
- Not planned: built-in text editor, disc burning, RAM disks, secure delete, desktop replacement, launching apps as root.
- Mac App Store distribution and iOS or visionOS builds.

## Impact

- Code: new SwiftUI scenes, view models and services under `FileCraft/Sources/`; helper daemon and Swift Testing targets.
- Project: sandbox, Hardened Runtime and platform build settings; `de` region; String Catalogs.
- Distribution: Developer ID signing, notarization and a signed Sparkle appcast; users approve Full Disk Access and the background helper in System Settings.
- Dependencies: Sparkle through Swift Package Manager (approved exception); otherwise Apple frameworks only.

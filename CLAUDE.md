# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

FileCraft is a macOS Finder replacement offering Path Finder–like features. SwiftUI app in Swift 6, built with Xcode 27, deployment target macOS 27.0.

## Development guidelines

The coding rules (mandatory Apache-2.0 file header, SwiftUI, concurrency and style rules, plan-and-confirm before editing code, no third-party dependencies without approval) are imported from:

@docs/dev/DEVELOPMENT_GUIDELINES.md

Where that file disagrees with the actual project, the project wins:

- The target platform is macOS, not iOS 17/18. The "no UIKit" rule translates to no AppKit bridging (`NSViewRepresentable`) unless requested or required.
- `[YourProject]` / `[YourScheme]` in its commands are `FileCraft.xcodeproj` / `FileCraft`.

## Commands

```sh
# Build
xcodebuild -project FileCraft.xcodeproj -scheme FileCraft -destination 'platform=macOS' -quiet build

# Run all tests
xcodebuild test -project FileCraft.xcodeproj -scheme FileCraft -destination 'platform=macOS'

# Run one suite
xcodebuild test -project FileCraft.xcodeproj -scheme FileCraft -destination 'platform=macOS' \
  -only-testing:FileCraftTests/AppConfigurationTests

# Run one test; raw-identifier test names keep their backticks
xcodebuild test -project FileCraft.xcodeproj -scheme FileCraft -destination 'platform=macOS' \
  -only-testing:'FileCraftTests/AppConfigurationTests/`App runs outside the App Sandbox`()'
```

- Tests use Swift Testing in the `FileCraftTests` target, which is hosted in the app: `Bundle.main` and the process environment are FileCraft's own.
- The shared scheme `FileCraft` (`FileCraft.xcodeproj/xcshareddata/xcschemes/`) builds the app and runs `FileCraftTests` in its Test action.
- The log line `IDERunDestination: Supported platforms for the buildables in the current scheme is empty.` is harmless.
- No linter, formatter or CI is configured.

## Project configuration that shapes code

These build settings in `FileCraft.xcodeproj/project.pbxproj` dictate how code must be written:

- **Synchronized folders.** `FileCraft/`, `FileCraftTests/`, `FileCraftHelper/`, `Shared/` and `docs/` are file-system-synchronized groups. New files under `FileCraft/` join the app target, under `FileCraftTests/` the test target, under `FileCraftHelper/` the privileged helper target, and under `Shared/` both the app and the helper, so never edit `project.pbxproj` to add sources. Code in `Shared/` must be explicitly `nonisolated`, because the helper target has no default MainActor isolation. Non-source files placed in `docs/` get copied into the app bundle unless they get a target-membership exception, as `docs/dev/DEVELOPMENT_GUIDELINES.md` and `docs/dev/LOCALIZATION.md` have.
- **Privileged helper.** The `FileCraftHelper` command-line target is embedded at `Contents/MacOS/FileCraftHelper`; its launchd property list `LaunchDaemons/de.meandmymac.FileCraft.Helper.plist` is copied to `Contents/Library/LaunchDaemons` (design decision D11). Registering it (`-FCHelperSelfTest` in Debug builds) adds a background item to the user's Login Items, so do not register it without asking.
- **MainActor by default.** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` makes every declaration `@MainActor` unless marked `nonisolated`, including models and services. With `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `nonisolated async` functions still run on the caller's actor. File-system work such as enumeration, copying or hashing only leaves the main thread when marked `@concurrent`.
- **Member import visibility** (`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`). Each file must directly import every module whose extension members it uses; transitive imports don't count.
- **No App Sandbox.** `ENABLE_APP_SANDBOX = NO` with `ENABLE_HARDENED_RUNTIME = YES`, for Developer ID distribution (design decision D2 of `add-ui-specification`). Entitlements come from build settings; there is no `.entitlements` file. Privileged file operations go through the planned `SMAppService` helper daemon, never `SMJobBless`. Changing the sandbox or entitlements is a product decision, so ask first.
- **macOS only.** `SDKROOT` and `SUPPORTED_PLATFORMS` are `macosx`, the minimum system version is macOS 27.0 (no `#available` fallbacks), and the bundle identifier is `de.meandmymac.FileCraft`. `AppConfigurationTests` checks the bundle identifier and that the app runs unsandboxed.

## Source layout

Swift sources live in `FileCraft/Sources/`, one folder per layer: `Application/` holds the app entry point and `Views/` the SwiftUI views. New layers (view models, models, services) go in sibling folders. String Catalogs (`Localizable.xcstrings`, `InfoPlist.xcstrings`) live in `FileCraft/Resources/`; German strings follow the owner-approved glossary and rules in `docs/dev/LOCALIZATION.md`. Tests live in `FileCraftTests/`.

## Spec-driven workflow (OpenSpec)

Feature work is planned with OpenSpec (`openspec` CLI, schema `spec-driven`, project context and rules in `openspec/config.yaml`):

- `/opsx:explore` thinks a change through. `/opsx:propose` creates `openspec/changes/<name>/` with proposal, design, delta specs and tasks. `/opsx:update` revises it.
- `/opsx:apply` implements the change's `tasks.md`.
- `/opsx:archive` moves a finished change to `openspec/changes/archive/` and merges its delta specs into `openspec/specs/`, the spec of current behavior. `/opsx:sync` merges the specs without archiving.
- CLI: `openspec list` (changes), `openspec list --specs`, `openspec show <name>`, `openspec validate <name>`.

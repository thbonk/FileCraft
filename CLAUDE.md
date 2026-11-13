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

# Release build, as Xcode Cloud archives it
xcodebuild -project FileCraft.xcodeproj -scheme FileCraft -configuration Release -destination 'generic/platform=macOS' -quiet build

# Run all tests
xcodebuild test -project FileCraft.xcodeproj -scheme FileCraft -destination 'platform=macOS'

# Run one suite
xcodebuild test -project FileCraft.xcodeproj -scheme FileCraft -destination 'platform=macOS' \
  -only-testing:FileCraftTests/AppConfigurationTests

# Run one test; raw-identifier test names keep their backticks
xcodebuild test -project FileCraft.xcodeproj -scheme FileCraft -destination 'platform=macOS' \
  -only-testing:'FileCraftTests/AppConfigurationTests/`App runs outside the App Sandbox`()'

# Sync the String Catalogs with the code: adds new keys, marks unused ones stale
xcodebuild -exportLocalizations -project FileCraft.xcodeproj -localizationPath <scratch folder> -exportLanguage de

# Path of the built app; on the owner's Mac products go to the gitignored Build/Products/<Configuration>,
# so a copy in DerivedData is stale
APP="$(xcodebuild -project FileCraft.xcodeproj -scheme FileCraft -showBuildSettings 2>/dev/null | sed -n 's/^ *BUILT_PRODUCTS_DIR = //p' | head -1)/FileCraft.app"

# Debug only, ask first (adds a Login Items entry): register and ping the helper, then read its log
"$APP/Contents/MacOS/FileCraft" -FCHelperSelfTest
log show --last 5m --predicate 'subsystem == "de.meandmymac.FileCraft" AND category == "HelperSelfTest"'
```

- Tests use Swift Testing in the `FileCraftTests` target, which is hosted in the app: `Bundle.main` and the process environment are FileCraft's own. Code that must behave differently in the test host checks `AppEnvironment.isTestHost`; file-system fixtures use `FileCraftTests/Support/TemporaryDirectory`.
- In the test host, `SettingsStore()` and the scenes' `@AppStorage` use `AppEnvironment.userDefaults`: the suite `de.meandmymac.FileCraft.TestHost`, emptied at each launch, never the user's defaults. Views hosted in tests get `.defaultAppStorage(AppEnvironment.userDefaults)`. The suite is shared by tests running in parallel, so tests whose outcome depends on view settings still pass `ViewSettings()`.
- The test host launches without a browser window (`defaultLaunchBehavior(.suppressed)`), because AppKit saves a window's toolbar, split view and frame into the user's real defaults; tests create the models and views they need. Xcode starts it with `-ApplePersistenceIgnoreState YES`, so saved windows are neither restored nor overwritten. `TestHostTests` guards both.
- Guard tests: `LocalizationCoverageTests` fails on missing or stale German strings, changed placeholders and count strings without plural variants; `AssetAuditTests` pins the allowed bundle resources, so new assets need it updated; `MainMenuTests` checks the menu structure.
- The shared scheme `FileCraft` (`FileCraft.xcodeproj/xcshareddata/xcschemes/`) builds the app and runs `FileCraftTests` in its Test action.
- The log line `IDERunDestination: Supported platforms for the buildables in the current scheme is empty.` is harmless.
- Only one FileCraft process runs: a copy started while another runs hands its requests to the earlier one and quits within a second (`Application/SingleInstance.swift`), unless a debugger is attached. To try a build with `open` while FileCraft runs, quit the other copy first or run the build from Xcode.
- No linter or formatter is configured. CI is the GitHub Actions workflow `.github/workflows/ci.yml` on the `xcode-27` runner (macOS 27, Apple Silicon): on every push to a pull request and to `main` it builds the Release configuration and runs all tests with `CODE_SIGNING_ALLOWED=NO`, as the runner has no signing certificate; the linker's ad-hoc signature is enough for the test host. The Xcode Cloud workflow in App Store Connect is disabled.
- To reproduce CI locally without replacing the signed apps in `Build/Products`, pass `SYMROOT=<scratch>/Build OBJROOT=<scratch>/Intermediates`; `-derivedDataPath` alone does not move the products on the owner's Mac.

## Project configuration that shapes code

These build settings in `FileCraft.xcodeproj/project.pbxproj` dictate how code must be written:

- **Synchronized folders.** `FileCraft/`, `FileCraftTests/`, `FileCraftHelper/`, `Shared/` and `docs/` are file-system-synchronized groups. New files under `FileCraft/` join the app target, under `FileCraftTests/` the test target, under `FileCraftHelper/` the privileged helper target, and under `Shared/` both the app and the helper, so never edit `project.pbxproj` to add sources. Code in `Shared/` must be explicitly `nonisolated`, because the helper target has no default MainActor isolation. Non-source files placed in `docs/` get copied into the app bundle unless they get a target-membership exception, as `docs/dev/DEVELOPMENT_GUIDELINES.md` and `docs/dev/LOCALIZATION.md` have.
- **Privileged helper.** The `FileCraftHelper` command-line target is embedded at `Contents/MacOS/FileCraftHelper`; its launchd property list `LaunchDaemons/de.meandmymac.FileCraft.Helper.plist` is copied to `Contents/Library/LaunchDaemons` (design decision D11). Registering it (`-FCHelperSelfTest` in Debug builds) adds a background item to the user's Login Items, so do not register it without asking.
- **Helper protocol.** The app's `XPCSession` (`Services/PrivilegedHelperClient.swift`) talks to the helper's `XPCListener` on the Mach service `de.meandmymac.FileCraft.Helper`, and each side requires the other's code-signing identifier. Request and response types and `HelperIdentity` live in `Shared/HelperProtocol.swift`; bump `HelperIdentity.protocolVersion` when the format changes, because both sides refuse other versions. The helper returns error codes only and the app maps them to localized strings. Tests replace the transport with a mock `HelperTransport`. The helper logs under the subsystem `de.meandmymac.FileCraft.Helper`.
- **Previews compile in Release.** `#Preview` blocks are type-checked in every configuration, so the fixtures in `FileCraft/Sources/PreviewSupport/` must not be wrapped in `#if DEBUG`; otherwise Release builds and Xcode Cloud archives fail.
- **MainActor by default.** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` makes every declaration `@MainActor` unless marked `nonisolated`, including models and services. With `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `nonisolated async` functions still run on the caller's actor. File-system work such as enumeration, copying or hashing only leaves the main thread when marked `@concurrent`.
- **Member import visibility** (`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`). Each file must directly import every module whose extension members it uses; transitive imports don't count.
- **No App Sandbox.** `ENABLE_APP_SANDBOX = NO` with `ENABLE_HARDENED_RUNTIME = YES`, for Developer ID distribution (design decision D2 of `add-ui-specification`). Entitlements come from build settings; there is no `.entitlements` file. Privileged file operations go through the `SMAppService` helper daemon, never `SMJobBless`. Changing the sandbox or entitlements is a product decision, so ask first.
- **Sparkle (approved dependency exception, design D16).** The app target, and only it, links Sparkle 2.10.1 through Swift Package Manager: an exact pin in `project.pbxproj`, with `Package.resolved` committed. `release.yml` pins the same version for `generate_appcast`, so raise both together after reading Sparkle's release notes. `UpdaterModel` wraps `SPUStandardUpdaterController`. The test host creates no updater; Debug builds refuse scheduled checks (Check for Updates… still works), so they never offer a release in place of themselves. While operations run, an update's relaunch waits for the quit confirmation. `Info.plist` holds `SUFeedURL` (the `appcast` branch), `SUPublicEDKey` and `SUEnableAutomaticChecks`. Sparkle keeps its two settings under its own keys, which `SettingsKeys` lists so that Restore Defaults covers them. The private EdDSA key is in the owner's login keychain (Sparkle's `generate_keys`, account `ed25519`) and, for releases, in the `release` environment's secret `SPARKLE_ED_PRIVATE_KEY`; it never goes into the repository.
- **macOS only.** `SDKROOT` and `SUPPORTED_PLATFORMS` are `macosx`, the minimum system version is macOS 27.0 (no `#available` fallbacks), and the bundle identifier is `de.meandmymac.FileCraft`. `AppConfigurationTests` checks the bundle identifier and that the app runs unsandboxed.

## Source layout

Swift sources live in `FileCraft/Sources/`, one folder per layer: `Application/` (entry point, app delegate, launch restoration), `Models/` (value types and pure logic), `Services/` (file system, operation engine, helper client, Spotlight, volumes), `Stores/` (persisted settings and JSON stores; `SettingsKey` names the defaults keys), `ViewModels/` (`@Observable` models), `Views/` (one folder per feature) and `PreviewSupport/` (static preview fixtures). Tests in `FileCraftTests/` mirror these layers. The helper's own sources are in `FileCraftHelper/`, code it shares with the app in `Shared/`, and its launchd property list in `LaunchDaemons/`.

String Catalogs (`Localizable.xcstrings`, `InfoPlist.xcstrings`) live in `FileCraft/Resources/`. Write user-visible text in English in code, run the `-exportLocalizations` command above, add the German values, then run `LocalizationCoverageTests`. German strings follow the owner-approved glossary and rules in `docs/dev/LOCALIZATION.md`.

## Releases

`.github/workflows/release.yml` runs by hand (Actions > Release > Run workflow) and publishes version `<yyyy.mm.mr>`: year, two-digit month, and a counter that starts at 0 each month, one above the highest `rel-*` branch or `v*` tag of the month. It creates the branch `rel-<version>` from `main`, commits `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` for all targets, archives with Developer ID, notarizes and staples the app, adds it to the Sparkle appcast, then pushes the branch and creates the release `v<version>` with `FileCraft-<version>.zip`. The run's "Pre-release" switch makes it a GitHub pre-release on Sparkle's `beta` channel.

- The build number is the workflow's run number plus the variable `BUILD_NUMBER_OFFSET` of the GitHub environment `release`. GitHub raises the run number on every run, also runs that fail later, and never resets it. Re-runs keep their run number, so the workflow refuses them; start a new run. Renaming `release.yml` restarts the run numbers, so raise the offset then.
- The appcast lives on the branch `appcast`, which holds only `appcast.xml` and gains one commit per release; Sparkle's feed URL is `https://raw.githubusercontent.com/thbonk/FileCraft/appcast/appcast.xml`. The workflow runs Sparkle's `generate_appcast` (version and SHA-256 pinned in the workflow) on the previous appcast plus the new archive. Never edit the branch by hand.
- The signing, notarization and Sparkle secrets live in the `release` environment; the workflow's header lists them. The app's `Info.plist` has `SUPublicEDKey`, so every release EdDSA-signs its appcast entry and fails without `SPARKLE_ED_PRIVATE_KEY`. Export that key into a file for `gh secret set`, never with `generate_keys -x /dev/stdout`: generate_keys refuses an existing path and prints an error that a pipe would store as the secret. The workflow's first step checks the key's format.
- The branch is pushed only after notarization succeeded, so a failed run leaves no branch or release behind, only a used build number.

## Spec-driven workflow (OpenSpec)

Feature work is planned with OpenSpec (`openspec` CLI, schema `spec-driven`, project context and rules in `openspec/config.yaml`):

- `/opsx:explore` thinks a change through. `/opsx:propose` creates `openspec/changes/<name>/` with proposal, design, delta specs and tasks. `/opsx:update` revises it.
- `/opsx:apply` implements the change's `tasks.md`.
- `/opsx:archive` moves a finished change to `openspec/changes/archive/` and merges its delta specs into `openspec/specs/`, the spec of current behavior. `/opsx:sync` merges the specs without archiving.
- CLI: `openspec list` (changes), `openspec list --specs`, `openspec show <name>`, `openspec validate <name>`.

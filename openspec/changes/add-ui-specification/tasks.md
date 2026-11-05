## 1. Project setup

- [x] 1.1 Restrict the target to macOS: set `SUPPORTED_PLATFORMS = macosx`, remove the iOS and visionOS deployment targets, `TARGETED_DEVICE_FAMILY` and `UI*` Info.plist keys, and confirm the build still succeeds
- [x] 1.2 Set the bundle identifier to `de.meandmymac.FileCraft`, replacing the template's `devplaceholder.*` value
- [x] 1.3 Turn off the App Sandbox, remove `ENABLE_USER_SELECTED_FILES`, enable Hardened Runtime, and confirm with `codesign -d --entitlements` that the built app has no sandbox entitlement
- [x] 1.4 Add `de` to the project's known regions and create `Localizable.xcstrings` and `InfoPlist.xcstrings`
- [x] 1.5 Add the Swift Testing target `FileCraftTests`, enable it in the scheme's test action, and update the test commands in `CLAUDE.md`
- [x] 1.6 Create the source layer folders (`Models`, `ViewModels`, `Services`, `Views/<Area>`) under `FileCraft/Sources/` and add the required file header to all existing source files
- [x] 1.7 Create `docs/dev/LOCALIZATION.md` with the seed glossary from the design, exclude it from the app target's membership, and have the owner approve the glossary before any German string is written
- [x] 1.8 Create static preview fixtures (sample `FileItem`s, volumes, tags) usable by `#Preview` blocks in English and German

## 2. Core models and services

- [x] 2.1 Implement `FileReference` (bookmark data plus last known path, `Codable`, `Hashable`) with resolution and refresh, with tests for rename and move
- [x] 2.2 Implement `FileItem` and `FileSystemService` enumeration as `@concurrent` code that prefetches localized name, hidden, package, tags, sizes and dates, with tests on temporary folders
- [x] 2.3 Implement `DirectoryWatcher` (FSEvents bridged to a debounced `AsyncStream`), with a test that a new file is reported within one second
- [x] 2.4 Implement `VolumeMonitor` for mount and unmount events, capacity and eject capability
- [x] 2.5 Implement `Location` and `NavigationHistory` (back, forward, discarding forward history, history menu entries), with tests
- [x] 2.6 Implement `SettingsKey` and `SettingsStore` with every default from the settings spec
- [x] 2.7 Implement sorting and grouping (localized standard comparison, Folders First, group keys), with tests for numeric order and German umlauts
- [x] 2.8 Implement `ThumbnailService` and `FolderSizeService` with caching and cancellation
- [x] 2.9 Implement the unique-name generator with localized suffixes and numbering, with tests in English and German

## 3. Browser window shell

- [x] 3.1 Implement `BrowserWindowModel`, `PaneModel` and `TabModel` as `@Observable` view models
- [x] 3.2 Build the browser `WindowGroup` with `NavigationSplitView`, inspector and shelf areas and the active pane, and turn off automatic window tabbing
- [x] 3.3 Build the path bar: breadcrumbs, overflow menu, subfolder menus and edit mode
- [x] 3.4 Build the status bar: item counts, selection size, available space and filter state
- [x] 3.5 Build the customizable toolbar with `toolbar(id:)`, all specified items and the default set
- [x] 3.6 Implement the View menu layout toggles and resizable areas with sizes persisted per window
- [x] 3.7 Implement window state snapshots in `@SceneStorage`, restoration with nearest-ancestor fallback, and the restoration setting
- [x] 3.8 Publish window and pane models as `@FocusedValue` entries for menu commands
- [ ] 3.9 Verify manually that sidebar and inspector widths persist across relaunches, which SwiftUI manages itself

## 4. File views

- [x] 4.1 Prototype list view with SwiftUI `Table` on 10,000 items, measure time to first rows, scrolling, inline rename and type-select, and record in `design.md` whether SwiftUI suffices or an approved AppKit fallback is needed
- [x] 4.2 Build list view: optional columns, column customization, header sorting and hierarchical rows
- [x] 4.3 Build icon view: reflowing grid, icon sizes, label position, item info, thumbnails and rubber-band selection
- [x] 4.4 Build column view with the preview column
- [x] 4.5 Implement the shared selection model (click, ⇧, ⌘, Select All, Deselect All, Invert Selection), with tests
- [x] 4.6 Implement keyboard navigation and type-to-select, including the Return key setting
- [x] 4.7 Implement the shared inline rename editor with inline validation messages
- [x] 4.8 Implement item presentation: localized names, extension visibility, link badges, tag dots and relative dates
- [x] 4.9 Implement the hidden files and package contents toggles and the folder size column
- [x] 4.10 Integrate Quick Look with selection following
- [x] 4.12 Apply live updates from `DirectoryWatcher` while preserving selection and scroll position
- [x] 4.13 Implement empty, loading and error states with their actions
- [x] 4.14 Implement grouping with localized section headers
- [x] 4.15 Build the view options panel (⌘J) with "Use as Defaults"
- [ ] 4.16 Verify manually in the running app: smooth scrolling through 10,000 items, type-to-select and inline rename inside the list view

## 5. Navigation

- [x] 5.1 Implement Back and Forward commands and the toolbar item with the press-and-hold history menu
- [x] 5.2 Implement Enclosing Folder and Open Selection
- [x] 5.3 Implement the Go menu's standard locations, including the ⌥ Library item and iCloud Drive visibility
- [x] 5.4 Build the Go to Folder sheet with completion, recent entries, file targets and inline errors, with path parsing tests
- [x] 5.5 Implement Copy Path and Copy Path As, with tests for each format and shell escaping
- [x] 5.6 Implement the recent folders store and menu
- [x] 5.7 Implement Open With, Show Original, Reveal in Finder and Open in Terminal
- [x] 5.8 Handle Dock drops and folder open requests through SwiftUI's open-URL handling (`onOpenURL`, `handlesExternalEvents`) and the document types in `Info.plist`

## 6. Sidebar

- [x] 6.1 Build the sidebar sections with persisted collapse state and visibility settings
- [x] 6.2 Implement `FavoritesStore` with bookmarks, adding (including ⌃⌘T), removing and reordering
- [x] 6.3 Show volumes in Locations with eject buttons, capacity tooltip, optional usage bar and busy-volume alerts
- [x] 6.4 Add the iCloud and Tags sections, with the tag location backed by a Spotlight query
- [x] 6.5 Implement sidebar drop targets for tagging and for adding favorites, and unavailable favorites (move and copy drops on folder and volume entries are part of 9.19)

## 7. Tabs and dual pane

- [x] 7.1 Build the tab bar with New Tab, Close Tab, Close Other Tabs, tooltips and the visibility rule
- [x] 7.2 Implement tab switching shortcuts, drag reordering and moving tabs between panes
- [x] 7.3 Implement Recently Closed Tabs and Reopen Closed Tab
- [x] 7.4 Implement Dual Pane with both layouts, Equalize Pane Sizes, Swap Panes and preserved tabs of the hidden pane
- [x] 7.5 Implement active pane indication and Tab-key focus switching
- [x] 7.6 Implement the cross-pane commands Show Same Folder in Other Pane and Open in Other Pane (Copy and Move to Other Pane and the function keys are task 9.20)

## 8. Inspector and info windows

- [x] 8.1 Build the inspector panel bound to the active pane's selection
- [x] 8.2 Build the Preview section with a `QLPreviewView` wrapper
- [x] 8.3 Build the General section with the editable name and background item counts
- [x] 8.4 Build the Tags section with suggestions
- [x] 8.5 Build the Permissions section with mode toggles, octal value, read-only ACL list and Apply to Enclosed Items
- [x] 8.6 Build the Open With section including Change All
- [x] 8.7 Build the Attributes and Extended Attributes sections
- [x] 8.8 Build the multiple-selection summary with mixed-state editing
- [x] 8.9 Implement Get Info windows with `WindowGroup(for: FileReference.self)` and the confirmation above ten items

## 9. File operations
 
- [x] 9.1 Implement the `FileOperationEngine` actor with per-volume queues, progress streams and pause, resume and cancel
- [x] 9.2 Implement copying with `copyfile(3)` (cloning, metadata, progress, cancellation), with integration tests
- [x] 9.3 Implement moving within and across volumes, with tests for interrupted moves
- [x] 9.4 Build the conflict dialog (Replace, Keep Both, Skip, Stop, Merge, apply to all), with policy tests
- [x] 9.5 Implement per-item error handling (Skip, Retry, Stop) and the completion summary
- [x] 9.6 Implement New Folder, New Folder with Selection and New Text File
- [x] 9.7 Implement rename with validation and the extension change confirmation
- [x] 9.8 Implement Duplicate, Make Alias and Make Symbolic Link
- [x] 9.9 Implement Copy, Cut, Paste and Move Items Here for files
- [x] 9.10 Implement Copy To… and Move To… with the destination chooser
- [x] 9.11 Implement Move to Trash with Put Back records, Delete Immediately and Empty Trash
- [x] 9.12 Implement Compress and Expand through `ArchiveService` using `ditto` and `tar`, with tests for every format
- [x] 9.13 Implement Eject, including switching affected panes to the home folder
- [x] 9.14 Register named undo and redo actions for every operation
- [x] 9.15 Implement copy verification with CryptoKit checksums
- [x] 9.16 Build the Operations window and toolbar progress item, including automatic opening after five seconds
- [x] 9.17 Implement the quit confirmation while operations run
- [x] 9.18 Implement the safety checks (folder into itself, symbolic links in recursive operations), with tests
- [x] 9.19 Implement drag and drop with copy, move and alias semantics, path bar and sidebar drop targets (folders and volumes) and spring-loaded folders (moved from 4.11 and 6.5; needs the operation engine)
- [x] 9.20 Implement Copy to Other Pane (F5) and Move to Other Pane (F6) and the F5 to F8 function keys with their setting, active only while a file view has keyboard focus (moved from 7.6)

## 10. Privileged helper (SMAppService)

- [x] 10.1 Add the `FileCraftHelper` command-line target embedded at `Contents/MacOS/FileCraftHelper` and its launchd property list `Contents/Library/LaunchDaemons/de.meandmymac.FileCraft.Helper.plist` (`Label`, `BundleProgram`, `MachServices`, `AssociatedBundleIdentifiers`), and verify the bundle has no `SMPrivilegedExecutables` key
- [x] 10.2 Implement `PrivilegedHelperClient` on `SMAppService.daemon(plistName:)` for register, unregister and status
- [x] 10.3 Build the approval flow: explanation sheet, Open System Settings via `SMAppService.openSystemSettingsLoginItems()`, status re-check on activation and resuming the pending operation
- [x] 10.4 Implement the XPC transport with peer code-signing requirements on both sides and a versioned `Codable` protocol
- [x] 10.5 Implement authorization: the helper defines its admin right with a 300-second timeout, the app obtains and reuses it for at most five minutes, and the helper verifies it per request
- [x] 10.6 Implement the helper's typed operations (list, create folder, copy, move, rename, delete, owner and group, mode, flags) with file-descriptor-based path validation and no command execution
- [x] 10.7 Report progress and support cancellation for privileged copy, move and delete through the operation queue
- [x] 10.8 Implement protocol version checks with re-registration and private unified logging in the helper
- [x] 10.9 Connect "Authenticate and Retry", "Authenticate to View" and inspector permission edits to the helper
- [ ] 10.10 Add protocol tests against a mock transport and test registration, approval and removal manually on a clean user account

## 11. Shelf

- [x] 11.1 Implement `ShelfStore` with bookmarks and persistence
- [x] 11.2 Build the shelf panel with drop target, dimmed missing items and context actions
- [x] 11.3 Implement Copy and Move Items to Current Folder and dragging out, including the remove-after-drag setting

## 12. Search and filter

- [x] 12.1 Implement the quick filter with case- and diacritic-insensitive matching, with tests
- [x] 12.2 Implement search scopes and the search results location in the tab history
- [x] 12.3 Implement recursive search with streamed results, a running count and Stop
- [x] 12.4 Implement Spotlight search with `NSMetadataQuery` and live result updates
- [x] 12.5 Build the criteria rows and the hidden items and package contents options
- [x] 12.6 Implement Select by Pattern with wildcards and regular expressions, with tests
- [x] 12.7 Implement recent searches in the search field menu

## 13. Batch rename

- [x] 13.1 Implement the rename rule engine (eight rule types and three targets) as value types, with tests for each rule
- [x] 13.2 Implement batch validation (empty, invalid characters, length, duplicates on case-insensitive volumes, collisions), with tests
- [x] 13.3 Build the batch rename sheet with rule editor and live preview, meeting 100 ms for 1,000 items
- [x] 13.4 Implement item ordering options for sequence and date rules
- [x] 13.5 Implement execution with temporary names for swaps, rollback on failure and a single undo step, with tests
- [x] 13.6 Implement rename presets with persistence

## 14. Settings

- [ ] 14.1 Build the `Settings` scene with all nine panes and Restore Defaults per pane
- [ ] 14.2 Build the General, Browser, Sidebar and Tabs & Panes panes; the "Restore windows" toggle calls `SettingsStore.applyWindowRestoration()` when it changes
- [ ] 14.3 Build the File Operations and Compression panes
- [ ] 14.4 Build the Integration pane: terminal chooser, the default file viewer toggle (`NSFileViewer` plus the `public.folder` handler, restoring Finder when turned off, with a drift check on launch) and shelf behavior
- [ ] 14.5 Build the Helper and Advanced panes (size units, Reset Warnings, Reset All Settings)

## 15. Menus and shortcuts

- [ ] 15.1 Build the menu bar in the specified structure with command validation and state-dependent titles
- [ ] 15.2 Assign the default shortcut table with keyboard-layout adaptation and check it against macOS system shortcuts
- [ ] 15.3 Build the context menus for items, background, sidebar, tabs, path bar and shelf
- [ ] 15.4 Build the Keyboard Shortcuts window with search
- [ ] 15.5 Build the Dock menu

## 16. Onboarding

- [ ] 16.1 Build the welcome window with its steps and first-launch logic
- [ ] 16.2 Implement the Full Disk Access probe, status refresh on activation and the settings deep link
- [ ] 16.3 Add the default file viewer step and reopening from Help and Settings

## 17. Software updates (Sparkle)

- [ ] 17.1 Add Sparkle 2 through Swift Package Manager with a pinned version and record the approved exception in `docs/dev/DEVELOPMENT_GUIDELINES.md`
- [ ] 17.2 Create the EdDSA key pair with Sparkle's `generate_keys`, keep the private key in the keychain, and set `SUPublicEDKey` and the HTTPS `SUFeedURL` (design open question 1)
- [ ] 17.3 Implement the `@Observable` `UpdaterModel` around `SPUStandardUpdaterController` with the Check for Updates… command and the two General settings toggles
- [ ] 17.4 Verify that installing an update while operations run shows the quit confirmation
- [ ] 17.5 Test the update flow with a local signed test appcast: an older build updates to the current one, and a tampered archive is rejected

## 18. Localization

- [ ] 18.1 Translate all strings into German following the owner-approved glossary, with translator comments for ambiguous keys
- [ ] 18.2 Add plural variants for all count-dependent strings
- [ ] 18.3 Add the localization coverage test that fails on missing or stale German translations
- [ ] 18.4 Test generated names and value formatting under the German locale
- [ ] 18.5 Run German and double-length pseudolanguage passes and fix all truncation
- [ ] 18.6 Localize the Info.plist strings and map helper error codes to localized messages
- [ ] 18.7 Have the owner spot-check the German UI and apply the reported corrections

## 19. Appearance and accessibility

- [ ] 19.1 Audit all bundle resources: SF Symbols, system icons, original assets and approved-dependency assets only
- [ ] 19.2 Check dark mode, Increase Contrast, Reduce Transparency and Reduce Motion across all windows
- [ ] 19.3 Apply the browser text size setting to file views, sidebar and inspector
- [ ] 19.4 Add VoiceOver labels, file item descriptions, accessibility actions and operation announcements
- [ ] 19.5 Verify Full Keyboard Access focus order and visible focus indication
- [ ] 19.6 Add non-color cues for tags, the active pane and errors
- [ ] 19.7 Integrate the owner-provided Icon Composer `.icon` file as the app icon (waits for delivery; no placeholder artwork)

## 20. Verification

- [ ] 20.1 Build with `xcodebuild` and run the full Swift Testing suite
- [ ] 20.2 Profile with Instruments (hangs and hitches) on a 10,000-item folder and during large copies
- [ ] 20.3 Walk through every spec scenario in English and German and record the results
- [ ] 20.4 Notarize a Developer ID build, publish its signed appcast, and verify Gatekeeper, the update flow, helper approval and Full Disk Access on a clean user account
- [ ] 20.5 Update `CLAUDE.md` with the new targets, test commands, helper, update and localization workflows

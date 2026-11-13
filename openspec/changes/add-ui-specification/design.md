## Context

FileCraft is a SwiftUI app (Swift 6 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency, deployment target macOS 27.0) that currently contains only the Xcode template. The template's build settings enable the App Sandbox with read-only access to user-selected files and list iOS and visionOS as supported platforms. The development guidelines require SwiftUI with `@Observable` view models (MVVM), `NavigationStack`/`NavigationSplitView` with value-based routing, `#Preview` blocks with static mock data, structured concurrency without GCD, and no third-party dependencies without approval.

### Reference analysis of Path Finder

Path Finder 26.1.10 (build 2669, minimum macOS 13) was analyzed statically on this machine. Nothing was decompiled, the app was not launched, and no extracted material is stored in the repository. Sources were the Info.plist, the code-signing entitlements, the decoded main menu (8 menus, about 300 items with selectors and shortcuts), the English string tables of the app and its frameworks, and the inventory of 40 plug-in bundles typed as modules, menu plug-ins or task plug-ins. Findings that shaped this design:

- **Distribution**: not sandboxed (only Apple Events, Contacts and Photos entitlements), with privileged helpers installed through the legacy `SMPrivilegedExecutables` mechanism, an XPC file service, a Full Disk Access onboarding view and Sparkle updates.
- **Browser**: icon, list and column views; tabs; a "dual browser" with function-key commands (copy, move, compress, decompress and compare to the other pane); shelves on all four window edges hosting modules; bookmarks bar, path navigator, status bar and a toggleable title bar; view options such as relative dates, folder size calculation, icon previews and smart sorting.
- **Information modules**: info, preview, permissions, ACL, size, tags, Open With and attributes, plus modules for recent folders, recent documents, selection path, processes, terminal, hex view, Git status, trash and a temporary holding stack.
- **Tools**: batch rename with eight rule types (replace text, regular expression, insert text, change case, sequence, date and others), folder compare and sync, duplicate finder, size browser, archives in about eleven formats, checksums, disk images, burning, RAM disk, screen capture, image conversion, uploads, Dropbox sharing, reports, secure delete, "launch as root" and a rich-text editor.
- **Preferences**: around fifteen areas, including launch behavior, default file browser, appearance and colors, key actions for Return and Enter, spring-loaded folders, sidebar, size units (base 10 or base 2), compression, file comparison tool, text editor, terminal, keyboard shortcuts and global hot keys.
- **Localization**: about 20 languages, including German.

## Goals / Non-Goals

**Goals:**

- Provide a complete, testable UI specification for FileCraft 1.0 across the sixteen capabilities in the proposal.
- Fix the architecture needed to implement it in SwiftUI under the project's guidelines and concurrency settings.
- Ship English and German from the first implemented screen.
- Perform privileged operations through an `SMAppService` daemon with a minimal, verified interface.

**Non-Goals:**

- Parity with Path Finder's look, names or behavior, and any reuse of its code, assets or text.
- The deferred and unplanned features listed in the proposal and in the roadmap below.
- Mac App Store distribution, sandbox compatibility and other platforms.

## Decisions

### D1: Original product design informed by the inventory

The analysis is used only as a feature map. Concepts get FileCraft names and FileCraft behavior:

| Path Finder concept | FileCraft concept |
|---|---|
| Dual browser | Dual Pane with an active pane |
| Path navigator | Path Bar |
| Temporary holding stack | Shelf, shared by all windows |
| Shelves with modules on four edges | Inspector (trailing) and Shelf (bottom) in 1.0; configurable panels later |
| Summary info | Inspector multiple-selection summary |
| Commands menu | Tools menu, with file commands in the File menu as in Finder |

Shortcuts follow Finder where Finder defines one, and the classic dual-pane convention (F5 copy, F6 move, F7 new folder, F8 trash) for pane commands.

Alternative considered: mirroring Path Finder's layout and terminology. Rejected because the user asked for FileCraft's own UI, it raises trademark and trade-dress concerns, and Finder conventions are what most users already know.

### D2: Unsandboxed Developer ID distribution with Hardened Runtime

Set `ENABLE_APP_SANDBOX = NO`, remove `ENABLE_USER_SELECTED_FILES`, enable Hardened Runtime and distribute notarized Developer ID builds. A Finder replacement must browse arbitrary locations, write to them, register a privileged helper and act as the default file viewer; the sandbox prevents all of these, and Path Finder ships unsandboxed for the same reasons.

Alternative considered: sandbox with user-selected folders and security-scoped bookmarks. Rejected because every new location would need a user grant, writes outside grants fail, and Mac App Store distribution is not a goal.

### D3: macOS-only target

Set `SUPPORTED_PLATFORMS = macosx`, drop the iOS and visionOS deployment targets, device families and `UI*` Info.plist keys, and replace the template's `devplaceholder.*` bundle identifier with `de.meandmymac.FileCraft`, which the helper's code-signing requirement depends on. The minimum system version stays macOS 27.0, so no `#available` fallbacks are written.

### D4: Scene structure

| Scene | Purpose |
|---|---|
| `WindowGroup(id: "browser")` | Browser windows; window state in `@SceneStorage` as an encoded snapshot |
| `WindowGroup(id: "info", for: FileReference.self)` | Get Info windows, one per item, opened with `openWindow(id:value:)` |
| `Window(id: "operations")` | Operations window; it hosts the conflict, error and summary sheets of all operations and the quit confirmation. Browser windows hand `OperationQueueModel` their `openWindow` action, so that the window also opens without a view at hand: for a question, an error summary, after five seconds (setting) and when the user quits. Its automatic menu command is removed, so that Window > Operations sits after the tab commands |
| `Window(id: "welcome")` | Onboarding |
| `Window(id: "shortcuts")` | Keyboard Shortcuts reference |
| `Settings` | Settings window with one tab per pane |
| `UtilityWindow(id: "viewOptions")` | View Options panel; it receives the main window's focused values. Its automatic menu command is removed (`commandsRemoved()`), because it is a generic "Show Window" without a shortcut; View > Show View Options (⌘J) opens it with `openWindow(id:)` |

Menus are built with `.commands` (`CommandMenu` for Go and Tools, `CommandGroup` replacements elsewhere). The system's Cut, Copy, Paste and Select All stay, because file views copy and paste through `.copyable`, `.cuttable` and `.pasteDestination`, which use them; FileCraft's Edit commands therefore follow Select All. FileCraft replaces the system's sidebar command group with its own Show Sidebar (⌃⌘S), so that the view commands come before the system's toolbar commands, as the menus spec orders them. `ShortcutCatalog` holds the default shortcut table for the Keyboard Shortcuts window, and a test compares it with the live menu bar; keys that move between keyboard layouts are adapted by macOS (`allowsAutomaticKeyEquivalentLocalization`). Commands reach the frontmost window through `@FocusedValue` entries that publish the window's `@Observable` model, never closures. Folder open requests and Dock drops use SwiftUI's `onOpenURL` with `handlesExternalEvents`, because SwiftUI then creates a browser window when none is open, which an application delegate cannot do; the `Info.plist` declares `public.folder` (Viewer, rank Alternate) and `public.item` (rank None, so that dropped files are accepted without FileCraft being offered for opening files). The Dock menu and quit confirmation use an `@NSApplicationDelegateAdaptor`, because SwiftUI has no API for them.

`FileReference` is a `Codable`, `Hashable` value holding bookmark data and the last known path, so that windows and stores survive renames and moves.

### D5: Model and service layering

View models are `@Observable` classes, implicitly `@MainActor` under the project's default isolation:

- `BrowserWindowModel` owns one or two `PaneModel`s, the active pane, and layout state (sidebar, inspector, shelf, sizes).
- `PaneModel` owns its `TabModel`s and the current tab.
- `TabModel` owns the `Location`, the `NavigationHistory`, `ViewSettings` and the `SelectionModel`, and observes a `DirectoryListing`.
- App-wide stores: `SettingsStore`, `FavoritesStore`, `ShelfStore`, `RecentsStore`, `OperationQueueModel`, and `SidebarSources`, which loads the mounted volumes and the tags once at launch for the sidebars of all windows and keeps the volumes current.

Services hold no UI state and are `nonisolated` types or actors: `FileSystemService` (enumeration and metadata), `DirectoryWatcher` (FSEvents), `VolumeMonitor` (`NSWorkspace` mount notifications), `ThumbnailService` (`QLThumbnailGenerator`), `FolderSizeService`, `FileOperationEngine` (actor), `SearchService` (`NSMetadataQuery` and recursive enumeration), `ArchiveService` (system tools) and `PrivilegedHelperClient`. They exchange `Sendable` value types (`FileItem`, `FileReference`, `OperationProgress`).

Alternative considered: views reading services directly. Rejected because selection, history and multi-pane state must be testable without views.

Implementation note (shelf): `ShelfStore` keeps `ShelfItem`s, each a `FileReference` bookmark, in a versioned `Shelf.json` in Application Support, as `FavoritesStore` does. It skips items it already holds and resolves its bookmarks when the shelf appears, when the window becomes active and when an operation ends; unresolvable items are dimmed. A move to another volume is a copy and a delete, which a bookmark cannot follow, so Move Items to Current Folder points the moved items to the destinations the engine reports (`relocate`). The shelf view keeps its selection and Quick Look state locally. Dragged shelf items carry their paths as IDs, as file view items do, so drop targets apply the same move-or-copy rules; with the remove-after-drag setting on, `onDragSessionUpdated` removes the items once a drag ends with an accepted operation. Drops of items that are all on the shelf already show the forbidden cursor, so dragging within the shelf never counts as dragging out.

### D6: Concurrency under default MainActor isolation

Because every declaration is `@MainActor` by default and `nonisolated async` functions run on the caller's actor, all I/O is placed in `@concurrent` functions or actors. Long-running results are streamed to models with `AsyncStream`, and view-bound work starts in `.task` modifiers so that navigation cancels it. GCD is not used; FSEvents callbacks are delivered on a dedicated queue only inside the watcher, which bridges them into an `AsyncStream`. One exception to `@concurrent`: each running file operation (D10) gets a thread of its own, because its copy blocks while it is paused or waits for the user's answer, and that must not occupy a thread of the cooperative pool.

### D7: Folder navigation as model state

`NavigationSplitView` provides the sidebar and content columns, and sidebar selection is value-based (`SidebarItem`). Folder navigation inside a tab is a `Location` value (`.folder(FileReference)`, `.computer` for the list of mounted volumes that Go > Computer and Enclosing Folder of a volume show, `.search(SearchQuery)`, `.tag(String)`) managed by `NavigationHistory`. `NavigationStack` is not used for folders, because back and forward history branches, the path bar jumps to arbitrary ancestors, and column view shows several levels at once. This keeps the guideline's value-based routing without a push/pop stack.

### D8: File view implementation

- **List view**: SwiftUI `Table` with `KeyPathComparator` sorting, `TableColumnCustomization` for column visibility and order, `DisclosureTableRow` for inline expansion, `contextMenu(forSelectionType:menu:primaryAction:)` for selection-aware menus and double-click, and a `TextField` cell for inline rename.
- **Icon view**: `LazyVGrid` in a `ScrollView` with a custom selection model, `focusable()` and `onKeyPress` for arrow keys (including ⇧ to extend, which `onMoveCommand` does not report), Return, Space and type-select, and a drag gesture for rubber-band selection.
- **Column view**: a horizontal `ScrollView` of per-level `List(selection:)` columns plus a preview column.
- **Sidebar**: a `List` with value-based selection. It starts only once favorites, volumes and tags are loaded, because sections that change while the list's first rows are still being inserted make SwiftUI update the underlying outline view from inside a delegate call, which AppKit reports as a reentrant operation that is to become an assertion.
- **Drag and drop**: `Transferable` file URLs with `draggable` and a `DropDelegate` that returns `DropProposal(operation:)` to show copy, move or alias feedback; spring-loading uses a timer started in `dropEntered`.
- **Pasteboard**: `copyable`, `cuttable` and `pasteDestination` modifiers.
- **Quick Look**: `quickLookPreview(_:in:)`.

Task 4.1 benchmarks `Table` with 10,000 rows, inline rename and type-select first. If it fails the `file-views` performance requirement, list view alone may wrap `NSTableView`/`NSOutlineView`, which needs the user's approval under the guidelines.

Result of task 4.1 (2026-10-30, unoptimized debug build): filtering, sorting and flattening 10,000 rows takes 20 ms and the first layout of the table 64 ms, well within the 500 ms requirement. List view therefore stays in SwiftUI. Hierarchical rows are flattened by FileCraft (`OutlineRows`) instead of using `DisclosureTableRow`, because recursive row builders are not expressible with opaque types and children load lazily. Scrolling, type-select and inline rename inside the running table are checked manually (task 4.16).

### D9: Required AppKit interop

The guidelines allow AppKit only when required. This design requires exactly these touch points; anything else needs separate approval:

| Need | AppKit API | Reason |
|---|---|---|
| Dock menu, quit confirmation | `NSApplicationDelegateAdaptor` | No SwiftUI equivalent. While operations run, the delegate answers `.terminateLater` and calls `reply(toApplicationShouldTerminate:)` later; the confirmation itself is a SwiftUI alert in the Operations window (decided by the project owner on 2026-11-03) |
| No system window tabs | `NSWindow.allowsAutomaticWindowTabbing = false` | Tabs live in panes |
| Inline previews in inspector and column view | `QLPreviewView` in `NSViewRepresentable` | SwiftUI offers only the Quick Look panel |
| Icons, Open With, eject, recycling, tag colors | `NSWorkspace` | Non-view system services |
| Space opens a hovered folder at once during a drag | `NSEvent.addLocalMonitorForEvents` | SwiftUI delivers no key events while a drag hovers a drop target; the monitor exists only while a spring-loading folder is targeted (approved by the project owner on 2026-11-04). The ⌥, ⌘ and ⌥⌘ drop semantics come from `DropSession.suggestedOperations`, so `NSEvent.modifierFlags` is not needed for drops |
| Copy Path and Copy Path As; reading file references for Move Items Here | `NSPasteboard` | SwiftUI has no API to write or read the pasteboard from a menu command on macOS; approved by the project owner on 2026-10-31, reading added on 2026-11-04. Cut, Copy and Paste of files themselves use SwiftUI's `copyable`, `cuttable` and `pasteDestination` on the file view, so that text fields keep their own copy and paste |

### D10: File operation engine

`FileOperationEngine` is an actor that runs one queue per volume and reports `OperationProgress` through `AsyncStream`.

- **Copy**: `copyfile(3)` per item with `COPYFILE_ALL`, `COPYFILE_NOFOLLOW`, `COPYFILE_EXCL` and `COPYFILE_CLONE`, so APFS clones are used where possible and symbolic links stay links. The engine walks folders itself, in name order, so that every item, also inside folders, can be retried, skipped or merged; a folder's metadata and dates are applied with `COPYFILE_METADATA` after its contents. A status callback reports data progress and holds the copy while paused. Copy verification hashes files with CryptoKit. (Changed from `COPYFILE_RECURSIVE` by the project owner on 2026-11-03, because recursion offers no retry for items inside folders and no merge.)
- **Move**: `rename(2)` within a volume, copy then delete across volumes; a source is deleted only when everything inside it was copied.
- **Questions**: a conflict or a failed item blocks the operation's thread until the user answers in the Operations window (`OperationControl.ask`). Answers for all conflicts apply to later conflicts of the same kind; Replace never applies across a file and a folder, so that the dialog appears for them every time. Replace moves the existing item to the Trash. Cancelling or Stop removes the partial copy.
- **Threads**: each running operation works on a thread of its own (exception to D6); operations on the same volume run one after another, different volumes in parallel.
- **Trash and Put Back**: `NSWorkspace.recycle`, so that Finder's Put Back keeps working too; FileCraft records the original locations in `PutBackStore` (JSON in Application Support) for its own Put Back. Delete Immediately and Empty Trash are `delete` operations of the queue: the engine deletes folder contents first, never follows symbolic links, and offers Skip, Retry and Stop per item. Empty Trash deletes the contents of the user's Trash folders on all volumes itself (decided by the project owner on 2026-11-04); reading the home Trash needs Full Disk Access, which FileCraft explains with a link to System Settings.
- **Aliases**: bookmark files written with `URL.writeBookmarkData`. Symbolic links hold the absolute path of the original (decided by the project owner on 2026-11-04).
- **Archives**: `/usr/bin/ditto` for Finder-compatible ZIP files, `/usr/bin/tar` for the tar formats and `/usr/bin/gzip` for single gzip files, run with `Process` as `compress` and `expand` operations of the queue; pausing suspends the tool, cancelling terminates it and removes the partial archive. Several items are cloned into a hidden folder on the destination's volume first, so that they sit at the archive's top level as in Finder's "Archive.zip". Archives expand into a hidden folder in the destination, and each top-level item then moves in under a free name. Undoing Expand moves the expanded items to the Trash and puts back an archive that the setting moved there.
- **Drag and drop**: SwiftUI's drag containers (`dragContainer`, `draggable(containerItemID:)`, `dragContainerSelection`) in icon and column view and `TableRow.draggable` in list view drag file URLs, so that Finder and other applications accept them; dragging a selected item drags the selection. Folders in all views, the file view background, path bar segments and sidebar folders and volumes are drop targets (`dropDestination` with a `DropSession` and `dropConfiguration` for the cursor). `DropPolicy` decides: move on the same volume, copy across volumes, ⌥ copy, ⌘ move, ⌥⌘ aliases; a folder into itself is refused with the reason. Hovering a folder opens it after the spring-loading delay, or at once with Space.
- **Undo**: every completed operation registers its inverse with the window's `UndoManager` through `FileUndoRegistrar`. Undoing registers the opposite action at once, so that it becomes the redo action, and the file work follows through a serial `FileUndoQueue`. Undoing a creation or copy moves the created items to the Trash, so Undo never deletes anything; undoing a move moves the items back to their original places and names (renames within a volume, the queue across volumes), using the source-to-destination pairs the engine reports as `transfers`. Items merged into an existing folder are left out, because moving that folder back would move content that was there before. Paste moves instead of copying when it pastes exactly the items cut last (`FileClipboard`, which also dims them). F5 and F6 are the shortcuts of Tools > Copy and Move to Other Pane, present only while a file view has focus and the function-key setting is on; F7 and F8 go through the file view's key handler. ⌘⌫ and ⌥⌘⌫ act only while a file view has focus (`focusedFileTab`), so that they never trash files while a text field is edited.

Alternative considered: `FileManager.copyItem`. Rejected because it offers no progress or cancellation within large files and no clone control.

### D11: Privileged helper through SMAppService

This decision was set by the user.

- **Targets**: a new command-line target `FileCraftHelper`, embedded at `Contents/MacOS/FileCraftHelper`, and a launchd property list at `Contents/Library/LaunchDaemons/de.meandmymac.FileCraft.Helper.plist` whose `Label` and Mach service are `de.meandmymac.FileCraft.Helper`, with `BundleProgram` and `AssociatedBundleIdentifiers` set to `de.meandmymac.FileCraft`.
- **Lifecycle**: the app uses `SMAppService.daemon(plistName:)` for `register()`, `unregister()` and `status`, and opens approval settings with `SMAppService.openSystemSettingsLoginItems()`.
- **IPC**: the Swift `XPC` framework (`XPCSession`/`XPCListener` with `Codable` messages) with peer code-signing requirements based on team identifier and bundle identifier. If peer requirements turn out insufficient, `NSXPCConnection` with `setCodeSigningRequirement(_:)` is the fallback.
- **Authorization**: the helper defines the right `de.meandmymac.FileCraft.helper.file-operations` (rule "authenticate as admin", 300-second timeout) when it first starts. The app obtains it with `AuthorizationCopyRights` and passes the external form with each request, and the helper verifies it per request.
- **Interface**: typed requests only (list, create folder, copy, move, rename, delete, set owner and group, set mode, set flags), each carrying a protocol version. Paths are opened with `O_NOFOLLOW` and file-descriptor-relative calls to avoid races with symbolic links.

- **Project layout** (implemented 2026-11-05): the helper's sources live in `FileCraftHelper/` and the protocol shared with the app in `Shared/`, a synchronized folder of both targets whose types are all `nonisolated`. The app target depends on the helper, copies it with an "Embed Privileged Helper" phase (executables, code-signed on copy) and the property list from `LaunchDaemons/` with a "Copy Launch Daemon" phase. The helper is signed with the identifier `de.meandmymac.FileCraft.Helper` and the Hardened Runtime. Both peer requirements use `XPCPeerRequirement.isFromSameTeam(andMatchesSigningIdentifier:)`. A response of another protocol version makes the app unregister and register the helper again and repeat the request once. Debug builds register and ping the helper when launched with `-FCHelperSelfTest`. The operations (protocol version 2, `Shared/HelperFileSystem.swift`) resolve a path's folder once with `realpath` and then open it from "/" with `openat(O_DIRECTORY | O_NOFOLLOW)`, so that a folder swapped for a link meanwhile fails the request; the item itself is never followed (`*at` calls with `AT_SYMLINK_NOFOLLOW`, `O_SYMLINK` for flags). Locations protected by System Integrity Protection are refused before anything happens. In the app, `PrivilegedRunner` first lets `HelperApprovalModel` explain and install the helper, then the approval in System Settings, then obtains the authorization, and polls jobs into the operation's progress; cancelling the operation cancels the job. The worker offers Authenticate and Retry for permission failures where one helper job covers the step (copying a file or folder, creating the destination folder, moving, deleting) and waits for the runner on its thread. Authenticate to View lists a folder through the helper; the inspector routes refused permission and Locked edits to `setMode` and `setFlags`. The authorization is discarded when FileCraft quits. Copies, moves and deletions are jobs on threads of their own with item and byte progress, polled with `jobStatus` and stopped with `cancelJob`; a cancelled or failed copy is removed.

Alternatives considered: `SMJobBless` (deprecated since macOS 13 and explicitly excluded by the user), `AuthorizationExecuteWithPrivileges` (deprecated) and AppleScript `do shell script … with administrator privileges` (no granular interface, injection risk).

### D12: Localization

- **Catalogs**: `Localizable.xcstrings` and `InfoPlist.xcstrings`, with English as the development language and `de` added to the project's known regions. The existing `LOCALIZATION_PREFERS_STRING_CATALOGS`, `SWIFT_EMIT_LOC_STRINGS` and `STRING_CATALOG_GENERATE_SYMBOLS` settings stay on.
- **Strings in code**: views use literals or generated symbols, and non-view code uses `LocalizedStringResource` or `String(localized:)` with translator comments.
- **Helper errors**: the helper returns error codes only, and the app maps them to localized messages.
- **Formatting and display**: values use `FormatStyle` (`.byteCount`, `Date.FormatStyle`, relative dates). Names come from the `localizedName` resource value, and sorting uses `localizedStandardCompare`.
- **Coverage test**: a test parses the catalogs and fails on any key without a translated German value.
- **Layout checks**: German and the double-length pseudolanguage are run as scheme options.
- **Glossary and review**: the glossary lives in `docs/dev/LOCALIZATION.md`, which must get a target-membership exception like the other files in `docs/`. The project owner, a native German speaker, approves the glossary before any German string is written; Claude then drafts all translations, and the owner spot-checks the German UI before release.

Seed glossary (to be approved by the project owner):

| English | German |
|---|---|
| Trash / Move to Trash / Put Back | Papierkorb / In den Papierkorb legen / Zurücklegen |
| Get Info / Inspector | Informationen / Inspektor |
| Quick Look | Übersicht |
| Sidebar / Favorites / Locations | Seitenleiste / Favoriten / Orte |
| Path Bar / Status Bar / Tab Bar | Pfadleiste / Statusleiste / Tableiste |
| Dual Pane / Pane | Doppelansicht / Bereich |
| Shelf | Sammelbereich |
| Operations | Vorgänge |
| Batch Rename | Mehrfach umbenennen |
| Enclosing Folder / Show Original / Make Alias | Übergeordneter Ordner / Original zeigen / Alias erzeugen |
| Show View Options / Group By / Sort By | Darstellungsoptionen einblenden / Gruppieren nach / Sortieren nach |
| Compress / Expand | Komprimieren / Entpacken |

### D13: Settings and persistence

Simple preferences use `@AppStorage`, with keys and defaults defined in one `SettingsKey` type. Favorites, the shelf, recent items, rename presets and Put Back records are versioned JSON files in Application Support that contain bookmark data. Window state lives in `@SceneStorage`, which macOS discards on ⌘Q while "Close windows when quitting an application" is on in System Settings, as it is by default; so at launch, and whenever "Restore windows" changes, FileCraft writes that setting's value as `NSQuitAlwaysKeepsWindows` into its own defaults domain, which overrides the system setting for FileCraft only. SwiftUI fills a restored window's `@SceneStorage` only when AppKit restores the window, after the window's first `.task` started, so a window waits for `NSApplication.didFinishRestoringWindowsNotification` (`LaunchRestoration`, at most 3 seconds) before it reads its stored state, and stores changes only after that. The default-file-viewer toggle sets `NSFileViewer` in the global preferences domain and reads it back; turning it off sets Finder (`com.apple.finder`). It does not touch the default application for folders: on macOS 27, Launch Services answers `paramErr` (-50) to every change of the handler of `public.folder` and `public.directory`, through `NSWorkspace.setDefaultApplication(at:toOpen:)` as well as `LSSetDefaultRoleHandlerForContentType`, even for the handler already set, while the same call succeeds for other types (verified 2026-11-05). On launch, FileCraft compares `NSFileViewer` with the toggle and corrects any drift. With the toggle on, FileCraft takes both roles back. With it off, only roles that still name FileCraft go back to Finder, so another file viewer the user chose stays. Keys that record state, such as the last folder shown or whether the welcome window was completed, are marked `isState`: Restore Defaults of their pane keeps them, and Reset All Settings clears them too. "Quit Finder when FileCraft launches" and "Hide Finder's desktop" follow Path Finder (analysis of 26.1.10, 2026-11-05): `FinderReplacement` quits Finder with `NSRunningApplication.terminate()` at launch and starts it again with `/usr/bin/open -g -b com.apple.finder` when FileCraft quits, because a request FileCraft would have to wait for does not outlive it. Hiding the desktop sets `CreateDesktop = false` in Finder's preferences domain and restarts a running Finder; showing it removes the key. Test runs, which host FileCraft, never quit Finder. Browser windows open without a value, so a folder that opens in a new window waits in `NewWindowQueue`, and the new window, which has no stored state, takes it when it appears.

### D14: Assets

All interface icons are SF Symbols. File, folder and volume icons come from `NSWorkspace` and Quick Look. The app icon is the owner's `AppIcon.appiconset` (PNGs from 16 to 1024 px, 2026-11-04); the owner decided not to wait for an Icon Composer `.icon` file (2026-11-06). `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` compiles it into `AppIcon.icns` and `Assets.car`, and `CFBundleIconName` names it, both confirmed in the built Release app. Standard SwiftUI containers pick up the current system design, so no custom glass effects or chrome are added. Path Finder resources are never copied, traced or referenced in the repository.

### D15: Testing

A Swift Testing target `FileCraftTests` covers:

- unit tests for navigation history, path parsing and completion, rename rules, unique-name generation, conflict policies, formatting and localization coverage;
- integration tests for the file operation engine in temporary directories;
- protocol tests for the helper interface against a mock transport.

UI flows are verified with a manual checklist per capability; XCUITest automation is deferred.

### D16: Software updates through Sparkle

The user approved Sparkle 2 as an exception to the no-third-party-dependency rule. It is added through Swift Package Manager with a pinned version. Updates are listed in an appcast served over HTTPS and signed with an EdDSA key pair created by Sparkle's `generate_keys`: the private key stays in the release machine's keychain and never enters the repository, and the public key goes into `SUPublicEDKey`. An `@Observable` `UpdaterModel` wraps `SPUStandardUpdaterController`, drives the Check for Updates… command and the three General settings (checking, installing, and including pre-releases through Sparkle's `beta` channel), and leaves the update windows to Sparkle, which ships its own English and German localizations. Sparkle's XPC services for sandboxed apps are not needed because FileCraft is not sandboxed. A relaunch for an update goes through the same quit confirmation as ⌘Q.

Alternatives considered: no automatic updates (every release would need a manual download) and a self-written update check (installation and signature verification would have to be built and maintained). Both rejected in favor of Sparkle's established signed update flow.

### D17: Search field and search results

The toolbar search field wraps `NSSearchField` in an `NSViewRepresentable` instead of using `.searchable`, because SwiftUI's search field has no menu, and the spec requires one that lists recent searches. The user approved this AppKit bridge on 2026-11-05. The field's menu lists the scopes and the ten recent searches. A recent search keeps its scope, text, criteria and options, but not the folder it started in, and is stored in `RecentsStore`. The This Folder scope filters the tab as the user types. Subfolders and This Mac show their results as a `.search(SearchQuery)` location. After the user stops typing for 0.3 seconds, the first search adds a history entry and later ones replace it, so ⌘[ returns to the folder where the search started. Clearing the field ends the search. Leaving a search records it as a recent search.

Subfolders searches enumerate with `FileManager` on the concurrent executor and hand results to the main actor in batches. This Mac searches use `NSMetadataQuery` on the main actor. Its predicate narrows the results, and `SearchMatcher` then checks each result, which covers regular expressions and package contents that Spotlight cannot express. Results are capped at 10,000.

### D18: Batch rename

Rename rules are value types (`RenameRule`). Each rule keeps the settings of every rule type, so the editor binds to them directly and switching a rule's type keeps what the user entered. `RenameEngine` prepares regular expressions and date formatters once and applies the enabled rules in order. `BatchRenameValidator` checks each folder separately, ignoring case on case-insensitive volumes. An item that keeps its name still counts as taking that name, and names that the batch frees count as free. `BatchRenamer` first gives every item a unique temporary name in its folder and then its new name, both with `RENAME_EXCL`. This allows exchanging names and never replaces an item outside the batch. If any rename fails, the renames already made are undone in reverse order. Undo is one action that applies the reversed moves the same way. The Date rule offers four preset formats plus a custom Unicode pattern (user choice, 2026-11-05). Presets are stored in `RenamePresets.json`.

### D19: No system Services for selected files

The item context menu does not offer the system Services, and FileCraft > Services does not receive the selected files (owner decision, 2026-11-06). For Services, AppKit asks the key window's responder chain whether a responder can send the selection. Every attempt to insert such a responder failed, as the running app showed (2026-11-06):
- The app delegate behind `@NSApplicationDelegateAdaptor` is never asked, because `NSApp.delegate` is SwiftUI's own `AppDelegate`.
- SwiftUI resets the next responders of its window, content view and window controller.
- SwiftUI's `AppDelegate` answers `validRequestor(forSendType:returnType:)` with nil without asking further, so a responder appended to the application's chain is never reached.

SwiftUI file views also never become AppKit's first responder. Supporting Services would require patching private SwiftUI classes at runtime or rebuilding the file views in AppKit. Both were rejected.

### D20: Accessibility implementation

The app uses only standard macOS controls, materials and SF Symbols, so dark mode, the accent color, Increase Contrast and Reduce Transparency already follow the system without custom code (verified 2026-11-06 by switching appearance live). No explicit animation exists anywhere in the codebase (no `withAnimation`, `.animation()` or `.transition()`), so there is nothing for Reduce Motion to turn off.

File item VoiceOver support is one shared modifier, `View.fileItemAccessibility(item:tab:name:sizeUnits:locale:isRenaming:)` in `FileViewCommands.swift`, applied by the icon, list and column views alike: it sets the name as the accessibility label, `ItemPresentation.accessibilityDescription(of:sizeFormatter:locale:language:)` (kind, size, modification date) as the value, and accessibility actions for Open, Quick Look, Rename, Get Info and Move to Trash. It is skipped while the item's name is being edited, so the rename field keeps its own text-editing accessibility. `ItemPresentation.accessibilityDescription` follows the `dateString` precedent: the inserted date and size follow the `locale` parameter, but the word "modified" is looked up through `LocalizedLookup` so it follows the app's language like other UI text, not a locale forced on it for formatting; this also keeps the sentence from being built by concatenating a translated fragment, which the guidelines forbid.

Operation completion is announced through `OperationAnnouncements`, a pure struct mirroring `OperationsWindowTriggers`'s design: it returns one message per operation the first time it reaches `.completed`, `.failed` or `.cancelled`. `OperationQueueModel` posts each with `AccessibilityNotification.Announcement`, through an injectable `announce` closure so tests can capture messages without posting them. The three messages are whole, independently localized sentences, not an operation-kind verb concatenated with a suffix, for the same reason.

Every error display (Settings, Inspector, Tags, Select by Pattern, Batch Rename, Go to Folder) pairs its red text with `exclamationmark.triangle.fill`, so the error does not depend on color alone, alongside tags (named) and the active pane (outline) from the capability's other requirements.

Task 19.5 (Full Keyboard Access focus order) stood blocked behind a locked screen; the sidebar, panes and shelf follow natural tab order already, and no view disables focus, but whether the inspector or the shelf receives focus first when both are visible is unverified.

### Roadmap of the analyzed feature set

| Area | FileCraft decision |
|---|---|
| Views, tabs, dual pane, path bar, status bar, sidebar, inspector, shelf | This change |
| Batch rename, filter and search, select by pattern, file operations, archives (ZIP, tar.gz, tar.bz2, tar.xz) | This change |
| Privileged helper, Full Disk Access onboarding, settings, localization | This change |
| ACL display | This change, read-only; editing follows later |
| Bookmarks bar, configurable panels with modules, per-folder view settings | Follow-up |
| Folder compare and sync, duplicate finder, disk usage, checksums, disk images | Follow-up |
| Terminal, processes, hex viewer, Git status panels | Follow-up |
| Saved searches, saved window layouts and tab sets, AppleScript, Services | Follow-up |
| Connect to server, cloud services, uploads | Follow-up; Dropbox SDK excluded (third-party dependency) |
| Text editor, burning, RAM disk, screen capture, slideshow, reports, secure delete, desktop replacement, launch as root | Not planned |

## Risks / Trade-offs

- [SwiftUI `Table` and grid may fall short on very large folders, type-select or inline rename] → Benchmark first (task 4.1); AppKit fallback limited to list view and only with approval.
- [The change is large] → Tasks are ordered in milestones that each leave a usable app; the change is archived only when all tasks are done, and can be split with OpenSpec if needed.
- [An unsandboxed app with a root helper widens the attack surface] → Typed minimal helper interface, mutual code-signing checks, per-request authorization, path validation, no command execution, private logging.
- [Users may not approve the background item] → Registration only on demand, clear guidance, status in Settings; unprivileged features never depend on the helper.
- [The Full Disk Access probe may change with macOS updates] → Probe only a documented TCC-protected location, never block usage, always offer the manual settings link.
- [Function keys need fn on Mac keyboards by default] → Every function-key command also exists in the menus, and the setting can turn function keys off.
- [German text is about 30% longer] → Content-sized controls, pseudolanguage runs, glossary review.
- [Default MainActor isolation makes main-thread I/O easy to write by accident] → I/O only in services (D6); verify with Instruments hang detection during each milestone.
- [Tag listing has no complete public API beyond the standard color labels] → Standard labels through `NSWorkspace`, additional tags discovered through Spotlight queries.
- [Put Back works only for items FileCraft trashed itself] → Documented in Help; Finder-trashed items can still be dragged out of the Trash.
- [Sparkle adds a third-party supply-chain dependency] → Pinned version reviewed before each bump, EdDSA-signed appcast over HTTPS, private key kept out of the repository.
- [Folders opened by other applications always open in Finder] → macOS refuses to change the handler of `public.folder` (D13); FileCraft becomes the file viewer for reveal requests only and says so in Settings and onboarding.

## Migration Plan

FileCraft has no users or data yet, so no data migration is needed. Project changes (sandbox off, Hardened Runtime, platforms, bundle identifier, regions, test and helper targets) land in the first task group and are verified by building and inspecting the signed app's entitlements. Persisted JSON stores carry a schema version from the start. Rollback is a git revert of the affected commits.

## Open Questions

1. Which HTTPS URL hosts the Sparkle appcast (`SUFeedURL`), and who runs the release step that signs and publishes it? Answered by the owner on 2026-11-12, replacing the GitHub Pages answer of 2026-11-06: the appcast lives on the branch `appcast` of `thbonk/FileCraft`, so `SUFeedURL` is `https://raw.githubusercontent.com/thbonk/FileCraft/appcast/appcast.xml`. The GitHub Actions workflow Release (`.github/workflows/release.yml`) generates and signs it with `generate_appcast` and publishes the update archives as GitHub release assets; pre-releases go to Sparkle's channel `beta`. Claude creates the EdDSA key pair with `generate_keys` on the owner's Mac when task group 17 is carried out; the private key then becomes the `release` environment's secret `SPARKLE_ED_PRIVATE_KEY`. Group 17 is deferred.

Resolved with the project owner on 2026-10-30:

- Bundle identifier: `de.meandmymac.FileCraft` (D3, D11).
- German review: the owner approves the glossary first and spot-checks the translations (D12).
- App icon: the owner's `AppIcon.appiconset` PNGs; no Icon Composer file needed (D14, 2026-11-06).
- Updates: Sparkle approved as a dependency exception (D16).
- Folder handler: dropped. The default-file-viewer toggle only sets `NSFileViewer`, because macOS refuses changes to the `public.folder` handler (D13, 2026-11-05).
- Minimum system version: macOS 27.0 (D3).

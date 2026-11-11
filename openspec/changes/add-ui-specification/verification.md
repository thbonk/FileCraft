# Verification of add-ui-specification

Results of task group 20. Builds are the Release configuration from `Build/Products/Release`, run on macOS 27 with
`-AppleLanguages (en)` unless a row says otherwise.

## 20.1 Build and tests

2026-11-10: Debug and Release builds without warnings; 443 Swift Testing tests passed, none failed.

## 20.2 Profiling

Recorded with `xctrace` (template Time Profiler plus the Hangs and Hitches instruments), attached to the running
Release app. The SwiftUI template is not usable here: with a 10,000-item folder it wrote 2 GB of attribute-graph data
and could not finalize the trace.

### Fixtures

- `Big10k`: 10,000 items (9,000 text-like files of ten types, 980 PNG images, 20 folders with 6 items each).
- A 4 GiB file of random data.
- Copy target: an 8 GB APFS sparse bundle disk image, so the copy is a real byte copy and not an APFS clone.

### Baseline, 2026-11-10 (before fixes)

| Scenario | Result |
|---|---|
| Open `Big10k` (column view) | Listing appears at once; scrolling the column is smooth |
| Scroll list view and icon view, thumbnails loading | Smooth; no hang |
| Select a row or press an arrow key in a 10,000-item folder | **Fails.** 3 severe hangs in 2 minutes (7.2 s, 3.8 s, 2.8 s) and 23 hitches up to 4.4 s; one click in list view took about 11 s to select |
| Copy 4 GiB file plus `Big10k` to the disk image | Passes. About 10 s, data verified identical; checksums run off the main thread; 2 microhangs (297 ms, 286 ms), worst hitch 308 ms |

Cause of the selection hangs, from the time profile of the hang windows (share of main-thread samples):

- 88 %: sorting the folder's items (`ItemSorting.sorted`, mostly `compareNames`).
- `TabModel.outlineRows`, `visibleItems`, `itemSections` and `selectedItems` are computed properties that sort all
  items on every read. Each selection change re-evaluates the menu commands, and `BrowserCommands` alone reads
  `FileCommandModel.selectedURLs` about 20 times, each read sorting 10,000 items (`selectedURLs` 49 %,
  `BrowserCommands.body` 40 %, `StatusBarView.body` 18 %, `ListFileView.body` 9 %).

### After fixes, 2026-11-10

Fixes: `TabModel` caches the sorted items, rows and sections per input revision (listing, children, last opened
dates, filter, sort order, grouping, expanded folders) and finds the selected items through a row index;
`FileItem.id` is stored instead of computed from the URL on every access; rows and sections start from the sorted
visible items. Regression tests in `ListFileViewPerformanceTests` and `TabModelTests`.

Same fixture and interactions (click, 20 × ↓, type-select, ⌘3, 10 × ↓, ⌘1, scroll, ⌘2), 75 s trace:

| Measure | Before | After |
|---|---|---|
| Hangs over 1 s | 3 (7.2 s, 3.8 s, 2.8 s) | 0 |
| Microhangs (250 ms to 1 s) | 0 | 3 (416, 386, 362 ms) |
| Total hang time | 13.8 s | 1.2 s |
| Worst hitch | 4.4 s | 350 ms |
| Sorting, share of all main-thread samples | 88 % of hang time | 0.6 % |

Click, arrow keys and type-select in the 10,000-item folder no longer hang (hitches up to 125 ms). The three
microhangs are the view mode switches (⌘3, ⌘1, ⌘2): SwiftUI and AppKit build the new view for 10,000 items, and
FileCraft's own code is at most 5 % of those samples.

Known limitation: switching the view mode of a 10,000-item folder takes about 0.4 s.

### Findings

| # | Finding | Status |
|---|---|---|
| B2 | List view seemed never to take keyboard focus on click | Not a bug: caused by synthesized clicks (see note below); a real click focuses the table |
| B3 | An empty folder replaced the file view with a message: the window content collapsed to its middle, Paste and drops had no target | Fixed: the file view stays and the message lies on top (`FileViewContainerTests`); verified live: layout, ⌘V into an empty volume |
| B4 | "Zero kB available" on APFS disk images, whose important-usage capacity is 0 | Fixed: falls back to the plain available capacity (`VolumeMonitorTests`); verified live: "208.2 MB available" |
| B3b | A folder that cannot be read shows its message the same collapsed way as B3 did | Fixed: the message fills the file view (`FileViewContainerTests`); verified live on "/private/var/root" |
| B5 | List and column view: right-clicking below the rows shows no background menu (empty or not); the item menu works, icon view's background menu works | Open: on macOS 27 SwiftUI `List` and `Table` never call `contextMenu(forSelectionType:)` with an empty selection for clicks outside the rows, and an outer `.contextMenu` does not receive them either; needs an owner decision (AppKit event monitor and menu, or a spec change) |
| B6 | Column view seemed to show no preview for a small Markdown file | Not a bug: the preview is there, dark text on dark background was unreadable in the screenshot |
| B7 | Typing a name with a space for type-select opens Quick Look at the space | Not a bug: the spec says Space opens Quick Look and makes no exception during type-select |
| B8 | View Options panel shows "No Window" while a browser window is key and main, also after a real click | Fixed: a stock SwiftUI app showed that a `UtilityWindow` receives no `focusedSceneValue` on macOS 27; browser windows now report themselves to `ActiveBrowserWindow` (`ActiveBrowserWindowTests`); verified live: the panel shows and follows the active tab's options |
| B9 | Path bar editing: the suggestion list opens upward over the tab bar and toolbar, is clipped by the window, and while typing covers the field's text | Fixed: the alignment guide meant to move the list below the field was ignored; the list now hangs below the field by its measured height; verified live over icon and list view |
| B10 | Open With lists "Pages" twice (Pages and Pages Creator Studio) with no way to tell them apart | Fixed: equal names get their version, as in Finder (`OpenWithProviderTests`); verified live: "Pages (14.5)", "Pages (15.4)" |
| B11 | Running the test suite writes the owner's real defaults: `general.lastFolderPath` pointed to a `FileCraftTests-…` temporary folder afterwards (tabs created in tests use `SettingsStore()` on the standard defaults) | Fixed: in the test host `SettingsStore()` and `@AppStorage` use the suite `de.meandmymac.FileCraft.TestHost` (`SettingsStoreTests`, `FolderOpeningTests`), and the test host opens no browser window, whose toolbar, split view and frame AppKit saves into the user's defaults (`TestHostTests`). A full run left the owner's domain unchanged. The toolbar reordering seen after earlier test runs is B12 |
| B12 | A launch can reorder the customized toolbar: the four non-default items the owner placed after the search field (New Folder, Hidden Files, Open in Terminal, Move to Trash) came back in a different order after one of two normal launches and two of three test runs, on screen and in `NSToolbar Configuration browser`; Operations, placed before the search field, kept its place. `BrowserToolbar` declares its items in a fixed order | Open, SwiftUI defect: a stock SwiftUI app with the same customizable toolbar keeps the order over 5 launches without `NavigationSplitView`; with it, also without the inspector, every customized item moves two places left per launch, as many as the split view's own items (sidebar toggle, separator). Removing the sidebar toggle does not make the order stable. No pure SwiftUI workaround found; to be reported to Apple with the repro in `repros/b12-toolbar-order/` |

### Note on driving the app

Clicks synthesized by the computer-use tool select rows in SwiftUI `List` and `Table` views but never make the view
first responder; a stock SwiftUI `Table` app behaves the same, while a real click focuses it. Keyboard checks
therefore set the first responder through LLDB first.

## 20.3 Scenario walkthrough

Each of the 198 scenarios of the change's specs, with its evidence. Result values:

- **Test**: covered by the named Swift Testing tests, all passing on 2026-11-10 (459 test cases).
- **Code**: verified by reading the implementation.
- **Live ✓**: checked in the running Release app on 2026-11-10, in English.
- **Live (pending)**: still to be checked in the running app; **Live DE (pending)**: in German.
- **Owner**: needs the owner: a system setting, VoiceOver or Full Keyboard Access, a clean user account, real
  hardware, or a change to the owner's own data such as the Trash or the default apps.
- **Fail (B…)**: does not behave as specified; see the findings above.
- **Deferred**: software updates (group 17), deferred by the owner on 2026-11-10.

German presentation is checked once per window, sheet and menu (see "German pass" below) rather than per scenario,
because the language changes text, not behavior; the German-specific scenarios are listed under localization.

### appearance-and-accessibility

| Scenario | Evidence | Result |
|---|---|---|
| Asset audit | AssetAuditTests "The bundle contains only the app icon, the asset catalog and localization", "The repository has no image, sound or interface files besides the app icon" | Test |
| Switch to dark mode | Semantic colors only (task 19.2); switching the system appearance while running | Owner |
| Large text | Text Size for file views, sidebar and inspector (task 19.3) | Live (pending) |
| VoiceOver reads a file | PresentationTests "The accessibility description lists kind, size and modification date"; VoiceOver itself | Test + Owner |
| Move focus through the window | Full Keyboard Access (task 19.5) | Owner |
| Toggle the inspector with Reduce Motion | System `.inspector` presentation (`BrowserWindowView.swift:84`), no custom animations anywhere in the app | Code + Owner |
| Tag names for color-blind users | `TagDots` names the tags as tooltip (`.help`, `TagDots.swift:46`); the hover itself; 2026-11-11: hovering the dot showed "Red" | Code + Live ✓ |

### batch-rename

| Scenario | Evidence | Result |
|---|---|---|
| Open the sheet | ⇧⌘R with 40 items selected; 2026-11-11: ⇧⌘R opened "Batch Rename 13 Items"; disabled without a selection | Live ✓ |
| Prefix and sequence | RenameEngineTests "A prefix and a sequence number as suffix" | Test |
| Regular expression with capture groups | RenameEngineTests "A regular expression with capture groups" | Test |
| Uppercase extension only | RenameEngineTests "Uppercase applied to the extension only" | Test |
| Duplicate names | BatchRenameValidatorTests "Names that become equal on a case-insensitive volume are duplicates" | Test |
| Number by date | BatchRenameModelTests "Sequence numbers follow the chosen order" | Test |
| Swap names | FileCommandTests "A batch rename with exchanged names is undone in one step" | Test |
| Failure reverts the batch | BatchRenamerTests "A failure reverts the renames already made"; FileCommandTests "A failed batch rename reports the item and renames nothing" | Test |
| Reuse a preset | RenamePresetsStoreTests (storage); applying a preset in the sheet; 2026-11-11: saved "Lower", reopened the sheet, applying it restored the rule and preview | Test + Live ✓ |

### browser-window

| Scenario | Evidence | Result |
|---|---|---|
| Default layout on first launch | Layout of a new window; a true first launch needs a clean account | Live (pending) + Owner |
| Hide the status bar | View > Hide Status Bar with two panes; 2026-11-11: View > Hide Status Bar hid it in both panes | Live ✓ |
| Selection summary | PathModelsTests "Status summary counts the selection and adds file sizes" | Test |
| Nothing selected | Status bar showed "10,000 items" and the free space during 20.2 | Live ✓ |
| Default toolbar | Toolbar items of an uncustomized toolbar | Live (pending) |
| Customization persists | Customized items stay in the toolbar, but their positions drift on relaunch (a stock SwiftUI app reproduces it) | Fail (B12) |
| Eject unavailable | Eject disabled on the startup volume | Live (pending) |
| New window | BrowserWindowModelTests "New tabs open at the current location or at home, as Settings say"; LocationResolverTests "New windows fall back to home when the chosen folder is missing" | Test + Live (pending) |
| Window menu without window-tab commands | MainMenuTests "The Window menu lists Operations once, after the tab commands"; automatic window tabbing is off (`FileCraftApp.swift:35`); "Show Tab Bar" in the View menu is FileCraft's own pane command | Test + Code |
| Sidebar state survives hiding | Collapse Tags, hide and show the sidebar | Live (pending) |
| Inspector width persists | Widen the inspector, relaunch (task 3.9) | Live (pending) |
| Restore after relaunch | BrowserWindowModelTests "Snapshot survives encoding and restoration"; tabs were restored at every relaunch during 20.2 | Test + Live (pending: two windows, dual pane) |
| Restored location was deleted | LocationResolverTests "Deleted folder resolves to its nearest existing ancestor", "Restored snapshot replaces a deleted folder" | Test |
| Enter full screen | ⌃⌘F | Live (pending) |

### file-operations

| Scenario | Evidence | Result |
|---|---|---|
| New folder name collision | ItemCreatorTests "New folders get the localized default name and then the next free number" | Test |
| Group the selection | FileCommandTests "New Folder with Selection moves the items into a new folder, and Undo moves them out again" | Test |
| Name already exists | TabModelTests "Renaming validates and renames on disk" | Test |
| Change extension | FileCommandTests "Renaming asks before changing an extension, and Undo renames back" | Test |
| Duplicate twice | FileCommandTests "Duplicate copies items into their folder under the localized copy name"; UniqueNameGeneratorTests "Duplicates get the copy suffix before the extension" | Test |
| Cut and paste | FileCommandTests "Paste copies items, but moves the items cut last" | Test |
| Move to a recent folder | Copy To… listed the recent folders and copied during 20.2; Move To… itself | Live (pending) |
| Put back | FileCommandTests "Put Back returns items to their original folder" | Test |
| Confirm deletion | FileDeletionTests "Deleting a folder removes its contents but never what a link inside points to"; the confirmation alert | Test + Live (pending) |
| Empty the Trash | MainMenuTests "File commands and Empty Trash have the shortcuts from the spec"; emptying would empty the owner's Trash | Owner |
| Make an alias | ItemCreatorTests "An alias is a Finder alias of its original, next to it" | Test |
| Compress several items | ArchiveServiceTests "Several items go into an archive named Archive, at its top level" | Test |
| Expand a ZIP archive | ArchiveServiceTests "An expanded item takes a free name when its name exists" | Test |
| Eject the current volume | ⌘E on a mounted disk image | Live (pending) |
| Cancel a copy | FileOperationEngineTests "A paused copy waits, and cancelling it removes the partial copy" | Test |
| Quit during a copy | Quit alert while a copy runs | Live (pending) |
| Keep both | FileOperationQuestionTests "A conflict compares both items, and Keep Both adds the new one under the next free name" | Test |
| Merge folders | FileOperationQuestionTests "Merging folders combines their contents and asks about conflicts inside them" | Test |
| Copy into a protected folder | FileOperationQuestionTests "Authenticate and Retry copies the item through the helper" (mock helper); the real approval and password (task 10.10) | Test + Owner |
| Undo a move | FileCommandTests "Undoing a move puts the item back under its original name" | Test |
| Cross-volume move interrupted | FileOperationEngineTests "A move across volumes deletes each source only after its copy, also when interrupted" | Test |
| Corrupted copy detected | FileOperationEngineTests "Verification compares checksums" | Test |
| Move a folder into itself | FileOperationEngineTests "A folder is never copied into itself or one of its folders"; FileCommandTests "Dropping a folder into its own folder is refused with the reason" | Test |

### file-views

| Scenario | Evidence | Result |
|---|---|---|
| Switch to column view | TabModelTests "Switching to column view keeps the selection" | Test |
| Show the Permissions column | PresentationTests "Permissions read like ls"; the column header menu; 2026-11-11: header menu, column shows "rwxr-xr-x" | Test + Live ✓ |
| Expand inline | TabModelTests "Expanding a folder loads its children"; the → key; 2026-11-11: → showed "Sub" indented, location unchanged | Test + Live ✓ |
| Numeric-aware name sorting | ItemSortingTests "Names with numbers sort numerically" | Test |
| Folders first | ItemSortingTests "Folders stay first when sorting by date modified" | Test |
| Group by kind | ItemSortingTests "Grouping by kind creates alphabetical sections"; the localized headers; 2026-11-11: headers Alias, Folder, Markdown, PDF document … | Test + Live ✓ |
| Change icon size | View options slider; View Options shows "No Window"; 2026-11-11 after the B8 fix: the slider grew the icons to 168 pt and the grid reflowed | Live ✓ |
| Preview column | PDF preview and metadata (see B6); 2026-11-11: PDF page preview, kind, size and date | Live ✓ |
| Localized folder names | Root of the startup volume in German | Live DE (pending) |
| Reveal hidden files | ⇧⌘.; 2026-11-11: ⇧⌘. showed ".zshrc-sample" dimmed | Live ✓ |
| Leave before calculation ends | FolderSizeServiceTests "Cancelled calculation throws CancellationError" | Test |
| Scroll a folder of photos | ThumbnailServiceTests "Thumbnail is created once and then served from the cache"; 980 images scrolled in icon view during 20.2 | Test + Live ✓ |
| Selection survives an external change | SelectionAndTypingTests "Pruning drops items that disappeared"; TabModelTests "Listing changes deselect items that are gone" | Test |
| Type to select | SelectionAndTypingTests "Typed characters form a prefix that resets after one second", "Prefix matches ignore case and diacritics"; typed "Image" in 10,000 items during 20.2 | Test + Live ✓ |
| Open folder in new tab | ⌘-double-click | Live (pending) |
| Browse with Quick Look | TabModelTests "Quick Look follows the selection and selects the item it moves to" | Test |
| Copy across volumes | DropPolicyTests "Drops move on the same volume and copy across volumes" | Test |
| Spring-loaded folder | Hover during a drag | Live (pending) |
| File created by another app | DirectoryWatcherTests "New file is reported within one second"; a file created from the shell appeared at once during 20.2 | Test + Live ✓ |
| Open a large folder | ListFileViewPerformanceTests; 20.2 | Test + Live ✓ |
| Protected folder without access | PresentationTests "Load failures are classified"; the error view; 2026-11-11: "No Access to This Folder" with both buttons; layout collapsed (B3b) | Test + Live ✓ |
| Apply options as defaults | SettingsStoreTests "Use as Defaults applies to new tabs in the same view mode only" | Test |

### inspector

| Scenario | Evidence | Result |
|---|---|---|
| Inspector follows the selection | Live ✓ |
| Confirmation for many items | BrowserWindowModelTests "Get Info asks for one window per selected item, or for the folder"; the alert above 10 items; 2026-11-11: ⌘I on 13 items asked "Open 13 info windows?" | Test + Live ✓ |
| Sections for a folder | Live ✓ |
| Preview a video | Needs a video file; 2026-11-11: plays with pause, time and scrubber | Live ✓ |
| Folder item count | InspectorModelTests "A folder shows its recursive item count and size" | Test |
| Rename from the inspector | InspectorModelTests "Renaming from the inspector can be undone" | Test |
| Add an existing tag | Tag suggestions; 2026-11-11: "Re" suggested "Red", accepted, stored in the file | Live ✓ |
| Make a script executable | InspectorModelTests "Turning on execute for the owner changes the mode and can be undone" | Test |
| Change requires administrator rights | PrivilegedHelperTests "Only permission and Locked edits go through the helper" (mock); the real helper | Test + Owner |
| Change the default app for a type | Change All… changes the owner's Launch Services defaults | Owner |
| Hide a file | InspectorModelTests "A mixed toggle sets an attribute of several items as one undoable edit"; the Hidden toggle; 2026-11-11: Hidden on "gamma.txt" removed it from the list | Test + Live ✓ |
| Tag several items | InspectorModelTests "A tag added to several items shows as theirs and undoes in one step" | Test |
| Undo a tag change | InspectorModelTests "Removing a tag in the inspector can be undone" | Test |

### localization

| Scenario | Evidence | Result |
|---|---|---|
| German system | Launch in German | Live DE (pending) |
| Unsupported language | Launch in French: English UI | Live (pending) |
| Missing translation detected | LocalizationCoverageTests "Every string has a German translation" and three more | Test |
| Item counts in German | GermanLocalizationTests "Counts use the German plural forms" | Test + Live DE (pending) |
| German number format | PathModelsTests "Decimal sizes follow the locale" | Test |
| Applications folder in German | "Programme" shown, Copy Path gives "/Applications" | Live DE (pending) |
| Duplicate in German | UniqueNameGeneratorTests "German names follow the glossary" | Test |
| Umlauts sort with their base letters | ItemSortingTests "Umlauts sort with their base letters in German" | Test |
| Trash command in German | File menu wording | Live DE (pending) |
| Pseudolanguage check | Task 18.5: double-length pass, remaining truncations accepted and recorded | Live ✓ (18.5) |

### menus-and-shortcuts

| Scenario | Evidence | Result |
|---|---|---|
| Every command is reachable from the menu bar | MainMenuTests "Every menu shortcut of the catalog belongs to its command" and twelve more | Test + Live (pending: menu walk) |
| Nothing selected | MainMenuTests "Item commands are disabled without a selection" | Test |
| Shortcut triggers command | MainMenuTests; ⇧⌘G opened Go to Folder during 20.2 | Test + Live ✓ |
| German keyboard layout | MainMenuTests "Shortcuts adapt to the keyboard layout"; this Mac uses the German layout | Test |
| Context menu on several items | | Live (pending) |
| Paste via context menu | Right-clicking below the rows in list view shows no menu; icon view: background menu with Paste works; list and column view: no menu | Fail (B5) |
| Remove a favorite | With a temporary favorite | Live (pending) |
| Look up a shortcut | ShortcutCatalogTests "Searching for Trash finds the three trash commands" | Test + Live (pending) |
| Open a recent folder from the Dock | DockMenuTests (2 tests) | Test + Live (pending) |

### navigation

| Scenario | Evidence | Result |
|---|---|---|
| Go back | NavigationHistoryTests "Going back returns to the previous location and enables Forward"; Back used during 20.2 | Test + Live ✓ |
| History menu | NavigationHistoryTests "History menu jumps directly to an earlier location"; press and hold; 2026-11-11: press and hold Forward listed the entry | Test + Live ✓ |
| Return to parent | TabModelTests "Enclosing Folder shows the parent with the folder just left selected" | Test |
| Jump to Downloads | StandardLocationTests; MainMenuTests "The Go menu has history, Recent Folders and the standard locations" | Test |
| Complete a path | PathCompletionTests "Typing "~/Doc" completes to "~/Documents/"" | Test |
| Path to a file | PathModelsTests "Typed paths are interpreted like Go to Folder"; the reveal; 2026-11-11: opened "Sub" with "inner.txt" selected | Test + Live ✓ |
| Invalid path | Live ✓ |
| Jump to an ancestor | Live ✓ |
| Narrow window | Live ✓ |
| Type a path into the path bar | Live ✓ |
| Copy two paths | PathFormatterTests "Copy Path puts the paths on the pasteboard" | Test |
| Copy as shell-escaped path | PathFormatterTests "Shell escaping produces one shell word" | Test |
| Revisit a folder | TabModelTests "Visited folders become recent folders, most recent first"; RecentsStoreTests | Test |
| Open with another app | Live ✓ |
| Resolve a symbolic link | OriginalResolverTests; TabModelTests "Show Original reveals the target of a link in its folder" | Test |
| Open a terminal here | FolderOpeningTests "Terminal applications include Terminal and skip apps that are not installed"; the configured terminal is the owner's iTerm2 | Test + Owner |
| Folder dropped on the Dock icon | BrowserWindowModelTests "An open request for a folder opens it in a new tab"; `open -a FileCraft <folder>` opened a new tab during 20.2 | Test + Live ✓ |

### onboarding

| Scenario | Evidence | Result |
|---|---|---|
| First launch | WelcomeModelTests "The window shows at launch until it is completed"; a real first launch | Test + Owner |
| Later launches | No welcome window at any launch on 2026-11-10 | Live ✓ |
| Grant access | WelcomeModelTests "Refreshing reads the Full Disk Access status"; granting in System Settings | Test + Owner |
| Skip the access step | Needs Full Disk Access denied | Owner |
| Enable from the welcome window | DefaultFileViewerTests; a system-wide change | Test + Owner |
| Reopen from Help | | Live (pending) |

### privileged-helper

| Scenario | Evidence | Result |
|---|---|---|
| Registration call | PrivilegedHelperTests "The client registers the helper and asks for approval before sending" | Test |
| Bundle check | Release bundle holds `Contents/MacOS/FileCraftHelper` and `Contents/Library/LaunchDaemons/de.meandmymac.FileCraft.Helper.plist` | Live ✓ |
| First privileged operation | PrivilegedHelperTests "The helper is explained before it is registered, then waits for the approval"; the real registration | Test + Owner |
| User approves the helper | Approval in System Settings | Owner |
| User does not approve | PrivilegedHelperTests "Cancelling the approval tells the waiting action" | Test + Owner |
| Authorization reuse | PrivilegedHelperTests "An authorization is reused for at most five minutes" | Test |
| Authorization expired | Same test | Test |
| Foreign client rejected | Both sides require `.isFromSameTeam(andMatchesSigningIdentifier:)` (`HelperMain.swift:44`, `PrivilegedHelperClient.swift:113`) | Code |
| No command execution | `HelperRequest` offers only ping, list, create folder, rename, owner, mode, flags and copy, move and delete jobs (`Shared/HelperProtocol.swift`) | Code |
| Protected system location | HelperFileSystemTests "Paths that are relative, contain dot-dot or lie in protected locations are refused" | Test |
| Cancel a privileged copy | PrivilegedHelperTests "A job runs through the helper until it finished and reports its progress" (mock); the real helper | Test + Owner |
| Remove the helper | HelperSettingsModelTests "Install waits for approval and Remove unregisters" | Test |
| App updated | PrivilegedHelperTests "A helper of another protocol version is registered again and asked once more" | Test |
| Log entry | The helper logs paths with `privacy: .private` (`HelperMain.swift:38`) | Code |

### search-and-filter

| Scenario | Evidence | Result |
|---|---|---|
| Filter by name | TabSearchTests "The quick filter shows matching items and the status counts them" | Test |
| Diacritic-insensitive match | TabSearchTests "The quick filter ignores diacritics" | Test |
| Search subfolders | SearchServiceTests "A Subfolders search finds matches in all folders below" | Test |
| Back to the folder | TabSearchTests "A search shows its results as a location that Back leaves" | Test |
| Large recent images | SearchMatcherTests "Large recent images match all three criteria" | Test |
| Include hidden items | SearchServiceTests "Hidden items and package contents are found only when included" | Test |
| Stop a long search | | Live (pending) |
| Select all JPEGs | TabSearchTests "Select by Pattern replaces the selection or adds to it" | Test |
| Repeat a search | TabSearchTests "A recent search runs again with its scope and criteria" | Test |

### settings

| Scenario | Evidence | Result |
|---|---|---|
| Immediate effect | PresentationTests "Always show extensions reveals a hidden extension"; the toggle | Test + Live (pending) |
| New windows open in Documents | BrowserWindowModelTests "New tabs open at the current location or at home, as Settings say" | Test + Live (pending) |
| Manual check finds an update | Group 17 | Deferred |
| Tampered update rejected | Group 17 | Deferred |
| Automatic installation off | Group 17 | Deferred |
| Update while operations run | Group 17 | Deferred |
| Return opens items | | Live (pending) |
| Hide tags | | Live (pending) |
| Disable function keys | | Live (pending) |
| Automatic Operations window | OperationsWindowTriggersTests "A long operation opens the window after five seconds when the setting is on"; opened during the 20.2 copy | Test + Live ✓ |
| Trash archive after expanding | | Live (pending) |
| Become the default file viewer | DefaultFileViewerTests "Turning the setting on makes FileCraft the file viewer"; system-wide | Test + Owner |
| Folders opened by other applications | System-wide | Owner |
| Turn the toggle off | DefaultFileViewerTests "Turning it off makes Finder the file viewer again"; system-wide | Test + Owner |
| Quit Finder on launch | FinderReplacementTests "Finder quits at launch and starts again when FileCraft quits"; quits the owner's Finder | Test + Owner |
| Finder returns when FileCraft quits | Same test | Test + Owner |
| Hide Finder's desktop | FinderReplacementTests "Hiding the desktop sets Finder's preference and restarts Finder" | Test + Owner |
| Show Finder's desktop again | SettingsStoreTests "Restore Defaults of each pane resets exactly the keys of that pane" | Test + Owner |
| Status shown | HelperSettingsModelTests "Statuses map to what the pane shows"; the Helper pane | Test + Live (pending) |
| Binary units | PathModelsTests "Binary sizes use IEC prefixes" | Test |

### shelf

| Scenario | Evidence | Result |
|---|---|---|
| Shared contents | Two windows | Live (pending) |
| Add by dragging | ShelfStoreTests "Adding stores references, skips items on the shelf and survives a relaunch"; the drag | Test + Live (pending) |
| Item deleted elsewhere | ShelfStoreTests "A renamed item gets its new path and a deleted one becomes unavailable" | Test |
| Collect and move | FileCommandTests "Move Items to Current Folder moves shelf items, which then point to their new places" | Test |
| Survive relaunch | ShelfStoreTests "Adding stores references, skips items on the shelf and survives a relaunch" | Test |

### sidebar

| Scenario | Evidence | Result |
|---|---|---|
| Collapse a section | Collapse Tags, open a new window | Live (pending) |
| Add a folder | FavoritesStoreTests "Adding appends new items, skips favorites and inserts at a drop position"; ⌃⌘T | Test + Live (pending) |
| Favorite follows a rename | FavoritesStoreTests "A renamed favorite shows its new name and a deleted one becomes unavailable" | Test |
| Open in new tab | BrowserWindowModelTests "Sidebar entries open in the active tab or in a new tab" | Test + Live (pending) |
| USB drive connected | A disk image as stand-in; a real USB drive | Live (pending) + Owner |
| Eject from the sidebar | A disk image | Live (pending) |
| Show tagged items | | Live (pending) |
| Tag by dropping | TagLibraryTests "Dropping on a tag adds it once and keeps the item's other tags" | Test + Live (pending) |
| Favorite on an unmounted volume | FavoritesStoreTests "Opening a favorite resolves it to a folder, a file or unavailable"; the alert | Test + Live (pending) |

### tabs-and-dual-pane

| Scenario | Evidence | Result |
|---|---|---|
| New tab | BrowserWindowModelTests "New tabs open at the current location or at home, as Settings say" | Test |
| Close the last tab of the second pane | BrowserWindowModelTests "Closing the last tab of the second pane turns dual pane off" | Test |
| Move a tab to the other pane | BrowserWindowModelTests "A dragged tab moves to the other pane with its history"; the drag | Test + Live (pending) |
| Undo an accidental close | BrowserWindowModelTests "A closed tab reopens with its history in the pane it came from" | Test |
| Second tab shows the tab bar | | Live (pending) |
| Turn on dual pane for the first time | BrowserWindowModelTests "Showing dual pane for the first time opens the active location" | Test |
| Hidden pane keeps its tabs | BrowserWindowModelTests "Hidden second pane keeps its tabs" | Test |
| Switch with Tab | BrowserWindowModelTests "Cross-pane commands use the other pane and Tab moves focus there"; 2026-11-11: Tab made the right pane active; the inspector showed its selection | Test + Live ✓ |
| Copy with F5 | Same test; the F5 key | Test + Live (pending) |
| Mirror the location | BrowserWindowModelTests "Cross-pane commands use the other pane and Tab moves focus there" (calls Show Same Folder in Other Pane) | Test |
| New folder with F7 | Live ✓ |

## ADDED Requirements

### Requirement: Per-tab navigation history
Each tab SHALL keep its own back and forward history of visited locations. Go > Back (⌘[) and Go > Forward (⌘]) and the toolbar's Back/Forward item SHALL move through that history. Pressing and holding a Back or Forward button SHALL show a menu of history entries for direct jumps. Navigating to a new location after going back SHALL discard the forward history.

#### Scenario: Go back
- **WHEN** the user opens "Documents" then "Invoices" in the same tab and presses ⌘[
- **THEN** the tab shows "Documents" and Forward becomes enabled

#### Scenario: History menu
- **WHEN** the user presses and holds the Back button after visiting five folders
- **THEN** a menu lists the earlier folders and choosing one shows it directly

### Requirement: Enclosing folder and open selection
Go > Enclosing Folder (⌘↑) SHALL show the parent of the current location and select the folder that was just left. ⌘↓ SHALL open the selected items: folders in the current tab, files with their default application.

#### Scenario: Return to parent
- **WHEN** the tab shows "~/Documents/Invoices" and the user presses ⌘↑
- **THEN** the tab shows "~/Documents" with "Invoices" selected

### Requirement: Standard locations
The Go menu SHALL navigate the active tab to Computer (⇧⌘C), Home (⇧⌘H), Desktop (⇧⌘D), Documents (⇧⌘O), Downloads (⌥⌘L), Applications (⇧⌘A), Utilities (⇧⌘U) and iCloud Drive (⇧⌘I). iCloud Drive SHALL be hidden when it is not enabled for the user. Holding ⌥ SHALL reveal a Library item for the user's Library folder.

#### Scenario: Jump to Downloads
- **WHEN** the user presses ⌥⌘L
- **THEN** the active tab shows the user's Downloads folder

### Requirement: Go to Folder
Go > Go to Folder… (⇧⌘G) SHALL open a sheet with a path field that accepts absolute paths, paths starting with "~", paths relative to the current location and file URLs. The field SHALL suggest completions for the typed path, and Tab SHALL accept the highlighted completion. The sheet SHALL offer the ten most recent entries. A path that names a file SHALL show its parent folder with the file selected; a path that does not exist SHALL produce an inline error and keep the sheet open.

#### Scenario: Complete a path
- **WHEN** the user types "~/Doc" in the Go to Folder sheet and presses Tab
- **THEN** the field reads "~/Documents/"

#### Scenario: Path to a file
- **WHEN** the user enters "~/Documents/report.pdf" and confirms
- **THEN** the tab shows "~/Documents" with "report.pdf" selected

#### Scenario: Invalid path
- **WHEN** the user enters a path that does not exist
- **THEN** the sheet stays open and shows a localized error below the field

### Requirement: Path bar breadcrumbs
The path bar SHALL show the current location as a sequence of segments from the volume root to the current folder, each with its icon and localized display name. Clicking a segment SHALL navigate to it. Each segment SHALL offer a menu of its subfolders for direct jumps. Items dropped on a segment SHALL be moved or copied there with the drag-and-drop rules of `file-views`. When space is short, middle segments SHALL collapse into an overflow menu while the first and last segments stay visible.

#### Scenario: Jump to an ancestor
- **WHEN** the tab shows "/Users/anna/Projects/FileCraft" and the user clicks the "anna" segment
- **THEN** the tab shows the folder "/Users/anna"

#### Scenario: Narrow window
- **WHEN** the pane is too narrow for all segments
- **THEN** the path bar shows the root segment, an overflow control and the last segments

### Requirement: Path bar editing
Double-clicking the empty area of the path bar or choosing Edit > Edit Path SHALL turn the path bar into a text field containing the current path, with the same completion behavior as Go to Folder. Return SHALL navigate and Escape SHALL restore the breadcrumbs.

#### Scenario: Type a path into the path bar
- **WHEN** the user double-clicks the path bar, types "/Library/Fonts" and presses Return
- **THEN** the tab shows "/Library/Fonts" and the path bar returns to breadcrumbs

### Requirement: Copy path
Edit > Copy Path (⌥⌘C) SHALL copy the POSIX paths of the selected items, one per line, or the current folder's path when nothing is selected. Edit > Copy Path As SHALL offer POSIX path, path relative to the home folder ("~/…"), file URL, name only and shell-escaped path.

#### Scenario: Copy two paths
- **WHEN** two files are selected and the user presses ⌥⌘C
- **THEN** the pasteboard contains both absolute paths separated by a line break

#### Scenario: Copy as shell-escaped path
- **WHEN** the user chooses Copy Path As > Shell-Escaped Path for "My File.txt"
- **THEN** the pasteboard contains the path with the space escaped, for example "/Users/anna/My\ File.txt"

### Requirement: Recent folders
FileCraft SHALL record visited folders and list the 15 most recent ones in Go > Recent Folders, most recent first, without duplicates. The menu SHALL include Clear Menu.

#### Scenario: Revisit a folder
- **WHEN** the user visited "Invoices" earlier and chooses it from Go > Recent Folders
- **THEN** the active tab shows "Invoices"

### Requirement: Open With
File > Open With SHALL list the applications that can open the selected items, with the default application first and marked, followed by "Other…" to pick any application. Choosing an application SHALL open all selected items with it.

#### Scenario: Open with another app
- **WHEN** the user selects "notes.md" and chooses Open With > TextEdit
- **THEN** "notes.md" opens in TextEdit

### Requirement: Show original
File > Show Original (⌘R) on an alias or symbolic link SHALL show the target's enclosing folder with the target selected. A broken alias or link SHALL produce a localized alert that offers Delete Alias and Cancel.

#### Scenario: Resolve a symbolic link
- **WHEN** the user selects a symbolic link pointing to "/usr/local/bin/tool" and presses ⌘R
- **THEN** the tab shows "/usr/local/bin" with "tool" selected

### Requirement: Reveal in Finder and Open in Terminal
The commands Reveal in Finder and Open in Terminal SHALL be available for the selection or, without a selection, the current folder. Open in Terminal SHALL open a session in the terminal application chosen in Settings, with the working directory set to the selected folder or the current folder.

#### Scenario: Open a terminal here
- **WHEN** nothing is selected in "~/Projects" and the user chooses Open in Terminal
- **THEN** the configured terminal application opens a session whose working directory is "~/Projects"

### Requirement: External open requests
FileCraft SHALL accept folders dropped on its Dock icon and folder open requests from other applications, showing each folder in a new tab of the frontmost browser window, or in a new window when none exists. A file in such a request SHALL be revealed (its folder shown with the file selected).

#### Scenario: Folder dropped on the Dock icon
- **WHEN** the user drops the folder "Photos" on FileCraft's Dock icon while a browser window is open
- **THEN** a new tab showing "Photos" opens in that window

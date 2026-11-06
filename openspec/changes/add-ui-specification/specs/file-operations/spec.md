## ADDED Requirements

### Requirement: Create folders and files
File > New Folder (⇧⌘N) SHALL create a folder with the localized default name ("untitled folder" in English) in the active pane's current folder, select it and start inline renaming. File > New Folder with Selection (⌃⌘N) SHALL create a folder and move the selected items into it. File > New Text File (⌥⌘N) SHALL create an empty plain-text file with the localized default name. When the default name exists, FileCraft SHALL append the next free number.

#### Scenario: New folder name collision
- **WHEN** "untitled folder" already exists and the user presses ⇧⌘N
- **THEN** FileCraft creates "untitled folder 2" and starts renaming it

#### Scenario: Group the selection
- **WHEN** three files are selected and the user presses ⌃⌘N
- **THEN** a new folder containing the three files is created, selected and ready for renaming

### Requirement: Inline rename
Renaming SHALL start with Return (unless Return is assigned to open), with File > Rename, or by clicking the name of an already selected item and pausing. The editor SHALL select the name without its extension. FileCraft SHALL reject an empty name, a name containing ":" or "/", a name longer than 255 bytes in UTF-8 and a name that already exists in the folder, and SHALL explain the reason inline while keeping the editor open.

#### Scenario: Name already exists
- **WHEN** the user renames "a.txt" to "b.txt" and "b.txt" exists in the folder
- **THEN** FileCraft keeps the editor open and explains that the name is taken

### Requirement: Extension change confirmation
When a rename changes a file's extension, FileCraft SHALL ask whether to keep the old extension or use the new one, unless the user turned this warning off.

#### Scenario: Change extension
- **WHEN** the user renames "notes.txt" to "notes.md"
- **THEN** FileCraft asks "Keep .txt" or "Use .md" and applies the chosen name

### Requirement: Duplicate
File > Duplicate (⌘D) SHALL copy each selected item into the same folder with a localized suffix ("copy", then "copy 2") and SHALL select the duplicates.

#### Scenario: Duplicate twice
- **WHEN** the user duplicates "plan.key" twice
- **THEN** the folder contains "plan copy.key" and "plan copy 2.key"

### Requirement: Copy, cut and paste
Edit > Copy (⌘C) SHALL put the selected items on the pasteboard as file references. Edit > Paste (⌘V) SHALL copy them into the active pane's current folder. Edit > Cut (⌘X) SHALL mark the selected items as dimmed, and the next Paste SHALL move them. After Copy, Edit > Move Items Here (⌥⌘V) SHALL move instead of copy. Pasting file references copied in other applications SHALL behave the same way.

#### Scenario: Cut and paste
- **WHEN** the user presses ⌘X on two files, opens another folder and presses ⌘V
- **THEN** both files move to the other folder

### Requirement: Copy to and move to
File > Copy To… and File > Move To… SHALL ask for a destination folder, offering the other pane's folder and recent folders as shortcuts, and SHALL copy or move the selection there.

#### Scenario: Move to a recent folder
- **WHEN** the user chooses Move To… and picks the recent folder "Archive"
- **THEN** the selection moves into "Archive"

### Requirement: Move to Trash and Put Back
File > Move to Trash (⌘⌫) SHALL move the selection to the Trash of its volume. Items moved to the Trash by FileCraft SHALL be restorable with File > Put Back while browsing the Trash, and with Edit > Undo. Items that cannot be moved to the Trash SHALL trigger an alert offering Delete Immediately.

#### Scenario: Put back
- **WHEN** the user trashes "draft.txt" from "~/Documents", opens the Trash, selects it and chooses Put Back
- **THEN** "draft.txt" returns to "~/Documents"

### Requirement: Delete immediately
File > Delete Immediately… (⌥⌘⌫) SHALL ask for confirmation, stating that the action cannot be undone, and SHALL then delete the selection without using the Trash.

#### Scenario: Confirm deletion
- **WHEN** the user presses ⌥⌘⌫ on three files
- **THEN** FileCraft asks for confirmation and deletes the files only after the user confirms

### Requirement: Empty Trash
File > Empty Trash… (⇧⌘⌫) SHALL empty the Trash after confirmation, unless the warning is turned off in Settings.

#### Scenario: Empty the Trash
- **WHEN** the user presses ⇧⌘⌫ and confirms
- **THEN** all items in the user's Trash are deleted

### Requirement: Aliases and symbolic links
File > Make Alias (⌃⌘A) SHALL create a Finder alias named with the localized "alias" suffix next to each selected item. File > Make Symbolic Link SHALL create a symbolic link with the same naming rule. Both SHALL be selected after creation.

#### Scenario: Make an alias
- **WHEN** the user selects "Projects" and presses ⌃⌘A
- **THEN** "Projects alias" appears next to it and is selected

### Requirement: Compress
File > Compress SHALL create a ZIP archive compatible with Finder: "<name>.zip" for one item or a localized "Archive.zip" for several items, placed according to the compression settings. File > Compress With Format SHALL also offer tar.gz, tar.bz2 and tar.xz. Compression SHALL use only tools included with macOS.

#### Scenario: Compress several items
- **WHEN** the user compresses three files in "~/Desktop"
- **THEN** "~/Desktop/Archive.zip" is created, containing the three files, and is selected

### Requirement: Expand archives
File > Expand SHALL extract ZIP, tar, tar.gz, tar.bz2, tar.xz and gz archives into the archive's folder, or another folder chosen in Settings, using a unique name when the destination exists, and SHALL select the extracted item. Double-clicking an archive SHALL expand it when "Expand archives in FileCraft" is on.

#### Scenario: Expand a ZIP archive
- **WHEN** the user expands "photos.zip" containing the folder "photos" in a folder that already contains "photos"
- **THEN** the extracted folder is named "photos 2" and is selected

### Requirement: Eject
File > Eject (⌘E) SHALL eject or unmount the selected volume or the volume of the current location. Panes showing locations on that volume SHALL switch to the home folder.

#### Scenario: Eject the current volume
- **WHEN** the active pane shows a folder on an external drive and the user presses ⌘E
- **THEN** the drive is ejected and the pane shows the home folder

### Requirement: Operation queue
Copy, move, delete, compress and expand operations SHALL run in the background without blocking the UI. Window > Operations SHALL list running and finished operations with progress, processed items and bytes, speed and estimated time remaining, and SHALL allow pausing, resuming and cancelling each one. While operations run, the Operations toolbar item SHALL show overall progress. Operations on different volumes SHALL run concurrently; operations on the same volume SHALL run one after another.

#### Scenario: Cancel a copy
- **WHEN** a 20 GB copy is running and the user clicks Cancel in the Operations window
- **THEN** the copy stops, the partially copied item is removed and the operation is listed as cancelled

### Requirement: Quitting with running operations
When the user quits FileCraft while operations are running or paused, FileCraft SHALL ask whether to stop the operations and quit or to keep FileCraft running.

#### Scenario: Quit during a copy
- **WHEN** a copy is running and the user presses ⌘Q
- **THEN** FileCraft asks whether to stop the copy and quit
- **AND** the copy continues if the user chooses not to quit

### Requirement: Conflict resolution
When an item with the same name exists at the destination, FileCraft SHALL show a dialog comparing both items' kind, size and modification date, offering Replace, Keep Both, Skip and Stop, plus "Apply to all conflicts". For two folders, it SHALL also offer Merge, which combines their contents and resolves nested conflicts the same way. A folder SHALL never be replaced by a file, or a file by a folder, without this dialog.

#### Scenario: Keep both
- **WHEN** copying "report.pdf" into a folder that already contains "report.pdf" and the user chooses Keep Both
- **THEN** the copy is named "report 2.pdf" and the existing file is unchanged

#### Scenario: Merge folders
- **WHEN** copying folder "Assets" onto an existing folder "Assets" and the user chooses Merge
- **THEN** the destination contains the items of both folders, and conflicts within them are resolved through the dialog

### Requirement: Error handling
An operation that fails for an item SHALL pause and offer Skip, Retry and Stop, plus "Apply to all errors". A permission error SHALL additionally offer "Authenticate and Retry", which performs the item operation through the privileged helper. When an operation finishes with errors, FileCraft SHALL show a summary listing the failed items and reasons.

#### Scenario: Copy into a protected folder
- **WHEN** the user copies a file into "/Library/Fonts" without write permission
- **THEN** FileCraft offers "Authenticate and Retry" and, after authentication, completes the copy through the privileged helper

### Requirement: Undo and redo
Edit > Undo (⌘Z) and Edit > Redo (⇧⌘Z) SHALL cover rename, move, copy (undo moves the copies to the Trash), move to Trash, new folder, new file, duplicate, alias and link creation, compress, expand, tag and attribute changes. The menu item SHALL name the action, for example "Undo Move of 3 Items".

#### Scenario: Undo a move
- **WHEN** the user moves three files and chooses Edit > Undo Move of 3 Items
- **THEN** the three files return to their original folder

### Requirement: Metadata and move semantics
Copies SHALL preserve extended attributes, access control lists, tags, Finder information, permissions where allowed, and creation and modification dates. A move within one volume SHALL be a rename that never copies data. A move across volumes SHALL copy and then delete each source item only after its copy completed successfully.

#### Scenario: Cross-volume move interrupted
- **WHEN** a move from the startup volume to an external drive is cancelled halfway
- **THEN** every source item whose copy did not complete is still at its original location

### Requirement: Copy verification
When "Verify copied files" is on, FileCraft SHALL compare a checksum of each copied file with its source and SHALL report any mismatch as an error of the operation.

#### Scenario: Corrupted copy detected
- **WHEN** verification is on and a copied file's checksum differs from its source
- **THEN** the operation reports the file as failed with the reason "verification failed"

### Requirement: Operation safety
FileCraft SHALL refuse to move or copy a folder into itself or into one of its descendants. Recursive operations SHALL never follow symbolic links that lead outside the selected items; they SHALL copy or delete the link itself.

#### Scenario: Move a folder into itself
- **WHEN** the user drags the folder "A" onto its subfolder "A/B"
- **THEN** FileCraft refuses the drop and explains why

## ADDED Requirements

### Requirement: Inspector panel
View > Show Inspector (⌥⌘I) SHALL toggle an inspector panel on the trailing side of the window. The inspector SHALL show information about the active pane's selection, or about the current folder when nothing is selected, and SHALL update when the selection changes.

#### Scenario: Inspector follows the selection
- **WHEN** the inspector is open and the user selects "photo.jpg" in the active pane
- **THEN** the inspector shows the information for "photo.jpg"

### Requirement: Get Info windows
File > Get Info (⌘I) SHALL open one info window per selected item, with the same sections as the inspector. An info window SHALL stay bound to its item even when the item is renamed or moved. When more than ten items are selected, FileCraft SHALL ask for confirmation before opening the windows.

#### Scenario: Confirmation for many items
- **WHEN** 25 items are selected and the user presses ⌘I
- **THEN** FileCraft asks "Open 25 info windows?" (localized) before opening them

### Requirement: Inspector sections
The inspector SHALL show these sections, each collapsible with a persistent expanded state: Preview, General, Tags, Permissions, Open With, Attributes and Extended Attributes. Sections that do not apply to the selection, such as Open With for a folder, SHALL be hidden.

#### Scenario: Sections for a folder
- **WHEN** the inspector shows a folder
- **THEN** Preview, General, Tags, Permissions, Attributes and Extended Attributes appear and Open With does not

### Requirement: Preview section
The Preview section SHALL show a Quick Look preview of a single selected item, including playback controls for audio and video.

#### Scenario: Preview a video
- **WHEN** a single video file is selected
- **THEN** the Preview section shows the video with playback controls

### Requirement: General section
The General section SHALL show the icon, an editable name, kind, size in bytes and on disk, item count for folders (calculated in the background), location as a clickable path, the created, modified, last opened and added dates, and, where available, version, image dimensions, media duration and the target of an alias or symbolic link.

#### Scenario: Folder item count
- **WHEN** the inspector shows a folder containing 1,240 items
- **THEN** the General section shows a progress indicator and then "1,240 items" with the folder's total size

#### Scenario: Rename from the inspector
- **WHEN** the user edits the name field to "Summary.pdf" and presses Return
- **THEN** the item is renamed with the validation rules of `file-operations` and the rename can be undone

### Requirement: Tags section
The Tags section SHALL show the item's tags and let the user add tags, with suggestions from existing tags, and remove tags.

#### Scenario: Add an existing tag
- **WHEN** the user types "Wo" in the tag field and accepts the suggestion "Work"
- **THEN** the item carries the tag "Work"

### Requirement: Permissions section
The Permissions section SHALL show owner, group and read, write and execute permissions for owner, group and everyone as toggles plus the octal mode, and SHALL list access control entries read-only. For folders it SHALL offer "Apply to Enclosed Items…" with confirmation. A change the user is not permitted to make SHALL be routed through the privileged helper after authentication.

#### Scenario: Make a script executable
- **WHEN** the user turns on execute for the owner of "build.sh"
- **THEN** the mode of "build.sh" changes accordingly and the octal value updates

#### Scenario: Change requires administrator rights
- **WHEN** the user changes the group of a file owned by root
- **THEN** FileCraft asks for administrator authentication and performs the change through the privileged helper

### Requirement: Open With section
The Open With section SHALL show the application that opens the selected file and SHALL let the user choose another one for this file. "Change All…" SHALL, after confirmation, make the chosen application the default for all files of the same type.

#### Scenario: Change the default app for a type
- **WHEN** the user chooses another editor for "notes.md" and clicks "Change All…" and confirms
- **THEN** all Markdown files open with that editor

### Requirement: Attributes and extended attributes
The Attributes section SHALL offer toggles for Locked, Hide Extension and Hidden. The Extended Attributes section SHALL list the names and sizes of the item's extended attributes, read-only.

#### Scenario: Hide a file
- **WHEN** the user turns on Hidden for "draft.txt"
- **THEN** "draft.txt" disappears from views that do not show hidden files

### Requirement: Multiple selection summary
When several items are selected, the inspector SHALL show the number of items, their total size (calculated in the background) and a breakdown by kind. Tags, Locked and Hide Extension SHALL be editable for all selected items at once, with a mixed state when items differ.

#### Scenario: Tag several items
- **WHEN** five files are selected and the user adds the tag "Archive" in the inspector
- **THEN** all five files carry the tag "Archive"

### Requirement: Edits are immediate and undoable
Changes made in the inspector or an info window SHALL apply when committed (Return, toggle click or leaving the field), SHALL show errors inline, and SHALL be undoable with Edit > Undo.

#### Scenario: Undo a tag change
- **WHEN** the user removes a tag in the inspector and presses ⌘Z
- **THEN** the tag is restored

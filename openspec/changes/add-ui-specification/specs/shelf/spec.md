## ADDED Requirements

### Requirement: Shelf panel
The shelf SHALL be a panel below the content area that collects references to files and folders. It SHALL be toggled with View > Show Shelf or the Shelf toolbar item. The shelf's contents SHALL be shared by all browser windows.

#### Scenario: Shared contents
- **WHEN** the user adds a file to the shelf in one window and shows the shelf in another window
- **THEN** the other window's shelf contains the same file

### Requirement: Adding items
Items SHALL be added by dropping them on the shelf or with File > Add to Shelf for the selection. The shelf SHALL store references, not copies, and SHALL ignore items it already contains.

#### Scenario: Add by dragging
- **WHEN** the user drags three files from a pane onto the shelf
- **THEN** the shelf shows the three files and the files stay in their folder

### Requirement: Item display
The shelf SHALL show each item with its icon and name in a scrollable row, with the full path in a tooltip. Items that no longer exist or cannot be reached SHALL appear dimmed.

#### Scenario: Item deleted elsewhere
- **WHEN** a file on the shelf is deleted by another application
- **THEN** the shelf shows it dimmed with Remove from Shelf available

### Requirement: Using shelf items
Items dragged out of the shelf SHALL follow the drag-and-drop rules of `file-views`. The shelf SHALL offer Copy Items to Current Folder and Move Items to Current Folder, which use the active pane's current folder, as well as Quick Look, Reveal in Pane, Remove from Shelf and Clear Shelf. Moved items SHALL stay on the shelf, pointing to their new location. When "Remove items after dragging them out" is on in Settings, items dragged out SHALL leave the shelf.

#### Scenario: Collect and move
- **WHEN** the shelf holds four files from different folders and the user chooses Move Items to Current Folder
- **THEN** the four files move into the active pane's current folder through the operation queue
- **AND** the shelf entries point to the new locations

### Requirement: Shelf persistence
The shelf's contents SHALL persist across relaunches and SHALL keep pointing to items that are renamed or moved on the same volume.

#### Scenario: Survive relaunch
- **WHEN** the user quits FileCraft with two items on the shelf and relaunches it
- **THEN** the shelf contains the same two items

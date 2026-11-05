## ADDED Requirements

### Requirement: Sidebar sections
The sidebar SHALL show the sections Favorites, Locations, iCloud and Tags, in that order. Each section SHALL be collapsible, and its collapsed state SHALL persist. Sections SHALL be hidden or shown according to Settings; the iCloud section SHALL also be hidden when iCloud Drive is not enabled.

#### Scenario: Collapse a section
- **WHEN** the user collapses Tags and opens a new window
- **THEN** the new window's sidebar shows Tags collapsed

### Requirement: Favorites management
Favorites SHALL initially contain Home, Desktop, Documents, Downloads and Applications. The user SHALL be able to add folders or files by dragging them into the section or with File > Add to Sidebar (⌃⌘T), remove entries from their context menu, and reorder entries by dragging. Favorites SHALL be stored as bookmarks so that they keep working after the item is renamed or moved.

#### Scenario: Add a folder
- **WHEN** the user selects "~/Projects" and presses ⌃⌘T
- **THEN** "Projects" appears at the end of Favorites in every browser window

#### Scenario: Favorite follows a rename
- **WHEN** a favorite folder "Projects" is renamed to "Work" on disk
- **THEN** the favorite shows "Work" and still opens the folder

### Requirement: Navigate from the sidebar
Clicking a sidebar item SHALL show it in the current tab of the active pane. ⌘-clicking SHALL open it in a new tab of the active pane. A file in Favorites SHALL open with its default application.

#### Scenario: Open in new tab
- **WHEN** the user ⌘-clicks "Downloads" in the sidebar
- **THEN** a new tab showing "Downloads" opens in the active pane

### Requirement: Volumes in Locations
Locations SHALL list the computer, mounted local, external, disk image and network volumes, updated within two seconds of mount or unmount events. Ejectable or unmountable volumes SHALL show an eject button. Each volume SHALL show its capacity and available space in a tooltip and, when enabled in Settings, as a usage bar. When ejecting fails because the volume is in use, FileCraft SHALL show a localized alert explaining that the volume is busy.

#### Scenario: USB drive connected
- **WHEN** the user connects a USB drive
- **THEN** the drive appears in Locations with an eject button within two seconds

#### Scenario: Eject from the sidebar
- **WHEN** the user clicks the eject button of a disk image
- **THEN** the image is unmounted and disappears from Locations, and panes showing it switch to the home folder

### Requirement: Tags section
The Tags section SHALL list the user's Finder tags with their colors. Selecting a tag SHALL show, in the current tab, a virtual location listing all items carrying that tag, found through Spotlight.

#### Scenario: Show tagged items
- **WHEN** the user clicks the tag "Red"
- **THEN** the current tab lists all items tagged "Red" and the path bar shows the tag as the location

### Requirement: Sidebar drop targets
Dropping items on a folder or volume entry SHALL move or copy them using the drag-and-drop rules of `file-views`. Dropping items on a tag SHALL add that tag to them.

#### Scenario: Tag by dropping
- **WHEN** the user drops two files on the tag "Blue"
- **THEN** both files carry the "Blue" tag and the files stay where they were

### Requirement: Unavailable favorites
A favorite whose item cannot be resolved SHALL appear dimmed. Clicking it SHALL show a localized alert offering Remove from Sidebar and Cancel.

#### Scenario: Favorite on an unmounted volume
- **WHEN** a favorite points into a network volume that is not mounted
- **THEN** the favorite is dimmed, and clicking it explains that the item is unavailable

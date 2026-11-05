## ADDED Requirements

### Requirement: Browser window layout
Each browser window SHALL consist of a toolbar spanning the window top and, from leading to trailing edge, a collapsible sidebar, a content area holding one or two file panes, and a collapsible inspector. A collapsible shelf SHALL appear below the content area when shown.

#### Scenario: Default layout on first launch
- **WHEN** the user opens a browser window with default settings
- **THEN** the window shows the toolbar, the sidebar and a single file pane with path bar and status bar
- **AND** the inspector and the shelf are hidden

### Requirement: File pane composition
Each file pane SHALL contain, from top to bottom, a tab bar, a path bar, the file view and a status bar. The tab bar SHALL follow the tab bar visibility rules of the `tabs-and-dual-pane` capability. Path bar and status bar visibility SHALL be set per window and apply to all panes of that window.

#### Scenario: Hide the status bar
- **WHEN** the user chooses View > Hide Status Bar in a window showing two panes
- **THEN** the status bar disappears from both panes of that window
- **AND** the menu item reads "Show Status Bar"

### Requirement: Status bar content
The status bar SHALL show the number of visible items in the current folder, the number and total size of selected items, and the available space on the folder's volume. Counts SHALL respect the active filter and the hidden-files setting. Sizes of selected folders SHALL be included once calculated, with a progress indicator while calculation runs.

#### Scenario: Selection summary
- **WHEN** a folder with 12 visible items is shown and the user selects 3 files totalling 4.2 MB
- **THEN** the status bar shows "3 of 12 selected, 4.2 MB" in the user's language and the volume's available space

#### Scenario: Nothing selected
- **WHEN** no item is selected in a folder with 12 visible items
- **THEN** the status bar shows "12 items" and the available space

### Requirement: Customizable toolbar
The toolbar SHALL be customizable through View > Customize Toolbar… (add, remove and reorder items; icon-only, icon-and-text or text-only display). Available items SHALL include Back/Forward, View Mode, Group/Sort, Action menu, New Folder, Move to Trash, Get Info, Inspector, Dual Pane, Shelf, Show Hidden Files, Quick Look, Share, Compress, Open in Terminal, Eject, Operations and Search. Customization SHALL persist across launches and apply to all browser windows.

#### Scenario: Default toolbar
- **WHEN** the toolbar has never been customized
- **THEN** it shows Back/Forward, View Mode, Group/Sort, Action menu, Share, Dual Pane, Inspector and Search

#### Scenario: Customization persists
- **WHEN** the user adds the Show Hidden Files item and relaunches FileCraft
- **THEN** every browser window shows the Show Hidden Files item at the chosen position

### Requirement: Toolbar commands target the active pane
Toolbar items that act on files or locations SHALL act on the active pane. Items SHALL be disabled when their command is unavailable for the active pane's state.

#### Scenario: Eject unavailable
- **WHEN** the active pane shows a folder on the startup volume and nothing ejectable is selected
- **THEN** the Eject toolbar item is disabled

### Requirement: Multiple browser windows
FileCraft SHALL support any number of browser windows. File > New Window (⌘N) SHALL open a window at the location configured in Settings (default: the home folder). The window title SHALL be the localized display name of the active pane's current location.

#### Scenario: New window
- **WHEN** the user presses ⌘N with default settings
- **THEN** a new browser window opens showing the home folder
- **AND** its title is the home folder's display name

### Requirement: No system window tabbing
FileCraft SHALL disable macOS automatic window tabbing for browser windows, because tabs are managed inside each file pane.

#### Scenario: Window menu without window-tab commands
- **WHEN** the user opens the Window menu
- **THEN** it contains no "Merge All Windows" or "Show Tab Bar" items for system window tabs

### Requirement: Layout toggles
The View menu SHALL provide toggles for Sidebar, Inspector, Shelf, Dual Pane, Path Bar, Status Bar, Tab Bar and Toolbar. Each toggle SHALL show or hide its component without discarding the component's state, and SHALL animate only when Reduce Motion is off.

#### Scenario: Sidebar state survives hiding
- **WHEN** the user collapses the Tags section, hides the sidebar and shows it again
- **THEN** the sidebar reappears with the Tags section still collapsed

### Requirement: Resizable areas
The sidebar, inspector, shelf and the divider between two panes SHALL be resizable by dragging. Each area SHALL enforce a minimum size that keeps its content usable. Sizes SHALL persist per window.

#### Scenario: Inspector width persists
- **WHEN** the user widens the inspector, quits FileCraft and relaunches it
- **THEN** the restored window shows the inspector at the widened size

### Requirement: Window state restoration
Unless restoration is disabled in Settings, FileCraft SHALL restore all browser windows on relaunch, including window frame, visibility and sizes of sidebar, inspector, shelf and panes, and each pane's tabs with location, history, view mode, sort order and scroll position. A location that no longer exists SHALL be replaced by its nearest existing ancestor folder.

#### Scenario: Restore after relaunch
- **WHEN** the user quits with two windows open, one of them in dual-pane mode with three tabs in the left pane
- **THEN** after relaunch both windows reappear with the same panes, tabs and locations

#### Scenario: Restored location was deleted
- **WHEN** a restored tab's folder was deleted while FileCraft was not running
- **THEN** that tab shows the nearest existing parent folder

### Requirement: Full screen and standard window behavior
Browser windows SHALL support full screen (⌃⌘F), minimize (⌘M), zoom and Bring All to Front. In full screen, the toolbar and all panels SHALL remain available.

#### Scenario: Enter full screen
- **WHEN** the user presses ⌃⌘F in a browser window
- **THEN** the window enters full screen with sidebar, panes and inspector unchanged

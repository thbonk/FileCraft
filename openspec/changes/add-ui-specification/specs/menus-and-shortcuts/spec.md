## ADDED Requirements

### Requirement: Menu bar structure
The menu bar SHALL contain the menus FileCraft, File, Edit, View, Go, Tools, Window and Help with at least these commands, in this order:

- **FileCraft**: About FileCraft, Check for Updates…, Settings…, Empty Trash…, Services, Hide FileCraft, Hide Others, Show All, Quit FileCraft
- **File**: New Window, New Tab, New Folder, New Folder with Selection, New Text File, Open, Open With, Open in New Tab, Open in Other Pane, Close Tab, Close Window, Get Info, Rename, Duplicate, Make Alias, Make Symbolic Link, Show Original, Quick Look, Add to Sidebar, Add to Shelf, Copy To…, Move To…, Compress, Compress With Format, Expand, Move to Trash, Delete Immediately…, Put Back, Eject, Tags…
- **Edit**: Undo, Redo, Cut, Copy, Paste, Move Items Here, Copy Path, Copy Path As, Edit Path, Select All, Deselect All, Invert Selection, Select by Pattern…, Find
- **View**: as Icons, as List, as Columns, Group By, Sort By, Folders First, Show Hidden Files, Treat Packages as Folders, Reload, Show Sidebar, Show Inspector, Show Shelf, Dual Pane, Pane Layout, Equalize Pane Sizes, Swap Panes, Show Tab Bar, Show Path Bar, Show Status Bar, Hide Toolbar, Customize Toolbar…, Show View Options, Enter Full Screen
- **Go**: Back, Forward, Enclosing Folder, Recent Folders, Computer, Home, Desktop, Documents, Downloads, Applications, Utilities, iCloud Drive, Library (with ⌥), Go to Folder…
- **Tools**: Batch Rename…, Copy to Other Pane, Move to Other Pane, Show Same Folder in Other Pane, Open in Terminal, Reveal in Finder
- **Window**: Minimize, Zoom, Show Next Tab, Show Previous Tab, Reopen Closed Tab, Recently Closed Tabs, Operations, Bring All to Front
- **Help**: FileCraft Help, Keyboard Shortcuts, Welcome to FileCraft…

#### Scenario: Every command is reachable from the menu bar
- **WHEN** the user looks for any command defined in the FileCraft capabilities, such as Batch Rename… or Swap Panes
- **THEN** the command exists in the menu bar at the listed position

### Requirement: Command validation
Menu items SHALL be enabled only when their command applies to the active window, pane and selection. Toggle items SHALL show their current state through a checkmark or a title that names the next action, such as "Show Hidden Files" or "Hide Hidden Files".

#### Scenario: Nothing selected
- **WHEN** nothing is selected in the active pane
- **THEN** Duplicate, Make Alias, Show Original and Move to Trash are disabled

### Requirement: Default keyboard shortcuts
FileCraft SHALL assign these default shortcuts. Each shortcut SHALL trigger its command from any browser window, and none SHALL collide with a macOS system-wide shortcut.

| Command | Shortcut | Command | Shortcut |
|---|---|---|---|
| Settings… | ⌘, | Show Hidden Files | ⇧⌘. |
| Empty Trash… | ⇧⌘⌫ | Show Sidebar | ⌃⌘S |
| New Window | ⌘N | Show Inspector | ⌥⌘I |
| New Tab | ⌘T | Dual Pane | ⌥⌘B |
| New Folder | ⇧⌘N | Show Path Bar | ⌥⌘P |
| New Folder with Selection | ⌃⌘N | Show Status Bar | ⌘/ |
| New Text File | ⌥⌘N | Hide Toolbar | ⌥⌘T |
| Open | ⌘O, ⌘↓ | Show View Options | ⌘J |
| Close Tab | ⌘W | Enter Full Screen | ⌃⌘F |
| Close Window | ⇧⌘W | Back | ⌘[ |
| Get Info | ⌘I | Forward | ⌘] |
| Duplicate | ⌘D | Enclosing Folder | ⌘↑ |
| Make Alias | ⌃⌘A | Computer | ⇧⌘C |
| Show Original | ⌘R | Home | ⇧⌘H |
| Quick Look | ⌘Y, Space | Desktop | ⇧⌘D |
| Add to Sidebar | ⌃⌘T | Documents | ⇧⌘O |
| Move to Trash | ⌘⌫ | Downloads | ⌥⌘L |
| Delete Immediately… | ⌥⌘⌫ | Applications | ⇧⌘A |
| Eject | ⌘E | Utilities | ⇧⌘U |
| Undo / Redo | ⌘Z / ⇧⌘Z | iCloud Drive | ⇧⌘I |
| Cut / Copy / Paste | ⌘X / ⌘C / ⌘V | Go to Folder… | ⇧⌘G |
| Move Items Here | ⌥⌘V | Batch Rename… | ⇧⌘R |
| Copy Path | ⌥⌘C | Copy to Other Pane | F5 |
| Select All | ⌘A | Move to Other Pane | F6 |
| Deselect All | ⌥⌘A | Minimize | ⌘M |
| Find | ⌘F | Show Next Tab | ⇧⌘], ⌃⇥ |
| as Icons / List / Columns | ⌘1 / ⌘2 / ⌘3 | Show Previous Tab | ⇧⌘[, ⌃⇧⇥ |
| Reopen Closed Tab | ⇧⌘T | | |

#### Scenario: Shortcut triggers command
- **WHEN** the user presses ⇧⌘G in a browser window
- **THEN** the Go to Folder sheet opens for the active tab

### Requirement: Keyboard layout adaptation
Shortcuts SHALL adapt to the active keyboard layout so that each shortcut is typeable on German and other non-US layouts, and the menus SHALL display the adapted key combination.

#### Scenario: German keyboard layout
- **WHEN** the active keyboard layout is German
- **THEN** the Back and Forward commands have shortcuts that can be typed on that layout and the menu shows them

### Requirement: Item context menu
Secondary-clicking a selected item SHALL show a context menu with Open, Open With, Open in New Tab, Open in Other Pane (with dual pane on), Quick Look, Get Info, Rename, Duplicate, Make Alias, Copy, Copy Path, Compress, Move to Trash, tag colors, Add to Shelf, Add to Sidebar, Reveal in Finder, Open in Terminal for folders, and the applicable system Services. Commands SHALL act on all selected items.

#### Scenario: Context menu on several items
- **WHEN** the user secondary-clicks one of three selected files
- **THEN** the context menu's commands act on all three files

### Requirement: Background context menu
Secondary-clicking an empty area of a file view SHALL show New Folder, New Text File, Paste, Get Info for the current folder, Group By, Sort By, Show View Options, Show Hidden Files and Open in Terminal.

#### Scenario: Paste via context menu
- **WHEN** files are on the pasteboard and the user secondary-clicks an empty area and chooses Paste
- **THEN** the files are copied into the current folder

### Requirement: Other context menus
Sidebar entries SHALL offer Open in New Tab, Get Info, Eject (for volumes) and Remove from Sidebar (for favorites). Tabs SHALL offer Close Tab, Close Other Tabs and Move to Other Pane. Path bar segments SHALL offer Open in New Tab, Copy Path and Open in Terminal. Shelf items SHALL offer Quick Look, Reveal in Pane and Remove from Shelf.

#### Scenario: Remove a favorite
- **WHEN** the user secondary-clicks a favorite and chooses Remove from Sidebar
- **THEN** the favorite disappears from Favorites in all windows

### Requirement: Keyboard Shortcuts window
Help > Keyboard Shortcuts SHALL show a searchable, localized list of all default shortcuts grouped by menu.

#### Scenario: Look up a shortcut
- **WHEN** the user types "Trash" into the Keyboard Shortcuts window's search field
- **THEN** the list shows Move to Trash, Delete Immediately… and Empty Trash… with their shortcuts

### Requirement: Dock menu
FileCraft's Dock menu SHALL offer New Window and the five most recent folders.

#### Scenario: Open a recent folder from the Dock
- **WHEN** the user chooses a recent folder from FileCraft's Dock menu
- **THEN** FileCraft opens that folder in a new tab of the frontmost browser window

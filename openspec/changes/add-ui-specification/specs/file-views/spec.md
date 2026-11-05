## ADDED Requirements

### Requirement: View modes
Each tab SHALL display its location in one of three view modes: icons (⌘1), list (⌘2) or columns (⌘3). The mode SHALL be switchable from the View menu, the toolbar and the keyboard, and SHALL keep the current selection when switched.

#### Scenario: Switch to column view
- **WHEN** the user selects two files in list view and presses ⌘3
- **THEN** the tab shows column view with the same two files selected

### Requirement: List view columns
List view SHALL always show the Name column and SHALL offer the optional columns Date Modified, Date Created, Date Last Opened, Date Added, Size, Kind, Extension, Tags, Version, Permissions, Owner and Group. Columns SHALL be resizable and reorderable, and their visibility SHALL be toggled from the column header's context menu or the view options.

#### Scenario: Show the Permissions column
- **WHEN** the user enables Permissions in the column header's context menu
- **THEN** a Permissions column appears showing each item's mode in symbolic form, for example "rwxr-xr-x"

### Requirement: Hierarchical list view
List view SHALL show a disclosure control for each folder that expands its contents inline. → and ⌘→ SHALL expand the selected folder, ← and ⌘← SHALL collapse it, and ⌥-clicking the disclosure control SHALL expand or collapse all nested folders. Expansion state SHALL persist per tab.

#### Scenario: Expand inline
- **WHEN** the user selects a folder in list view and presses →
- **THEN** the folder's items appear indented below it without changing the tab's location

### Requirement: Sorting
Items SHALL be sortable by name, kind, size, date modified, date created, date last opened, date added, extension and tags, in ascending or descending order. Clicking a list column header SHALL sort by that column and clicking again SHALL reverse the order. Name sorting SHALL use the localized standard comparison, so numbers compare numerically. A "Folders First" option SHALL keep folders above files regardless of the sort key.

#### Scenario: Numeric-aware name sorting
- **WHEN** a folder contains "File 10", "File 2" and "File 1" and is sorted by name ascending
- **THEN** the order is "File 1", "File 2", "File 10"

#### Scenario: Folders first
- **WHEN** "Folders First" is on and the folder is sorted by date modified
- **THEN** all folders appear before all files, each group sorted by date modified

### Requirement: Grouping
Each tab SHALL offer grouping by None, Kind, Date Modified, Date Created, Size, Extension or Tags. Grouped views SHALL show each group under a localized header and SHALL sort items within each group by the current sort key.

#### Scenario: Group by kind
- **WHEN** the user chooses Group By > Kind in a folder containing images and PDFs
- **THEN** items appear under the headers "Image" and "PDF document" (localized)

### Requirement: Icon view
Icon view SHALL arrange items in a grid that reflows with the pane width. It SHALL offer an icon size from 16 to 512 points, label position below or to the right of the icon, and optional item info (for example image dimensions or a folder's item count) below the name. Free positioning of icons is not supported.

#### Scenario: Change icon size
- **WHEN** the user moves the icon size slider in the view options from 64 to 128 points
- **THEN** all icons in the tab grow to 128 points and the grid reflows

### Requirement: Column view
Column view SHALL show the location hierarchy as side-by-side columns where selecting a folder opens its contents in the next column. Selecting a single file SHALL show a preview column with the file's preview and key metadata when the preview column option is on. Column widths SHALL be resizable, and the view SHALL scroll to keep the active column visible.

#### Scenario: Preview column
- **WHEN** the user selects a PDF in column view with the preview column enabled
- **THEN** a final column shows the PDF's preview, kind, size and modification date

### Requirement: Item presentation
Items SHALL be shown with their system icon or thumbnail and their localized display name. File extensions SHALL be shown according to the "Always show file extensions" setting and each item's own "hide extension" flag. Aliases and symbolic links SHALL carry a link badge, tagged items SHALL show their tag colors, and dates SHALL use relative formatting ("Today, 10:42") when that setting is on.

#### Scenario: Localized folder names
- **WHEN** the system language is German and the user views the root of the startup volume
- **THEN** the Applications folder is shown as "Programme"

### Requirement: Hidden files and package contents
View > Show Hidden Files (⇧⌘.) SHALL toggle the display of hidden items in all panes of all windows; shown hidden items SHALL appear dimmed. Packages SHALL be shown as single items unless "Show Package Contents" is used on a package or "Treat Packages as Folders" is enabled for the tab.

#### Scenario: Reveal hidden files
- **WHEN** the user presses ⇧⌘. in a home folder containing ".zshrc"
- **THEN** ".zshrc" appears dimmed in every open pane showing that folder

### Requirement: Folder size calculation
When "Calculate Folder Sizes" is on, list view SHALL compute folder sizes in the background, show a progress indicator in the Size cell until finished, cache results until the folder changes, and cancel pending calculations when the tab leaves the folder.

#### Scenario: Leave before calculation ends
- **WHEN** folder sizes are being calculated and the user navigates to another folder
- **THEN** the calculations for the previous folder stop

### Requirement: Thumbnails
When icon previews are enabled, the views SHALL replace generic icons with Quick Look thumbnails for supported files. Thumbnails SHALL be generated asynchronously and SHALL never block scrolling or selection.

#### Scenario: Scroll a folder of photos
- **WHEN** the user scrolls quickly through a folder of 2,000 photos in icon view
- **THEN** scrolling stays fluid and thumbnails replace generic icons as they become ready

### Requirement: Selection
The views SHALL support single selection by click, range extension with ⇧-click and ⇧-arrow keys, toggling with ⌘-click, Select All (⌘A), Deselect All (⌥⌘A) and Invert Selection, plus rubber-band selection in icon view. Selection SHALL survive view-mode switches and on-disk changes to unrelated items.

#### Scenario: Selection survives an external change
- **WHEN** two files are selected and another app creates a new file in the same folder
- **THEN** the new file appears and the two files stay selected

### Requirement: Keyboard navigation
Arrow keys SHALL move the selection, typing characters SHALL select the first item whose name starts with the typed prefix (the prefix resets after one second without typing), ⌘↓ SHALL open the selection, Space SHALL toggle Quick Look, and Escape SHALL cancel an inline rename. Return SHALL start renaming the selected item unless Settings assign Return to open.

#### Scenario: Type to select
- **WHEN** the user types "rep" quickly in a folder containing "Report.pdf"
- **THEN** "Report.pdf" becomes the selected item

### Requirement: Opening items
Double-clicking a folder SHALL show it in the current tab, unless Settings choose a new tab or a new window. ⌘-double-click SHALL open a folder in a new tab. Double-clicking a file SHALL open it with its default application, and double-clicking an archive SHALL follow the archive setting (expand or open).

#### Scenario: Open folder in new tab
- **WHEN** the user ⌘-double-clicks the folder "Projects"
- **THEN** a new tab showing "Projects" opens in the same pane and becomes the current tab

### Requirement: Quick Look
Space or ⌘Y SHALL open the Quick Look preview for the selected items. While the preview is open, arrow keys SHALL move the selection and the preview SHALL follow it.

#### Scenario: Browse with Quick Look
- **WHEN** Quick Look is open for "a.jpg" and the user presses ↓
- **THEN** the next item becomes selected and Quick Look shows it

### Requirement: Drag and drop
Items SHALL be draggable within a pane, between panes, between windows, to the sidebar, to the shelf and to other applications. Dropping SHALL move items on the same volume and copy them across volumes; holding ⌥ SHALL force a copy, ⌘ SHALL force a move and ⌥⌘ SHALL create aliases. Folders SHALL spring open when an item hovers over them for the configured delay, and pressing Space SHALL open them immediately.

#### Scenario: Copy across volumes
- **WHEN** the user drags a file from the startup volume onto a folder on an external drive
- **THEN** the file is copied and the original stays in place

#### Scenario: Spring-loaded folder
- **WHEN** the user drags a file and hovers over a folder for the configured delay
- **THEN** the folder opens in the pane so the user can continue the drag inside it

### Requirement: Live updates
Each view SHALL reflect changes made on disk by any process within one second, without resetting scroll position or the selection of unaffected items.

#### Scenario: File created by another app
- **WHEN** another app saves a new file into the folder shown in a pane
- **THEN** the file appears in the pane within one second

### Requirement: Large folder performance
Directory enumeration and metadata loading SHALL run off the main thread. For a folder with 10,000 items on a local SSD, the first visible items SHALL appear within 500 ms, and the remaining items SHALL load without blocking interaction.

#### Scenario: Open a large folder
- **WHEN** the user opens a local folder containing 10,000 files
- **THEN** visible rows appear within 500 ms and the user can scroll while loading continues

### Requirement: Empty, loading and error states
A pane SHALL show a localized empty-folder message for empty folders, a loading indicator when loading takes longer than 300 ms, and an error state with actions when a location cannot be read. A permission error SHALL offer opening the Full Disk Access settings and, when the privileged helper can help, "Authenticate to View".

#### Scenario: Protected folder without access
- **WHEN** the user opens a folder that FileCraft is not permitted to read
- **THEN** the pane explains the error and offers the relevant actions instead of showing an empty list

### Requirement: View options
View > Show View Options (⌘J) SHALL open a panel for the active tab with the settings relevant to its view mode: icon size, text size, label position, item info, icon previews, list columns, relative dates, folder sizes, Folders First, grouping and sorting. Changes SHALL apply immediately to the tab. "Use as Defaults" SHALL make the current options the default for new tabs in that view mode.

#### Scenario: Apply options as defaults
- **WHEN** the user turns on relative dates in the view options and clicks "Use as Defaults"
- **THEN** every newly opened tab in list view uses relative dates

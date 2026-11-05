## ADDED Requirements

### Requirement: Tabs per pane
Each pane SHALL hold one or more tabs, each with its own location, history, view mode, view options and selection. File > New Tab (⌘T) SHALL add a tab after the current one, showing the current location or the home folder as configured in Settings. Each tab SHALL show the location's icon and display name, with the full path in its tooltip.

#### Scenario: New tab
- **WHEN** the active pane shows "~/Documents" and the user presses ⌘T with default settings
- **THEN** a second tab showing "~/Documents" opens to the right of the current tab and becomes current

### Requirement: Closing tabs
File > Close Tab (⌘W) SHALL close the current tab of the active pane, and SHALL close the window when it is the window's only tab in its only pane. Closing the last tab of the second pane SHALL turn dual pane off. A tab's context menu SHALL offer Close Tab and Close Other Tabs.

#### Scenario: Close the last tab of the second pane
- **WHEN** the second pane has one tab and the user presses ⌘W while it is active
- **THEN** dual pane turns off and the window keeps the first pane

### Requirement: Switching and reordering tabs
⌃⇥ and ⇧⌘] SHALL activate the next tab and ⌃⇧⇥ and ⇧⌘[ the previous tab of the active pane, wrapping around at the ends. Tabs SHALL be reorderable by dragging, and dragging a tab onto the other pane's tab bar SHALL move it to that pane.

#### Scenario: Move a tab to the other pane
- **WHEN** the user drags a tab from the left pane's tab bar onto the right pane's tab bar
- **THEN** the tab, with its history, appears in the right pane and disappears from the left pane

### Requirement: Reopen closed tabs
Each window SHALL remember its ten most recently closed tabs. Window > Reopen Closed Tab (⇧⌘T) SHALL restore the most recently closed tab, with its location and history, in the pane it came from, and Window > Recently Closed Tabs SHALL list the remembered tabs.

#### Scenario: Undo an accidental close
- **WHEN** the user closes a tab showing "Invoices" and presses ⇧⌘T
- **THEN** a tab showing "Invoices" with its previous history reappears

### Requirement: Tab bar visibility
When "Hide tab bar with a single tab" is on (the default), a pane with one tab SHALL hide its tab bar. View > Show Tab Bar SHALL force the tab bar to show for all panes of the window.

#### Scenario: Second tab shows the tab bar
- **WHEN** a pane with one tab and a hidden tab bar gets a second tab
- **THEN** the pane's tab bar appears

### Requirement: Dual pane
View > Dual Pane (⌥⌘B) and the Dual Pane toolbar item SHALL show or hide a second pane. The panes SHALL be arranged side by side or stacked, chosen via View > Pane Layout. View > Equalize Pane Sizes SHALL give both panes equal space and View > Swap Panes SHALL exchange their contents. Hiding the second pane SHALL keep its tabs, and showing it again SHALL restore them.

#### Scenario: Turn on dual pane for the first time
- **WHEN** the user presses ⌥⌘B in a single-pane window showing "~/Documents"
- **THEN** a second pane appears side by side, showing "~/Documents" in one tab

#### Scenario: Hidden pane keeps its tabs
- **WHEN** the second pane has three tabs and the user hides and then shows it again
- **THEN** the second pane reappears with the same three tabs

### Requirement: Active pane
Exactly one pane per window SHALL be active. Clicking in a pane or moving keyboard focus into it SHALL make it active. The active pane SHALL be indicated by an accent-colored path bar and a focus outline, so that the distinction does not rely on color alone. Menu commands, toolbar items, the inspector and the status bar's selection data SHALL refer to the active pane. With dual pane on and focus in a file view, Tab SHALL move focus to the other pane's file view.

#### Scenario: Switch with Tab
- **WHEN** dual pane is on, the left pane is active and the user presses Tab
- **THEN** the right pane becomes active and the inspector shows the right pane's selection

### Requirement: Cross-pane commands
With dual pane on, FileCraft SHALL offer Copy to Other Pane (F5), Move to Other Pane (F6), Show Same Folder in Other Pane and Open in Other Pane (for a selected folder). These commands SHALL use the other pane's current folder as the destination or target and SHALL be disabled when dual pane is off.

#### Scenario: Copy with F5
- **WHEN** the left pane is active with two files selected and the right pane shows "/Volumes/Backup"
- **THEN** pressing F5 copies both files into "/Volumes/Backup" through the operation queue

#### Scenario: Mirror the location
- **WHEN** the user chooses Show Same Folder in Other Pane while the active pane shows "~/Music"
- **THEN** the other pane's current tab shows "~/Music"

### Requirement: Function key commands
When "Use function keys for file commands" is on (the default), F5 SHALL copy and F6 SHALL move the selection to the other pane, F7 SHALL create a new folder and F8 SHALL move the selection to the Trash. Function key commands SHALL work only while a file view has keyboard focus, and every function key command SHALL also be reachable from the menus.

#### Scenario: New folder with F7
- **WHEN** a file view has focus and the user presses F7
- **THEN** a new folder is created in the active pane's current folder and its name is ready for editing

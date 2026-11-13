## ADDED Requirements

### Requirement: Settings window
FileCraft > Settings… (⌘,) SHALL open a single settings window with the panes General, Browser, Sidebar, Tabs & Panes, File Operations, Compression, Integration, Helper and Advanced. Changes SHALL apply immediately to all windows without relaunching, SHALL persist across launches, and each pane SHALL offer Restore Defaults.

#### Scenario: Immediate effect
- **WHEN** the user turns on "Always show file extensions" in the Browser pane
- **THEN** all open panes show file extensions without a relaunch

### Requirement: General settings
The General pane SHALL offer: location for new windows (Home, Desktop, Documents, last location or a chosen folder; default Home), where folders open on double-click (same tab, new tab or new window; default same tab), restoring windows on relaunch (default on), checking for updates automatically (default on), installing updates automatically (default off), including pre-releases in updates (default off), and showing the welcome window again.

#### Scenario: New windows open in Documents
- **WHEN** the user sets new windows to open in Documents and presses ⌘N
- **THEN** the new window shows the Documents folder

### Requirement: Software updates
FileCraft SHALL update itself through the Sparkle framework from an appcast served over HTTPS, and SHALL install only updates whose EdDSA signature matches the public key embedded in the app. FileCraft > Check for Updates… SHALL check immediately; with automatic checks on, FileCraft SHALL check at most once a day. When an update is available, FileCraft SHALL show its version and release notes and offer Install Update, Skip This Version and Remind Me Later. FileCraft SHALL offer pre-releases, which the appcast lists on the channel `beta`, only while including pre-releases is on; final releases are offered either way. The update windows SHALL appear in English or German like the rest of FileCraft.

#### Scenario: Manual check finds an update
- **WHEN** the appcast lists a newer version and the user chooses FileCraft > Check for Updates…
- **THEN** FileCraft shows the new version and its release notes with Install Update, Skip This Version and Remind Me Later

#### Scenario: Tampered update rejected
- **WHEN** a downloaded update's signature does not match the embedded public key
- **THEN** FileCraft does not install the update and reports that it could not be verified

#### Scenario: Automatic installation off
- **WHEN** automatic checks are on, automatic installation is off and an update is found
- **THEN** FileCraft asks the user before installing the update

#### Scenario: Pre-releases only on request
- **WHEN** the appcast lists a pre-release newer than the installed version and including pre-releases is off
- **THEN** FileCraft does not offer the pre-release, and offers it once the user turns including pre-releases on

#### Scenario: Update while operations run
- **WHEN** the user chooses Install Update while a copy is running
- **THEN** FileCraft shows the quit confirmation of the `file-operations` capability before relaunching

### Requirement: Browser settings
The Browser pane SHALL offer: default view mode (default list), show hidden files (default off), always show file extensions (default off), Folders First (default on), relative dates (default on), calculate folder sizes (default off), icon previews (default on), browser text size (small, medium, large; default medium), Return key action (rename or open; default rename), spring-loaded folders (default on) with a delay setting, and treat packages as folders (default off).

#### Scenario: Return opens items
- **WHEN** the user sets the Return key action to open and presses Return on a folder
- **THEN** the folder opens instead of entering rename mode

### Requirement: Sidebar settings
The Sidebar pane SHALL offer visibility toggles for the Favorites, Locations, iCloud and Tags sections and for volume usage bars.

#### Scenario: Hide tags
- **WHEN** the user turns off the Tags section
- **THEN** no browser window shows the Tags section

### Requirement: Tabs and panes settings
The Tabs & Panes pane SHALL offer: location of new tabs (current location or home; default current location), hiding the tab bar with a single tab (default on), default dual-pane layout (side by side or stacked; default side by side) and function keys for file commands (default on).

#### Scenario: Disable function keys
- **WHEN** the user turns off function keys for file commands and presses F5 in a file view
- **THEN** FileCraft performs no copy

### Requirement: File operations settings
The File Operations pane SHALL offer: warning before emptying the Trash (default on), warning before changing an extension (default on), copy verification (default off), and showing the Operations window automatically when an operation takes longer than five seconds (default on).

#### Scenario: Automatic Operations window
- **WHEN** this option is on and a copy takes longer than five seconds
- **THEN** the Operations window opens showing the copy

### Requirement: Compression settings
The Compression pane SHALL offer: default format for Compress (ZIP, tar.gz, tar.bz2, tar.xz; default ZIP), destination for archives and expanded items (same folder as the original or a chosen folder; default same folder), selecting the result after completion (default on), expanding archives on double-click in FileCraft (default on) and moving the archive to the Trash after expanding (default off).

#### Scenario: Trash archive after expanding
- **WHEN** "move archive to Trash after expanding" is on and the user expands "data.zip"
- **THEN** the extracted item appears and "data.zip" is in the Trash

### Requirement: Integration settings
The Integration pane SHALL offer: the terminal application for Open in Terminal (default Terminal); a "Use FileCraft as default file viewer" toggle (default off) that sets the system's file viewer preference, so that other applications' "Show in Finder" requests that honor it open in FileCraft; and removing items from the shelf after dragging them out (default off). Turning the toggle off SHALL make Finder the file viewer again. If the preference cannot be stored, the pane SHALL name the preferences file. The toggle SHALL NOT change which application opens folders, because macOS does not allow other applications to replace Finder as the default application for folders. The pane SHALL also offer "Quit Finder when FileCraft launches" (default off): while it is on, FileCraft quits Finder when it launches and opens Finder again when FileCraft quits; turning it on SHALL first warn that some system features, such as Time Machine, may not work correctly while Finder is not running. And it SHALL offer "Hide Finder's desktop" (default off): FileCraft sets Finder's desktop preference and relaunches Finder, so that the desktop icons stay hidden even while FileCraft is not running; turning it off, Restore Defaults and Reset All Settings SHALL show the desktop again. FileCraft does not draw a desktop of its own.

#### Scenario: Become the default file viewer
- **WHEN** the user turns on "Use FileCraft as default file viewer" and another app that honors this preference reveals a file
- **THEN** FileCraft shows the file's folder with the file selected

#### Scenario: Folders opened by other applications
- **WHEN** the toggle is on and the user runs `open ~/Documents` in Terminal
- **THEN** Finder opens "~/Documents", because macOS keeps Finder as the application for folders

#### Scenario: Turn the toggle off
- **WHEN** the user turns the toggle off and another app that honors the file viewer preference reveals a file
- **THEN** Finder shows the file's folder with the file selected

#### Scenario: Quit Finder on launch
- **WHEN** "Quit Finder when FileCraft launches" is on and FileCraft launches
- **THEN** Finder is no longer running

#### Scenario: Finder returns when FileCraft quits
- **WHEN** "Quit Finder when FileCraft launches" is on and the user quits FileCraft
- **THEN** Finder runs again

#### Scenario: Hide Finder's desktop
- **WHEN** the user turns on "Hide Finder's desktop"
- **THEN** Finder relaunches and the desktop shows no icons

#### Scenario: Show Finder's desktop again
- **WHEN** the user turns "Hide Finder's desktop" off or clicks Restore Defaults in the Integration pane
- **THEN** Finder relaunches and the desktop shows its icons again

### Requirement: Helper settings
The Helper pane SHALL show the privileged helper status and offer the management actions defined in the `privileged-helper` capability.

#### Scenario: Status shown
- **WHEN** the helper waits for approval in System Settings
- **THEN** the Helper pane shows "Waiting for approval" with a button that opens System Settings

### Requirement: Advanced settings
The Advanced pane SHALL offer: size units (decimal, where 1 KB is 1,000 bytes, or binary, where 1 KiB is 1,024 bytes; default decimal), Reset Warnings to show all suppressed warnings again, and Reset All Settings with confirmation.

#### Scenario: Binary units
- **WHEN** the user selects binary units
- **THEN** sizes are shown with binary prefixes, for example "1 KiB" for 1,024 bytes

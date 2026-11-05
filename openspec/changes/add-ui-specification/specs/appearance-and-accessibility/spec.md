## ADDED Requirements

### Requirement: Original and system assets only
FileCraft SHALL use SF Symbols for all interface icons, icons and thumbnails supplied by macOS for files, folders and volumes, and its own original app icon and artwork. The app bundle and repository SHALL NOT contain or derive from any icon, image, sound, interface file, string table, help content or other asset of Path Finder. Assets that ship inside an approved dependency, such as Sparkle's update windows, are allowed.

#### Scenario: Asset audit
- **WHEN** the built app bundle's resources are reviewed before release
- **THEN** every image and icon is an SF Symbol, a system-provided icon, an original FileCraft asset or part of an approved dependency such as Sparkle

### Requirement: System appearance
FileCraft SHALL follow the system appearance, including light and dark mode, the accent color, Increase Contrast and Reduce Transparency, by using standard macOS controls, materials and toolbar and sidebar styles rather than custom chrome.

#### Scenario: Switch to dark mode
- **WHEN** the user switches macOS to dark mode while FileCraft is running
- **THEN** all FileCraft windows switch to dark appearance without a relaunch

### Requirement: Text size
File views, the sidebar and the inspector SHALL use system text styles and SHALL scale with the browser text size setting.

#### Scenario: Large text
- **WHEN** the user sets the browser text size to large
- **THEN** names and metadata in file views, sidebar and inspector are shown larger and rows grow to fit

### Requirement: VoiceOver support
Every control SHALL have a localized accessibility label and, where helpful, a hint. File items SHALL announce their name, kind, size and modification date, and SHALL offer accessibility actions for Open, Quick Look, Rename, Get Info and Move to Trash. Completion or failure of a file operation SHALL be announced.

#### Scenario: VoiceOver reads a file
- **WHEN** VoiceOver focuses the list row of "report.pdf"
- **THEN** VoiceOver reads its name, kind, size and modification date in the user's language

### Requirement: Full keyboard operation
All functions SHALL be usable with the keyboard alone, with visible focus indication and a logical focus order of sidebar, panes, inspector and shelf.

#### Scenario: Move focus through the window
- **WHEN** Full Keyboard Access is on, a single-pane window shows the inspector and the shelf, and the user presses Tab repeatedly starting in the sidebar
- **THEN** focus moves from the sidebar to the file view, then to the inspector, then to the shelf

### Requirement: Reduce Motion
When Reduce Motion is on, FileCraft SHALL replace sliding and zooming animations with fades or immediate changes.

#### Scenario: Toggle the inspector with Reduce Motion
- **WHEN** Reduce Motion is on and the user shows the inspector
- **THEN** the inspector appears without a sliding animation

### Requirement: Information beyond color
Tags, the active pane, errors and status SHALL not be conveyed by color alone: tags SHALL expose their names, the active pane SHALL show a focus outline, and errors SHALL include an icon and text.

#### Scenario: Tag names for color-blind users
- **WHEN** the user hovers over a tag dot in list view or VoiceOver focuses the row
- **THEN** the tag's name is shown or announced

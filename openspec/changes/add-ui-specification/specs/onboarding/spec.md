## ADDED Requirements

### Requirement: Welcome window
On first launch, FileCraft SHALL show a welcome window with the steps Welcome, Full Disk Access and Default File Viewer. The user SHALL be able to finish or skip the window at any step; it SHALL not appear on later launches once finished or skipped.

#### Scenario: First launch
- **WHEN** FileCraft launches for the first time
- **THEN** the welcome window opens in front of the first browser window

#### Scenario: Later launches
- **WHEN** the user skipped the welcome window and relaunches FileCraft
- **THEN** no welcome window appears

### Requirement: Full Disk Access step
The Full Disk Access step SHALL explain why a file manager needs Full Disk Access, show whether FileCraft currently has it, and offer a button that opens the Full Disk Access list in Privacy & Security settings. FileCraft SHALL determine access by attempting to read a location that requires Full Disk Access and SHALL refresh the status whenever it becomes active.

#### Scenario: Grant access
- **WHEN** the status shows "Not granted", the user enables FileCraft in the Full Disk Access list and returns to FileCraft
- **THEN** the step shows "Granted"

### Requirement: Continue without access
FileCraft SHALL remain fully usable without Full Disk Access, except for protected locations, which SHALL show the error state defined in `file-views`.

#### Scenario: Skip the access step
- **WHEN** the user continues without granting Full Disk Access and opens the home folder
- **THEN** the home folder is shown normally

### Requirement: Default file viewer step
The Default File Viewer step SHALL explain that, with this option on, "Show in Finder" requests and folders opened by other applications go to FileCraft, and SHALL offer the same toggle as the Integration settings, set to off by default.

#### Scenario: Enable from the welcome window
- **WHEN** the user turns on the toggle in the welcome window
- **THEN** the Integration settings show FileCraft as the default file viewer

### Requirement: Reopen the welcome window
Help > Welcome to FileCraft… and the General settings SHALL reopen the welcome window at any time.

#### Scenario: Reopen from Help
- **WHEN** the user chooses Help > Welcome to FileCraft…
- **THEN** the welcome window opens at its first step with the current Full Disk Access status

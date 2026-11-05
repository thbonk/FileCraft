## ADDED Requirements

### Requirement: Helper registration through SMAppService
Privileged file operations SHALL be performed by a helper daemon that is embedded in the FileCraft app bundle as a launchd property list in `Contents/Library/LaunchDaemons` and registered, queried and unregistered exclusively through the `SMAppService` daemon API (`SMAppService.daemon(plistName:)`). The deprecated `SMJobBless` API, `AuthorizationExecuteWithPrivileges` and AppleScript-based privilege escalation SHALL NOT be used.

#### Scenario: Registration call
- **WHEN** FileCraft installs the helper
- **THEN** it calls `register()` on the `SMAppService` daemon object for the bundled property list and evaluates the returned `status`

#### Scenario: Bundle check
- **WHEN** the built app bundle is inspected
- **THEN** it contains the helper's launchd property list in `Contents/Library/LaunchDaemons` and no `SMPrivilegedExecutables` entry in its Info.plist

### Requirement: On-demand registration
FileCraft SHALL NOT register the helper at launch. Registration SHALL happen when the user first triggers an operation that needs privileges, or when the user installs the helper in Settings. Before registering, FileCraft SHALL explain in a localized sheet what the helper does and that macOS will ask for approval.

#### Scenario: First privileged operation
- **WHEN** the helper is not registered and the user chooses "Authenticate and Retry" for a failed copy
- **THEN** FileCraft explains the helper, registers it after the user agrees, and continues the operation once the helper is enabled

### Requirement: Background item approval
When the helper's status is "requires approval", FileCraft SHALL explain that the helper must be allowed in System Settings and SHALL offer a button that opens the Login Items & Extensions settings through `SMAppService.openSystemSettingsLoginItems()`. FileCraft SHALL re-check the status when it becomes active again and SHALL resume the pending operation once the helper is enabled. A "not found" status SHALL be reported as a damaged installation.

#### Scenario: User approves the helper
- **WHEN** the status is "requires approval", the user opens System Settings, allows FileCraft's background item and returns to FileCraft
- **THEN** FileCraft detects the enabled status and resumes the pending operation

#### Scenario: User does not approve
- **WHEN** the user returns to FileCraft without allowing the background item
- **THEN** the pending operation stays paused with the explanation and the System Settings button still available

### Requirement: Administrator authentication
Every privileged operation SHALL require administrator authorization obtained through Authorization Services, which presents the system authentication dialog, including Touch ID where available. The helper SHALL verify the authorization for each request before acting. An authorization SHALL be reused for at most five minutes and SHALL be discarded when FileCraft quits.

#### Scenario: Authorization reuse
- **WHEN** the user authenticates for a privileged copy and starts another privileged operation two minutes later
- **THEN** the second operation runs without a new authentication prompt

#### Scenario: Authorization expired
- **WHEN** more than five minutes have passed since the last authentication
- **THEN** the next privileged operation asks for authentication again

### Requirement: Verified connection
The app and the helper SHALL communicate over an XPC Mach service. The helper SHALL accept connections only from code signed with FileCraft's team identifier and bundle identifier, and the app SHALL accept only a helper signed with the same team identifier, both enforced through code signing requirements on the XPC connection.

#### Scenario: Foreign client rejected
- **WHEN** a process that is not FileCraft connects to the helper's Mach service
- **THEN** the helper rejects the connection without executing any request

### Requirement: Restricted operation set
The helper SHALL offer only typed file operations: list folder contents, create folder, copy, move, rename, delete, set owner and group, set permissions and set file flags. It SHALL NOT execute arbitrary commands, run scripts or launch applications.

#### Scenario: No command execution
- **WHEN** the helper's XPC interface is inspected
- **THEN** it exposes only the listed file operations and no method that runs a command, script or application

### Requirement: Path validation
The helper SHALL accept only absolute paths, SHALL resolve them without following symbolic links in the final path component unless the operation targets the link's destination, and SHALL report a clear error for paths it may not modify, such as locations protected by System Integrity Protection.

#### Scenario: Protected system location
- **WHEN** the user tries to delete an item inside "/System"
- **THEN** the operation fails with a localized explanation that the location is protected by macOS

### Requirement: Progress and cancellation
Privileged copy, move and delete operations SHALL report progress to the operation queue and SHALL be cancellable from the Operations window like any other operation.

#### Scenario: Cancel a privileged copy
- **WHEN** a privileged copy into "/Library" is running and the user cancels it
- **THEN** the helper stops and removes the partially copied item

### Requirement: Helper management
Settings SHALL show the helper status (not installed, waiting for approval, enabled, error) and SHALL offer Install Helper, Remove Helper and Open System Settings. Remove Helper SHALL unregister the daemon through `SMAppService`.

#### Scenario: Remove the helper
- **WHEN** the helper is enabled and the user clicks Remove Helper
- **THEN** FileCraft unregisters the daemon and the status changes to "not installed"

### Requirement: Version compatibility
The app and the helper SHALL exchange a protocol version when connecting. On a mismatch, for example after an app update, FileCraft SHALL re-register the helper from the current app bundle before sending requests.

#### Scenario: App updated
- **WHEN** a newer FileCraft version connects to a helper with an older protocol version
- **THEN** FileCraft re-registers the helper and then sends the request

### Requirement: Private logging
The helper SHALL log each request and its outcome to the unified logging system, with file paths marked as private.

#### Scenario: Log entry
- **WHEN** the helper completes a privileged rename
- **THEN** a log entry records the operation type and result, and the paths appear as private data

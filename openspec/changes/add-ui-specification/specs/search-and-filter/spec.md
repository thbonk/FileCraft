## ADDED Requirements

### Requirement: Quick filter
Typing in the toolbar search field with the scope "This Folder" SHALL filter the active tab's items by name as the user types, ignoring case and diacritics. Edit > Find (⌘F) SHALL focus the search field and Escape SHALL clear the filter. While a filter is active, the status bar SHALL show the filter text and the number of matching items.

#### Scenario: Filter by name
- **WHEN** the user types "inv" in a folder with 120 items, 3 of which contain "inv" in their names
- **THEN** the tab shows only those 3 items and the status bar reports 3 of 120 items

#### Scenario: Diacritic-insensitive match
- **WHEN** the user types "uber"
- **THEN** an item named "Über uns.pdf" matches

### Requirement: Search scopes
The search field SHALL offer the scopes This Folder (filter), Subfolders (recursive name search below the current folder) and This Mac (Spotlight). Searches with the Subfolders or This Mac scope SHALL show their results in the active tab as a search results location with an additional Location column. Search results locations SHALL be part of the tab's history.

#### Scenario: Search subfolders
- **WHEN** the user selects the scope Subfolders in "~/Projects" and searches for "README"
- **THEN** the tab lists all matching items below "~/Projects" with their locations

#### Scenario: Back to the folder
- **WHEN** the user presses ⌘[ while viewing search results
- **THEN** the tab returns to the folder where the search started

### Requirement: Search criteria
The search UI SHALL let the user add criteria rows combined with AND: Name (contains, begins with, ends with, is, matches regular expression), Kind (folder, application, document, image, movie, audio, PDF, text, archive), Extension, Date Modified and Date Created (today, within the last N days, weeks or months, before or after a date), Size (greater or less than a value in KB, MB or GB), Tags and Contents. The Contents criterion SHALL be available only with the This Mac scope.

#### Scenario: Large recent images
- **WHEN** the user searches Subfolders with Kind is image, Size greater than 5 MB and Date Modified within the last 7 days
- **THEN** only images larger than 5 MB modified in the last 7 days are listed

### Requirement: Search options
Searches SHALL exclude hidden items and package contents by default and SHALL offer options to include them.

#### Scenario: Include hidden items
- **WHEN** the user enables "Include hidden items" and searches Subfolders for ".env"
- **THEN** hidden ".env" files appear in the results

### Requirement: Progressive and cancellable search
Subfolders searches SHALL run in the background, show results as they are found with a running count, and stop when the user clicks Stop, clears the field or leaves the results. This Mac searches SHALL update their results when matching items change.

#### Scenario: Stop a long search
- **WHEN** a Subfolders search on a large volume has found 300 items and the user clicks Stop
- **THEN** the search ends and the 300 results stay visible

### Requirement: Select by pattern
Edit > Select by Pattern… SHALL select the items in the active tab whose names match a wildcard pattern (for example "*.jpg") or a regular expression, ignoring case unless requested, and SHALL either replace the selection or add to it.

#### Scenario: Select all JPEGs
- **WHEN** the user enters "*.jpg" and chooses Replace Selection
- **THEN** exactly the items whose names end in ".jpg" or ".JPG" are selected

### Requirement: Recent searches
The search field SHALL offer the ten most recent searches, with their scope and criteria, in its menu.

#### Scenario: Repeat a search
- **WHEN** the user chooses a recent search from the search field's menu
- **THEN** the search runs again with the same scope and criteria

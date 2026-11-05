## ADDED Requirements

### Requirement: Batch rename sheet
Tools > Batch Rename… (⇧⌘R) SHALL open a sheet for the selected items in the active pane, showing an ordered list of rename rules and a preview table. The command SHALL be disabled when nothing is selected.

#### Scenario: Open the sheet
- **WHEN** 40 photos are selected and the user presses ⇧⌘R
- **THEN** the batch rename sheet opens with an empty rule list and a preview of the 40 current names

### Requirement: Rename rules
The sheet SHALL offer these rule types: Replace Text (find and replace with case-sensitivity and first, last or all occurrences), Regular Expression (ICU syntax with capture group references such as "$1"), Insert Text (as prefix, as suffix or at a character position), Remove Characters (a count from the start, from the end or at a position), Change Case (lowercase, uppercase, title case, sentence case), Sequence Number (start value, step, zero-padded digit count, position and separator), Date (creation, modification or current date in a selectable format, with position and separator) and Change Extension (replace, remove or lowercase). Rules SHALL be applied in list order and SHALL be addable, removable, reorderable and individually disableable.

#### Scenario: Prefix and sequence
- **WHEN** the rules are Insert Text "Trip_" as prefix and Sequence Number starting at 1 with 3 digits as suffix separated by "_"
- **THEN** "IMG_4711.jpg" previews as "Trip_IMG_4711_001.jpg"

#### Scenario: Regular expression with capture groups
- **WHEN** the rule is Regular Expression "(\d{4})-(\d{2})-(\d{2})" replaced with "$3.$2.$1"
- **THEN** "Report 2026-10-30.pdf" previews as "Report 30.10.2026.pdf"

### Requirement: Rule target
Each rule SHALL apply to the name without extension (the default), to the extension only or to the full name.

#### Scenario: Uppercase extension only
- **WHEN** a Change Case rule set to uppercase targets the extension only
- **THEN** "photo.jpg" previews as "photo.JPG"

### Requirement: Live preview
The preview table SHALL list current and new names and SHALL update within 100 ms of any rule change for up to 1,000 items. Unchanged names SHALL be marked. Empty names, invalid characters, names longer than 255 bytes, duplicate names within the batch and collisions with existing items outside the batch SHALL be highlighted with the reason, and the Rename button SHALL stay disabled while any such error exists, showing the number of errors.

#### Scenario: Duplicate names
- **WHEN** a rule turns "a.txt" and "A.txt" into the same name on a case-insensitive volume
- **THEN** both rows are highlighted as duplicates and Rename is disabled

### Requirement: Item order
The sheet SHALL number items in the order shown in the active view and SHALL offer reordering by name, date modified or date created for sequence and date rules.

#### Scenario: Number by date
- **WHEN** the user sets the order to date created
- **THEN** the sequence numbers in the preview follow the items' creation dates

### Requirement: Execution and undo
Clicking Rename SHALL rename all items as one undoable action, including name exchanges within the batch such as "a" to "b" and "b" to "a". If an item cannot be renamed, FileCraft SHALL revert the renames already made in that batch and report the failure.

#### Scenario: Swap names
- **WHEN** the rules rename "a.txt" to "b.txt" and "b.txt" to "a.txt"
- **THEN** both renames succeed and one Undo restores the original names

#### Scenario: Failure reverts the batch
- **WHEN** the tenth of twenty renames fails because the item is locked
- **THEN** the first nine renames are reverted and FileCraft reports the locked item

### Requirement: Presets
The sheet SHALL let the user save the current rule list as a named preset, apply a preset, and delete presets. Presets SHALL persist across launches.

#### Scenario: Reuse a preset
- **WHEN** the user saved the preset "Photo export" and applies it to a new selection
- **THEN** the rule list matches the preset and the preview updates

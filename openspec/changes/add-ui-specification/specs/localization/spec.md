## ADDED Requirements

### Requirement: Supported languages
FileCraft SHALL be localized in English, its development language, and German. It SHALL use the user's preferred languages, including a per-app language chosen in System Settings, and SHALL fall back to English for any other language.

#### Scenario: German system
- **WHEN** German is the user's first preferred language
- **THEN** all FileCraft menus, windows, alerts and settings appear in German

#### Scenario: Unsupported language
- **WHEN** French is the user's only preferred language
- **THEN** FileCraft appears in English

### Requirement: Complete translation coverage
Every user-visible string SHALL be localizable and translated into German, including menus, toolbar labels, tooltips, settings, alerts, errors (including those originating in the privileged helper), onboarding, accessibility labels and Info.plist strings such as the app's usage descriptions. User-visible text SHALL NOT be hard-coded outside the string catalogs, and the test suite SHALL fail when any string lacks a current German translation.

#### Scenario: Missing translation detected
- **WHEN** a developer adds a new English string without a German translation
- **THEN** the localization coverage test fails and names the string

### Requirement: Plural forms
Strings that depend on a count SHALL use the language's plural rules instead of concatenation.

#### Scenario: Item counts in German
- **WHEN** the status bar shows a folder with one item and then a folder with three items in German
- **THEN** it reads "1 Objekt" and then "3 Objekte"

### Requirement: Locale-aware formatting
Dates, times, numbers, byte counts and relative dates SHALL be formatted with the user's locale, never by concatenating values with fixed separators or units.

#### Scenario: German number format
- **WHEN** a German user views a file of 4,200,000 bytes
- **THEN** its size appears as "4,2 MB"

### Requirement: Localized file system names
Items whose names the system localizes, such as standard folders, SHALL be displayed with their localized display names, while paths typed by the user and copied paths SHALL use the real file system names.

#### Scenario: Applications folder in German
- **WHEN** a German user views the startup volume and copies the path of the folder displayed as "Programme"
- **THEN** the copied path is "/Applications"

### Requirement: Localized names created by FileCraft
Names that FileCraft generates SHALL be localized: in German, a new folder SHALL be named "Neuer Ordner", a duplicate SHALL receive the suffix "Kopie", an alias the suffix "Alias", a new text file the name "Unbenannt.txt" and a multi-item archive the name "Archiv.zip".

#### Scenario: Duplicate in German
- **WHEN** a German user duplicates "Bericht.pdf"
- **THEN** the duplicate is named "Bericht Kopie.pdf"

### Requirement: Locale-aware sorting and matching
Name sorting SHALL use the localized standard comparison, and filtering and searching SHALL ignore case and diacritics according to the user's locale.

#### Scenario: Umlauts sort with their base letters
- **WHEN** a folder contains "Zebra", "Äpfel" and "Birnen" sorted by name in German
- **THEN** the order is "Äpfel", "Birnen", "Zebra"

### Requirement: macOS terminology
German strings SHALL use the established macOS German terms for system concepts, for example "Papierkorb" (Trash), "In den Papierkorb legen" (Move to Trash), "Informationen" (Get Info), "Übersicht" (Quick Look), "Einstellungen" (Settings), "Seitenleiste" (Sidebar), "Pfadleiste" (Path Bar), "Statusleiste" (Status Bar) and "Auswerfen" (Eject), and SHALL follow a glossary maintained in the repository for FileCraft-specific terms.

#### Scenario: Trash command in German
- **WHEN** a German user opens the File menu
- **THEN** the command reads "In den Papierkorb legen"

### Requirement: Layout robustness
Localized strings SHALL never be truncated or clipped in menus, buttons, settings, sheets and alerts at default window sizes. Controls SHALL size to their content. The UI SHALL be verified with German and with a double-length pseudolanguage.

#### Scenario: Pseudolanguage check
- **WHEN** FileCraft runs with the double-length pseudolanguage
- **THEN** no settings label, button title or alert text is truncated

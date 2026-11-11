# B12: customized toolbar order drifts on every launch

Repro for finding B12 of `verification.md`, written as a draft for Feedback Assistant (area: SwiftUI).

## Title

SwiftUI customizable toolbar in a NavigationSplitView window does not restore the customized item order; items move two places left on every launch

## Environment

macOS 27.0.1 (26A434), Xcode 27.1 (27A9275), Swift 6.4

## Description

A window with `NavigationSplitView` and `.toolbar(id:)` saves the user's customized toolbar order, but restores it
wrongly on the next launch. Each customized item ends up two places further left, as many places as the split view
adds toolbar items of its own (the sidebar toggle and the separator). The wrong order is saved again, so items drift
further on every launch and can cross other items, including a search field. The same toolbar without
`NavigationSplitView` keeps its order.

## Steps

1. Run `./run.sh` in this folder. It builds `main.swift` into ToolbarRepro.app, stores a customized order (Operations
   before Search; New Folder, Hidden Files, Open in Terminal and Move to Trash after Search), launches the app five
   times in the background (it quits itself after four seconds) and prints the order AppKit saved after each launch.
2. Run `./run.sh -D NO_SPLIT` for the same app without `NavigationSplitView` and inspector.

By hand: run the app without the four-second quit, choose View > Customize Toolbar…, drag items after the search
field, quit and relaunch a few times.

## Expected

Every launch shows and saves the order the user chose.

## Actual

With `NavigationSplitView`, the order changes on every launch, on screen and in `NSToolbar Configuration browser`:

```
stored:   …, dualPane, inspector, operations, search, newFolder, hiddenFiles, openInTerminal, moveToTrash
launch 1: …, share, operations, dualPane, inspector, hiddenFiles, openInTerminal, search, newFolder, moveToTrash
launch 2: …, groupSort, operations, action, share, dualPane, inspector, search, hiddenFiles, moveToTrash, newFolder, openInTerminal
launch 3: …, backForward, operations, viewMode, groupSort, action, share, dualPane, hiddenFiles, moveToTrash, newFolder, openInTerminal, inspector, search
```

With `-D NO_SPLIT`, every launch keeps the stored order.

## Notes

- `-D NO_INSPECTOR` (split view without `.inspector`) drifts the same way, so the inspector is not involved.
- `-D REMOVE_TOGGLE` (`.toolbar(removing: .sidebarToggle)`) changes the order on the first launch and again later,
  so removing the toggle is no workaround.
- Neither the `NSSearchField` item nor `showsByDefault: false` matters: a plain button as the search item and all items
  shown by default drift the same way.

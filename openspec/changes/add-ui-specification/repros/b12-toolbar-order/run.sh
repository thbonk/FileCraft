#!/bin/zsh
#
# run.sh
# ToolbarRepro
#
# Created by Thomas Bonk on 2026-11-11.
# Copyright 2026 Thomas Bonk <thomas@meandmymac.de>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Builds ToolbarRepro, stores a customized toolbar order for it, launches it LAUNCHES times in the background and
# prints the toolbar order AppKit saved after each launch. Extra arguments are passed to swiftc, for example
# `./run.sh -D NO_SPLIT`. The app's preferences domain is removed at the end.

set -euo pipefail

SOURCE_DIR=${0:A:h}
LAUNCHES=${LAUNCHES:-5}
DOMAIN=de.meandmymac.ToolbarRepro
KEY="NSToolbar Configuration browser"
WORK=$(mktemp -d)
APP=$WORK/ToolbarRepro.app

mkdir -p $APP/Contents/MacOS
cat > $APP/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>de.meandmymac.ToolbarRepro</string>
<key>CFBundleName</key><string>ToolbarRepro</string>
<key>CFBundleExecutable</key><string>ToolbarRepro</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>27.0</string>
</dict></plist>
PLIST
xcrun swiftc -parse-as-library -swift-version 6 -O "$@" $SOURCE_DIR/main.swift -o $APP/Contents/MacOS/ToolbarRepro
codesign -s - --force $APP 2>/dev/null

# The order a user chose in Customize Toolbar: Operations before Search, four items after it.
defaults delete $DOMAIN 2>/dev/null || true
defaults write $DOMAIN $KEY '{
  "TB Display Mode" = 2; "TB Icon Size Mode" = 1; "TB Is Shown" = 1; "TB Size Mode" = 1;
  "TB Item Identifiers" = (NSToolbarFlexibleSpaceItem, "com.apple.SwiftUI.navigationSplitView.toggleSidebar",
    "com.apple.SwiftUI.splitViewSeparator-0d2", backForward, viewMode, groupSort, action, share, dualPane,
    inspector, operations, search, newFolder, hiddenFiles, openInTerminal, moveToTrash);
}'

print "stored:   $(defaults read $DOMAIN $KEY | tr -d ' \n' | sed 's/.*TBItemIdentifiers"=(//; s/);.*//')"
for i in $(seq 1 $LAUNCHES); do
  open -g -W -n $APP
  print "launch $i: $(defaults read $DOMAIN $KEY | tr -d ' \n' | sed 's/.*TBItemIdentifiers"=(//; s/);.*//')"
done

defaults delete $DOMAIN
rm -rf $WORK

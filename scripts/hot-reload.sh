#!/bin/bash
# Build, install and launch Rail with hot reload (InjectionNext + Inject).
# After launch, saving any Swift file under Rail/ patches the running app in ~2–3s.
#
#   scripts/hot-reload.sh            # iPhone (needs "Enable Devices" on in the InjectionNext menu)
#   scripts/hot-reload.sh sim        # iPhone 18 Pro simulator
#   scripts/hot-reload.sh sim -demo -demoScreen seats   # extra args go to the app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE_ID=00008030-001C2569368B802E
SIM_ID=0C3BA4B2-B484-4AD1-84C3-3691421FD58D
BUNDLE_ID=com.ticketparves
# InjectionNext reads compile commands from build logs under ~/Library/Developer,
# so build here rather than in Xcode's custom DerivedData location.
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/Rail-hotreload"

TARGET="device"
if [ "${1:-}" = "sim" ]; then TARGET="sim"; shift; fi

pgrep -x InjectionNext >/dev/null || open -a /Applications/InjectionNext.app

if [ "$TARGET" = "sim" ]; then
    xcrun simctl boot "$SIM_ID" 2>/dev/null || true
    xcodebuild -project "$ROOT/Rail.xcodeproj" -scheme Rail -quiet \
        -destination "platform=iOS Simulator,id=$SIM_ID" -derivedDataPath "$DERIVED" build
    xcrun simctl install "$SIM_ID" "$DERIVED/Build/Products/Debug-iphonesimulator/Rail.app"
    SIMCTL_CHILD_INJECTION_PROJECT_ROOT="$ROOT" \
        xcrun simctl launch --console-pty --terminate-running-process "$SIM_ID" "$BUNDLE_ID" "$@"
else
    xcodebuild -project "$ROOT/Rail.xcodeproj" -scheme Rail -quiet \
        -destination "platform=iOS,id=$DEVICE_ID" -derivedDataPath "$DERIVED" \
        -allowProvisioningUpdates build
    xcrun devicectl device install app --device "$DEVICE_ID" "$DERIVED/Build/Products/Debug-iphoneos/Rail.app"
    DEVICECTL_CHILD_INJECTION_PROJECT_ROOT="$ROOT" \
        xcrun devicectl device process launch --console --terminate-existing --device "$DEVICE_ID" "$BUNDLE_ID" "$@"
fi

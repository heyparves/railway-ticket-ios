#!/usr/bin/env bash
# Rebuilds Rail/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png from RailMark.swift.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

swiftc -parse-as-library -O \
  "$root/Rail/Core/Design/RailMark.swift" \
  "$root/scripts/render-icon.swift" \
  -o "$work/render-icon"
"$work/render-icon" "$root/Rail/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

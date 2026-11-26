#!/usr/bin/env bash
# Switches the mail engine (the NimbraCore package) between its release and a local checkout.
#
#   scripts/local-core.sh on      build against ../core (the nimbra-core repo, cloned next to this one)
#   scripts/local-core.sh off     back to the release in project.yml
#   scripts/local-core.sh status  which one Nimbra.xcodeproj uses
#
# `on` writes project.local.yml (gitignored): it includes project.yml and replaces the
# NimbraCore package with the local path, then generates the project from it. project.yml
# is never touched. XcodeGen has no optional include, so while it is on, regenerate with
# `xcodegen --spec project.local.yml` (or run `on` again): a plain `xcodegen` goes back to
# the release.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL="$ROOT/project.local.yml"
CORE="$ROOT/../core"
PBXPROJ="$ROOT/Nimbra.xcodeproj/project.pbxproj"
MARKER="# Written by scripts/local-core.sh"

ours() { [[ -f "$LOCAL" && "$(head -n 1 "$LOCAL")" == "$MARKER" ]]; }

case "${1:-}" in
  on)
    if [[ ! -f "$CORE/Package.swift" ]]; then
      echo "No nimbra-core package at $CORE." >&2
      echo "Clone it first: git clone https://github.com/nimbra-mail/core ../core" >&2
      exit 1
    fi
    if [[ -f "$LOCAL" ]] && ! ours; then
      echo "$LOCAL exists and was not written by this script; leaving it alone." >&2
      exit 1
    fi
    cat > "$LOCAL" <<EOF
$MARKER
# Builds NimbraCore from the local checkout in ../core instead of the release.
# Generate with: xcodegen --spec project.local.yml. Remove with scripts/local-core.sh off.
# This file is gitignored.
include:
  - project.yml
packages:
  NimbraCore:REPLACE:
    path: ../core
EOF
    (cd "$ROOT" && xcodegen --spec project.local.yml)
    echo "NimbraCore now builds from ../core."
    if [[ ! -d "$CORE/NimbraFFI.xcframework" ]]; then
      echo "No ../core/NimbraFFI.xcframework yet: run ../core/scripts/build-ios-core.sh first," >&2
      echo "and again after every change to the engine (without it, the package uses the release binary)." >&2
    else
      echo "Run ../core/scripts/build-ios-core.sh after every change to the engine."
    fi
    echo "While it is on, regenerate with: xcodegen --spec project.local.yml"
    ;;
  off)
    if [[ -f "$LOCAL" ]] && ! ours; then
      echo "$LOCAL was not written by this script; leaving it alone." >&2
      exit 1
    fi
    rm -f "$LOCAL"
    (cd "$ROOT" && xcodegen)
    echo "NimbraCore now comes from the release in project.yml."
    ;;
  status)
    if [[ ! -f "$PBXPROJ" ]]; then
      echo "No Nimbra.xcodeproj yet: run xcodegen."
    elif awk '/XCLocalSwiftPackageReference/ { found = 1 } END { exit !found }' "$PBXPROJ"; then
      echo "Nimbra.xcodeproj: local ../core"
    else
      echo "Nimbra.xcodeproj: release $(sed -n 's/^ *exactVersion: *//p' "$ROOT/project.yml" | head -n 1) from github.com/nimbra-mail/core"
    fi
    if ours; then
      echo "project.local.yml: present (regenerate with xcodegen --spec project.local.yml)"
    fi
    ;;
  *)
    echo "usage: $0 on|off|status" >&2
    exit 2
    ;;
esac

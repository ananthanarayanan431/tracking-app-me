#!/bin/bash
# Runs the unit tests. With only the Command Line Tools installed, Swift Testing lives outside
# the default search paths, so point the compiler and loader at it.
set -euo pipefail
cd "$(dirname "$0")/.."
DEV="$(xcode-select -p)"
F="$DEV/Library/Developer/Frameworks"
L="$DEV/Library/Developer/usr/lib"
if [ -d "$F/Testing.framework" ] && [ ! -d "$DEV/Platforms" ]; then
  swift test -Xswiftc -F"$F" -Xlinker -F"$F" -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$L" "$@"
else
  swift test "$@"
fi

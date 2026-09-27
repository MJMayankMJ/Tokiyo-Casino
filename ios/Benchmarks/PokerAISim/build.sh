#!/bin/bash
# Builds the headless Poker AI simulator from the app's own engine sources.
# Card.swift imports UIKit only for a suit colour, so it is swapped to AppKit.
#
#   Benchmarks/PokerAISim/build.sh
#   "${TMPDIR:-/tmp}/pokersim/sim" shove 12 100      # see main.swift for scenarios
set -e
H="$(cd "$(dirname "$0")" && pwd)"
R="$H/../../Tokiyo Casino"
E="$R/Poker /Game Engine"
OUT="${TMPDIR:-/tmp}/pokersim"
rm -rf "$OUT/src"
mkdir -p "$OUT/src"
cp "$E"/GameManager*.swift "$E/GameTypes.swift" "$E/HandEvaluator.swift" "$E/AIEngine.swift" \
   "$E"/AI/*.swift "$R/Poker /Models/Player.swift" "$R/Manager/DebugLog.swift" "$OUT/src/"
{ sed 's/^import UIKit$/import AppKit/' "$R/Poker /Models/Card.swift"; echo 'typealias UIColor = NSColor'; } > "$OUT/src/Card.swift"
cp "$H/main.swift" "$OUT/src/main.swift"
xcrun swiftc -O -wmo "$OUT"/src/*.swift -o "$OUT/sim"
echo "built $OUT/sim"

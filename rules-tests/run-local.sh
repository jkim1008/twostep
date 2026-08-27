#!/bin/sh
# Local rules-test runner. (CI uses `firebase emulators:exec` from the npm CLI;
# the standalone/packaged firebase binary corrupts child Node module resolution,
# so locally we background the emulator and run vitest from a clean shell.)
set -e
cd "$(dirname "$0")/.."
export JAVA_HOME="$(brew --prefix openjdk)"
export PATH="$JAVA_HOME/bin:$PATH"
firebase emulators:start --only firestore --project demo-twostep-rules >/tmp/twostep-emulator.log 2>&1 &
EMU_PID=$!
trap 'kill $EMU_PID 2>/dev/null' EXIT
for i in $(seq 1 180); do nc -z -G 1 127.0.0.1 8080 2>/dev/null && break; done
cd rules-tests && node node_modules/vitest/vitest.mjs run

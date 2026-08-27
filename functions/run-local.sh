#!/bin/sh
# Local functions-test runner. Uses the npm-distributed firebase-tools via
# npx (the standalone/packaged firebase binary corrupts child Node module
# resolution under emulators:exec, so never use it here).
set -e
cd "$(dirname "$0")/.."
export JAVA_HOME="$(brew --prefix openjdk)"
export PATH="$JAVA_HOME/bin:$PATH"
(cd functions && npm run build)
npx -y firebase-tools@15 emulators:exec \
  --only auth,functions,firestore \
  --project demo-twostep \
  "cd functions && node node_modules/vitest/vitest.mjs run"

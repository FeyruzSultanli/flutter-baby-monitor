#!/usr/bin/env bash
# Starts the local Firebase Emulator Suite (Auth 9099, Firestore 8080 with
# our firestore.rules, Functions 5001, UI 4000). Local only: nothing is
# deployed and no login is needed. Uses the firebase-tools installed in
# firestore-tests/node_modules.
#
# The project id must match the app's Firebase options so the app (debug,
# --dart-define=USE_FIREBASE_EMULATOR=true) and the Functions trigger use the
# same emulator namespace. Data lives only in the emulator.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
export PATH="$JAVA_HOME/bin:$PATH"
FIREBASE="$ROOT/firestore-tests/node_modules/.bin/firebase"

[ -x "$FIREBASE" ] || (cd "$ROOT/firestore-tests" && npm install --no-audit --no-fund)
[ -d "$ROOT/functions/node_modules" ] || (cd "$ROOT/functions" && npm install --no-audit --no-fund)
(cd "$ROOT/functions" && npm run build)

cd "$ROOT"
# firebase.emulators.json holds the emulator settings, so firebase.json
# (used for real deploys) stays unchanged.
exec "$FIREBASE" --config firebase.emulators.json emulators:start \
  --only auth,firestore,functions --project bebekmonitor-282fd "$@"

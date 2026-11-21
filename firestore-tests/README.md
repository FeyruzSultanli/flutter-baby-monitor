# Firestore rules tests

Tests `../firestore.rules` against the local Firestore emulator. They use the
`demo-baby-monitor` project id, so they never touch the real Firebase project.

The emulator needs Java 11+. Android Studio's JDK works (session only):

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
```

```bash
cd firestore-tests && npm install && npm test
```

The first run downloads the Firestore emulator into `~/.cache/firebase`.

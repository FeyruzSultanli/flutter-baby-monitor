# Cloud Functions (D2)

`onCryAlertCreated`: when the baby writes `rooms/{code}/alerts/{id}`, sends a
high-priority FCM notification to the paired parent (`viewerFcmToken`), at
most once per minute per room, in the parent's language (`viewerLocale`).

Requires the **Blaze** plan. Before deploying, set `REGION` in
`src/index.ts` to match the Firestore location (console → Firestore).

```bash
cd functions && npm install && npm test
```

```bash
cd functions && npx firebase-tools login
```

```bash
cd functions && npm run deploy
```

Remove it again with:

```bash
npx firebase-tools functions:delete onCryAlertCreated --project bebekmonitor-282fd
```

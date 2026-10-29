# Security

## Model

Memory Stack has no server code of its own. The app talks directly to Firebase (Authentication and Cloud Firestore) and, for **Run**, to a Judge0 code runner. So:

- **Firestore security rules are the backend.** Anything the app can do, an attacker with the public API key can try, so every rule assumes a hostile client.
- **Firebase API keys are not secrets.** They identify the project and ship inside every APK and web page. They are restricted to this app in Google Cloud (package + signing certificate, iOS bundle ID, website domains).
- **Real secrets never enter the repo:** the release keystore and its passwords (`android/key.properties`, `*.jks` are git-ignored and kept in `C:\Users\quant\MemoryStack-keys\`), and any Judge0 key (passed at build time with `--dart-define`).

## What is enforced

| Threat | Protection | Where |
|---|---|---|
| Reading or changing another user's data | Rules allow only `request.auth.uid == uid`; listing users is denied | `firestore.rules` |
| Junk or oversized data, unknown fields, privilege flags | Allowed fields and types only, map and note size limits, every other path denied | `firestore.rules` |
| Writing to the old (v1) layout | Read and delete only | `firestore.rules` |
| Rules regressions | Emulator tests for each case, run in CI | `firestore-tests/` |
| Malicious problem links (`javascript:`, `intent:`, `file:`) | Only `http`/`https` links are opened or accepted | `lib/screens/open_link.dart` |
| Oversized input | Field length limits; notes ≤ 20,000 characters (same limit as the rules); code and stdin ≤ 64 KB before sending to the runner | `lib/logic/models.dart`, `lib/data/runner.dart` |
| Account takeover after a stolen session | Deleting an account requires a recent sign-in | `lib/screens/home_page.dart` |
| Data extracted via Android backup / adb | `allowBackup="false"`, no cleartext HTTP | `AndroidManifest.xml` |
| Reverse engineering | Release builds are AOT-compiled and R8-shrunk; Dart symbols can be obfuscated (below) | build |
| Clickjacking, MIME sniffing, referrer leaks on the website | `X-Frame-Options`, CSP `frame-ancestors`, `nosniff`, `Referrer-Policy`, `Permissions-Policy` | `firebase.json` |
| Vulnerable dependencies | Dependabot weekly updates; CI on every push | `.github/` |

## Release build with obfuscation

```
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```
Keep `build/symbols` (it is not in git): it is needed to read crash stack traces from that build.

## Switches only the project owner can turn on

These live in consoles, not in code:

1. **Firebase → Authentication → Settings → User actions → Email enumeration protection: on.** Stops attackers from checking which emails have accounts.
2. **Firebase → Authentication → Settings → Password policy:** require at least 8 characters (the app already asks for 8).
3. **Firebase → App Check**: register Play Integrity (Android, after the Play Store listing exists) and reCAPTCHA Enterprise (web), watch the metrics for a week, then **Enforce** for Firestore and Authentication. Enforcing before then blocks sideloaded test APKs.
4. **Google Cloud → Billing → Budgets & alerts:** a small budget with email alerts, so abuse can never turn into an unexpected bill.
5. **Two-step verification** on the Google account that owns Firebase and on the GitHub account.

## Reporting a problem

Please do not open a public issue for a vulnerability. Email the developer address shown on the Google Play listing.

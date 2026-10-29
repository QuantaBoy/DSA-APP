# Launch checklist: Google Play

## 1. Before you upload

- [ ] **Sheet permission.** The A2Z problem list belongs to takeUforward (Striver). Get written permission to use it in a published app, or replace `assets/sheets/a2z.json` with a list you are allowed to use.
- [ ] **Back up the signing key.** Copy `C:\Users\quant\MemoryStack-keys\` (the `upload-keystore.jks` and `key.properties` with its password) to a USB drive or private cloud. If you lose it, you can't publish updates without asking Google to reset the key.
- [x] **Privacy policy URL:** https://memory-stack-e6990.web.app/privacy.html (Firebase Hosting; redeploy with `flutter build web && firebase deploy --only hosting`).
- [ ] **Your own code runner.** The Run button uses the free public Judge0 (`https://ce.judge0.com`), which is rate-limited and not meant for production apps. Before launch, run your own Judge0 server (its Docker image on a small cloud machine, about USD 5–10 a month) or buy a Judge0 plan on RapidAPI, then build with `--dart-define=JUDGE0_URL=...` (and `JUDGE0_KEY=...` for RapidAPI). See `lib/data/runner.dart`.
- [ ] **Bump the version** in `pubspec.yaml` for every upload (for example `1.0.1+2`; the number after `+` must always go up).

## 2. Build

```
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```
Upload `build/app/outputs/bundle/release/app-release.aab`. The build is signed with your upload key automatically, using `android/key.properties`.

## 3. Play Console (https://play.google.com/console)

1. Create a developer account. There is a one-time USD 25 fee and an ID check.
2. **Create app:** name *Memory Stack*, type App, Free.
3. **App content**, fill in each section:
   - Privacy policy: https://memory-stack-e6990.web.app/privacy.html
   - App access: "All functionality available without special access", or give test login details.
   - Ads: No ads.
   - Content rating: fill in the questionnaire (Education, no violence and so on).
   - Target audience: 18+ (or 13+).
   - Data safety: you collect **email address and name** (account management) and **app activity / other user-generated content** (app functionality). Code you Run is shared with the code-execution service (Judge0) only to run it. Data is encrypted in transit, users can request deletion, and it is not shared.
   - Account deletion: in-app (profile menu → Delete account), plus the policy URL.
4. **Store listing:** use the text below and the screenshots.
5. **Testing → Closed testing:** upload the `.aab` and add at least **12 testers** (their Gmail addresses). They must stay opted in for **14 days**. New personal accounts need this before production.
6. After 14 days: **Production → Create release**, upload the same or a newer `.aab`, then send it for review.
7. **Play App Signing:** after the first upload, go to *Setup → App signing*, copy the **app signing key SHA-1**, and add it in the Firebase console (Project settings → Android app → Add fingerprint). Without this, Google login fails in the Play Store version.

## 4. Store listing text

**App name:** Memory Stack: DSA Revision

**Short description (80 characters max):**
Never forget a DSA problem. Spaced repetition for coding interview prep.

**Full description:**
Solved a problem last month but can't remember the trick now? Memory Stack fixes that.

Follow a structured DSA sheet step by step. When you solve a problem, tick it. Memory Stack brings it back for revision at the right moment: after 1 day, 3 days, a week, two weeks, a month, and so on. Each review takes a minute. You recall the approach, check yourself, and tap Remembered or Forgot. Forgotten problems come back sooner; remembered ones move further out.

Features:
• Step-by-step DSA sheet with progress for every step
• Smart revision schedule (spaced repetition)
• Today screen: what is due, your streak, what is coming up
• Notes for each problem: key idea, edge cases, complexity
• Stats: recall rate, weakest topics, last 7 days
• Daily reminder
• Works offline and syncs across devices
• Sign in with Google or email
• Light and dark mode

Built for students preparing for placements and coding interviews.

**Category:** Education · **Tags:** education, productivity

**Graphics needed:** a 512×512 icon (`assets/icon/icon.png`, resized), a 1024×500 feature graphic, and at least 2 phone screenshots (Today, Sheet, Review, Stats).

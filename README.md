# Memory Stack

Spaced repetition app for DSA problems (Flutter, Android + web).

- **Today**: problems due for revision, streak, what's coming up this week
- **Review**: recall, check, then tap Remembered or Forgot. Reviews come back after 1, 3, 7, 14, 30 � 365 days.
- **A2Z Sheet**: Striver's sheet step by step; ticking a problem adds it to your stack
- **My stack**: every problem, with notes; add problems from LeetCode, Codeforces and other sites
- **Stats**: recall rate, weakest topics, last 7 days
- Daily reminder at 10 AM, works offline, Google and email login, account deletion

Code layout: `lib/logic` (pure rules, no Firebase), `lib/data` (Firestore, sheet, reminder), `lib/screens` (UI).

## Run

```
flutter pub get
flutter run -d chrome      # or: flutter run   (Android phone/emulator)
flutter test
```

## One-time Firebase setup (login)

1. Go to https://console.firebase.google.com → **Add project** → name it `memory-stack` (Google Analytics: off is fine).
2. In the project: **Build → Authentication → Get started**, then on the **Sign-in method** tab enable:
   - **Email/Password**
   - **Google** (pick your support email, Save)
3. On your PC, in this folder:
   ```
   firebase login
   dart pub global run flutterfire_cli:flutterfire configure
   ```
   Pick the `memory-stack` project and the **android** and **web** platforms.
   This replaces `lib/firebase_options.dart` with your real settings. These values are public identifiers, safe to commit.
4. **Google sign-in on Android** also needs your app's SHA-1 fingerprint (after Android Studio is installed):
   ```
   cd android
   gradlew signingReport
   ```
   Copy the `SHA1` of the `debug` variant → Firebase console → **Project settings → Your apps → Android app → Add fingerprint**.
   Add the release key's SHA-1 too before publishing.

## Release build

The release signing key is kept outside the repo, in `C:\Users\quant\MemoryStack-keys\`. `android/key.properties` points to it and is git-ignored.
```
flutter build apk --release        # to install directly on a phone
flutter build appbundle --release  # to upload to Google Play
```
See [LAUNCH.md](LAUNCH.md) for the Play Store steps and [PRIVACY.md](PRIVACY.md) for the privacy policy.

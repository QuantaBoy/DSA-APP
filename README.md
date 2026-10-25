# Memory Stack

Spaced repetition app for DSA problems (Flutter, Android + web).

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

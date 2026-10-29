# iPhone (iOS)

The app's code already supports iOS: the `ios/` folder is set up, and the Firebase iOS app is registered (bundle id `com.memorystack.memoryStack`). What's missing is the build: Apple only allows iPhone apps to be built on a Mac.

## Today, free: install the web app on an iPhone

1. On the iPhone, open **Safari** and go to https://memory-stack-e6990.web.app
2. Tap **Share** → **Add to Home Screen** → **Add**.

It opens full-screen from its own icon, like an app. Sign-in, the sheet, the code runner, reviews and streaks all work. The only thing missing is the daily notification (web apps can't schedule one).

## Real iOS app (App Store / TestFlight)

You need:
- An **Apple Developer account**: USD 99 a year (https://developer.apple.com/programs/).
- A Mac with Xcode, **or** a cloud Mac. **Codemagic** has a free plan with Mac build minutes: https://codemagic.io

### With Codemagic (no Mac needed)
1. Sign in to Codemagic with GitHub and add the `DSA-APP` repository.
2. Choose **Flutter App** → **iOS**.
3. Under **Code signing**, connect your Apple Developer account (App Store Connect API key) and let it create the certificate and profile automatically.
4. Build mode **Release**, then **Start new build**. The result is an `.ipa` file.
5. Turn on **Publish to App Store Connect** to send it to **TestFlight**, then invite testers by email. They install it with the TestFlight app.

### With a Mac
```
flutter build ipa --release
```
Then open `build/ios/archive/Runner.xcarchive` in Xcode → **Distribute App** → App Store Connect.

### Before the App Store
- In App Store Connect, create the app with bundle id `com.memorystack.memoryStack`.
- Privacy policy: https://memory-stack-e6990.web.app/privacy.html
- Apple requires **Sign in with Apple** when an app offers Google sign-in. Add it before the first App Store review: enable *Apple* in Firebase Authentication, then add an Apple button next to Google.
- The daily reminder is Android-only for now; on iOS it needs notification permission code and an APNs setup.

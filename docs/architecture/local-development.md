# Local Development

## Rails

```sh
cd rails
mise exec ruby@4.0.1 -- bundle install
mise exec ruby@4.0.1 -- bin/rails db:setup
mise exec ruby@4.0.1 -- bin/rails server
```

Create an Android API token from the Rails UI after signing in. Seed credentials are:

- email: `driver@example.com`
- password: `password123`

## Cloudflare Tunnel

Install `cloudflared`, then run:

```sh
scripts/tunnel
```

Paste the emitted HTTPS URL into the Android app's API base URL field. Keep the trailing slash.

## Android

The Android SDK is present at `~/Library/Android/sdk`, but `adb`, `sdkmanager`, and `gradle` were not on `PATH` during scaffolding. Open `android/` in Android Studio or install/add command-line tools before running:

```sh
cd android
./gradlew testDebugUnitTest
./gradlew connectedDebugAndroidTest
```

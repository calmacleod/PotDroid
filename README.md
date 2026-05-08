# PotDroid

PotDroid contains a native Android app and a Rails 8 backend for detecting, reviewing, and submitting candidate potholes.

## Structure

- `android/`: Kotlin Android app using CameraX, Room, WorkManager, Retrofit, Compose, and a pluggable pothole detector.
- `rails/`: Rails 8 app using Hotwire, SQLite, Active Storage, Solid Queue/Cache/Cable, and Kamal.
- `docs/architecture/`: architecture decisions and integration notes.
- `scripts/`: local developer workflow helpers.

## Quick Start

```sh
scripts/setup
scripts/dev
```

In another terminal, expose Rails to a physical Android device:

```sh
scripts/tunnel
```

Paste the Cloudflare tunnel URL and a Rails-generated Android API token into the Android app's debug settings.

## Test

```sh
scripts/test
```

Rails tests are runnable now. Android tests require Gradle/Android command-line access or Android Studio sync.

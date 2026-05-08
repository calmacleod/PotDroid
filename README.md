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

To rebuild the Rails development database with deterministic seed data:

```sh
scripts/reset-dev-db
```

Seed login:

- email: `driver@example.com`
- password: `password123`

`scripts/dev` starts Rails and, when `cloudflared` is on `PATH`, starts a Cloudflare quick tunnel first. The generated HTTPS URL is exported into the Rails process as `POTDROID_API_BASE_URL`, so Android pairing QR codes point at the tunnel URL automatically.

To run Rails without the tunnel:

```sh
POTDROID_DEV_TUNNEL=false scripts/dev
```

`scripts/tunnel` remains available when you only want the raw Cloudflare tunnel process.

If you install `devenv`, run `devenv shell` from the repo root to get `cloudflared`, Android platform tools, JDK 17, and the Android Gradle environment in one shell. For automatic activation, use `devenv hook` or run `direnv allow` once; `GRADLE_USER_HOME` will be set automatically when you enter the repo.

The Rails API documentation is served by the Rails app at:

```sh
http://localhost:3000/api-docs
```

## Test

```sh
scripts/test
```

Rails tests are runnable now. Android tests require Gradle/Android command-line access or Android Studio sync.

Android Gradle commands can also run through the repo wrapper:

```sh
scripts/gradle testDebugUnitTest
```

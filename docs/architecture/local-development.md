# Local Development

## Rails

```sh
cd rails
mise exec ruby@4.0.1 -- bundle install
mise exec ruby@4.0.1 -- bin/rails db:setup
mise exec ruby@4.0.1 -- bin/rails server
```

Reset development data from the monorepo root:

```sh
scripts/reset-dev-db
```

Development seeds use Rails-native `db/seeds.rb` with deterministic `faker` values and stable upserts. Seed credentials are also shown in a development-only banner in the Rails UI:

- email: `driver@example.com`
- password: `password123`

## devenv

`devenv.sh` is a good fit for this monorepo because it can provide the missing command-line tools without replacing Android Studio. From the repo root:

```sh
devenv shell
```

The checked-in `devenv.nix` provides `cloudflared`, Android platform tools, JDK 17, `mise`, SQLite, and shared environment variables. It uses the Android Studio SDK at `~/Library/Android/sdk` by default and stores Gradle caches under `android/.gradle`.

For automatic shell activation, use `devenv hook` with your shell. If you prefer `direnv`, install it and run:

```sh
direnv allow
```

If `devenv` is not installed, `.envrc` falls back to the same Android environment variables when loaded by `direnv`.

## Cloudflare Tunnel

Install `cloudflared`, then start the parent dev script:

```sh
scripts/dev
```

By default, the parent script starts `cloudflared tunnel --url http://localhost:3000`, waits for the emitted `https://*.trycloudflare.com` URL, exports it as `POTDROID_API_BASE_URL`, and then starts the Rails `bin/dev` process. Rails pairing QR codes use that tunnel URL automatically.

For a stable long-lived hostname, authenticate `cloudflared` and run the setup helper once:

```sh
scripts/setup-tunnel potdroid-dev.example.com
```

The hostname must belong to the Cloudflare zone selected during `cloudflared login`. If `cloudflared` is authenticated to `example.com`, use a hostname such as `potdroid-dev.example.com`.

The optional second argument sets the Cloudflare tunnel name:

```sh
scripts/setup-tunnel potdroid-dev.example.com potdroid-dev
```

The setup helper creates or reuses the named tunnel, routes the hostname to that tunnel, and writes gitignored local config to `.local/cloudflare-tunnel.env`. After that, `scripts/dev` and `scripts/tunnel` use the named tunnel and export `POTDROID_API_BASE_URL=https://potdroid-dev.example.com` instead of generating a new `trycloudflare.com` URL on every run.

If a DNS record already exists and should be replaced, run:

```sh
POTDROID_TUNNEL_OVERWRITE_DNS=true scripts/setup-tunnel potdroid-dev.example.com
```

To run without Cloudflare:

```sh
POTDROID_DEV_TUNNEL=false scripts/dev
```

`scripts/tunnel` remains available for running the tunnel by itself.

## Android

The Android SDK is present at `~/Library/Android/sdk`, but `adb`, `sdkmanager`, and `gradle` were not on `PATH` during scaffolding. Open `android/` in Android Studio or install/add command-line tools before running:

```sh
cd android
./gradlew testDebugUnitTest
./gradlew connectedDebugAndroidTest
```

From the repo root, use this wrapper when your shell has not loaded `.envrc`:

```sh
scripts/gradle testDebugUnitTest
```

## API Documentation

The Rails app mounts self-hosted Scalar documentation at:

```sh
http://localhost:3000/api-docs
```

The OpenAPI document is served from `rails/public/openapi.yml`, and the Scalar browser bundle is served from `rails/public/scalar-api-reference.js`.

# AGENTS.md

## Project Shape

PotDroid is a monorepo with two sibling applications:

- `android/`: native Kotlin Android app for mounted-phone road scanning.
- `rails/`: Rails 8 app for API ingestion, review UI, city submission jobs, and deployment.
- `docs/architecture/`: architecture decisions and operational notes.
- `scripts/`: parent-level developer workflow commands.

## Working Rules

- Keep Android and Rails API contracts in sync. If an upload field changes in one app, update the other app and the API contract doc in the same change.
- Prefer small, tested changes. Add or update focused tests for every feature path.
- Do not commit real API tokens, tunnel URLs, city credentials, or Rails master keys.
- Use the parent scripts first; they encode the expected local workflow.
- Rails commands should be run from `rails/` through `mise exec ruby@4.0.1 -- ...` on this machine unless the local shell already resolves Ruby 4.0.1.
- Android commands assume Android Studio or a Gradle install/wrapper is available. The SDK exists at `~/Library/Android/sdk`, but command-line tools may need to be added to `PATH`.

## Rails Conventions

- Keep controllers thin and move external submission behavior into `app/services/city_submissions`.
- API routes are versioned under `/api/v1`.
- Mobile API auth uses bearer tokens backed by `ApiToken`; never store raw tokens.
- Use Active Storage for candidate images.
- Use Solid Queue jobs for upload processing, city submission, and status polling.
- Run `mise exec ruby@4.0.1 -- bundle exec rspec` before handing off Rails changes.

## Android Conventions

- Keep camera, detector, persistence, and upload concerns separated.
- `PotholeDetector` is the boundary for model work. Keep fake/test detectors available.
- All candidate captures must include image path, location, confidence, model version, bounding box, and timestamp.
- Uploads must go through the Room-backed queue and WorkManager, not direct fire-and-forget calls from UI code.
- Run `./gradlew testDebugUnitTest` and relevant `connectedDebugAndroidTest` checks when Gradle is available.

## City Connectors

- Keep city-specific behavior behind `CitySubmissions::Connector`.
- The Ottawa connector is Open311-first. If API key/write access is missing, use the manual-required fallback path rather than automating browser form submissions inside domain code.

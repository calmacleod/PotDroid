# ADR 0003: Rails API And Review Workflow

## Decision

Use Rails 8 with built-in authentication for the web UI and bearer-token `ApiToken` records for the Android API.

## API

- `POST /api/v1/candidate_potholes`: multipart image upload plus metadata.
- `GET /api/v1/candidate_potholes/:id`: current user's upload and review/submission state.

## Review

Users sign in, view their uploaded candidates, and confirm or reject detections. Confirmed candidates can be queued for city submission through Solid Queue.

## Storage

Candidate photos use Active Storage. Candidate metadata includes detector output and the optional accelerometer data window uploaded by Android. SQLite is the default database for application, queue, cache, and cable data.

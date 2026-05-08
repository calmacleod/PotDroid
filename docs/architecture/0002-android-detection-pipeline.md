# ADR 0002: Android Detection Pipeline

## Decision

Build the Android vision path around a `PotholeDetector` interface with a fake detector for tests/dev and a `TflitePotholeDetector` production slot.

## Why

The app can validate camera, location, compression, offline queueing, and upload behavior before committing to a specific pothole model artifact. This keeps the expensive model-selection work isolated from the rest of the capture pipeline.

## Data Captured

Each candidate stores:

- compressed image path
- latitude and longitude
- heading and speed when available
- detector confidence
- model version
- bounding box
- capture timestamp
- upload status and remote API id

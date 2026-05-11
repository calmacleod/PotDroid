# ADR 0002: Android Detection Pipeline

## Decision

Build the Android vision path around a `PotholeDetector` interface with a fake detector for tests/dev and a `TflitePotholeDetector` production implementation.

## Why

The app can validate camera, location, compression, offline queueing, and upload behavior while keeping model selection isolated from the rest of the capture pipeline.

The first bundled detector is `pot_yolo_int8.tflite`, an int8 TensorFlow Lite YOLO detector trained for `pothole` on RDD2022-derived road-damage data. Android stores `pot-yolo-int8-780aff5` as the detector model version on every queued candidate.

The model card declares Apache-2.0, but the embedded Ultralytics metadata names an AGPL-3.0 license. Treat this as acceptable for prototype validation only until the redistribution license is reviewed.

## Data Captured

Each candidate stores:

- compressed image path
- latitude and longitude
- heading and speed when available
- detector confidence
- model version
- bounding box
- accelerometer data window captured around the detector event
- capture timestamp
- upload status and remote API id

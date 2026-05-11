# API Contract

The same contract is available as a self-hosted Scalar UI when Rails is running:

```text
http://localhost:3000/api-docs
```

## Authentication

Android sends a bearer token:

```http
Authorization: Bearer pd_...
```

Tokens are long-lived. The preferred way to obtain one is the pairing flow below.

## Pair Android App

From the Rails UI, click **Pair Android app**. Rails creates a one-time code that expires after 15 minutes and renders a QR deep link:

```text
potdroid://pair?u=https%3A%2F%2Fexample.trycloudflare.com&c=ABCD-EFGH-JK23
```

Android can open the compact deep link directly, paste the deep link, paste the legacy JSON payload, paste the legacy `api_base_url`/`code` deep link, or submit just the code.

`POST /api/v1/pairing`

```json
{
  "pairing": {
    "code": "ABCD-EFGH-JK23",
    "device_name": "Google Pixel"
  }
}
```

Successful responses return `201 Created` with a long-lived bearer token:

```json
{
  "data": {
    "type": "pairing",
    "attributes": {
      "api_token": "pd_...",
      "token_type": "Bearer",
      "long_lived": true,
      "user_email": "driver@example.com"
    }
  }
}
```

## Create Candidate

`POST /api/v1/candidate_potholes`

Multipart field names:

- `candidate_pothole[image]`
- `candidate_pothole[latitude]`
- `candidate_pothole[longitude]`
- `candidate_pothole[heading]`
- `candidate_pothole[speed]`
- `candidate_pothole[detector_confidence]`
- `candidate_pothole[detector_model_version]`
- `candidate_pothole[captured_at]`
- `candidate_pothole[accelerometer_data]` optional JSON string
- `candidate_pothole[bounding_box][left]`
- `candidate_pothole[bounding_box][top]`
- `candidate_pothole[bounding_box][right]`
- `candidate_pothole[bounding_box][bottom]`

`accelerometer_data` contains a rolling sensor window captured around the detector event:

```json
{
  "sensor_type": "linear_acceleration",
  "sensor_name": "Pixel linear acceleration",
  "includes_gravity": false,
  "sample_rate_hz": 48.5,
  "window_start_elapsed_millis": 1000,
  "window_end_elapsed_millis": 1900,
  "peak_magnitude": 7.2,
  "bump_threshold": 5.0,
  "bump_detected": true,
  "samples": [
    { "elapsed_millis": 1000, "x": 0.1, "y": 0.2, "z": 1.1, "magnitude": 1.12 }
  ]
}
```

Successful responses return `201 Created` with the candidate id, status, metadata, accelerometer data, image URL, image validation state, and city submission state when present. Rails enqueues an async image reliability validation job after the upload is stored. The job runs the local detector against the original image plus transformed versions of the image. Candidates remain reviewable only when every validation check detects the pothole at or above the server threshold; failed reliability checks automatically move the candidate to `rejected`.

## Validate Image Against Local Detector

`POST /api/v1/detector_validation`

This endpoint is intended for development and review workflows on a machine that can run the local TFLite detector. It does not create a candidate pothole; it only reports whether the bundled detector would catch the uploaded image.

Multipart field names:

- `image`
- `threshold` optional, defaults to `0.25`

Successful responses return `200 OK`:

```json
{
  "detected": true,
  "confidence": 0.82,
  "threshold": 0.25,
  "model_version": "pot-yolo-int8-780aff5",
  "bounding_box": {
    "left": 0.1,
    "top": 0.2,
    "right": 0.4,
    "bottom": 0.5
  },
  "detections": []
}
```

Rails executes `rails/lib/pothole_detector/tflite_runner.py` with the Android model asset. Run `scripts/setup-detector` to install the optional Python dependencies into `rails/tmp/detector-venv`, or set `POTDROID_DETECTOR_PYTHON` when Rails should use a specific Python or virtualenv.

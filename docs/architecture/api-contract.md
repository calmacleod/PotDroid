# API Contract

## Authentication

Android sends a bearer token:

```http
Authorization: Bearer pd_...
```

Tokens are long-lived. The preferred way to obtain one is the pairing flow below.

## Pair Android App

From the Rails UI, click **Pair Android app**. Rails creates a one-time code that expires after 15 minutes and renders a QR deep link:

```text
potdroid://pair?api_base_url=https%3A%2F%2Fexample.trycloudflare.com&code=ABCD-EFGH-JK23
```

Android can open the deep link directly, paste the deep link, paste the legacy JSON payload, or submit just the code.

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
- `candidate_pothole[bounding_box][left]`
- `candidate_pothole[bounding_box][top]`
- `candidate_pothole[bounding_box][right]`
- `candidate_pothole[bounding_box][bottom]`

Successful responses return `201 Created` with the candidate id, status, metadata, image URL, and city submission state when present.

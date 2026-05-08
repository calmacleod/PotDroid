# API Contract

## Authentication

Android sends a bearer token:

```http
Authorization: Bearer pd_...
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

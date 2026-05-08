# ADR 0004: City Submission Connectors

## Decision

Use a generic city connector interface with an Ottawa Open311 connector as the first implementation.

## Why

The City of Ottawa has a public 311 pothole form and is listed in the Open311 GeoReport v2 server registry. Open311 is the best first abstraction because it models service requests and status checks without coupling the app to one municipality's browser UI.

## Ottawa Behavior

`CitySubmissions::Ottawa::Open311Connector` submits confirmed candidates when `OTTAWA_OPEN311_API_KEY` is configured. Without API credentials, it produces a `manual_required` submission packet with the location, description, and photo-size guidance.

## Extension

Future cities should implement the same `submit(candidate)` and `status(city_submission)` methods and be registered in `CitySubmissions::Registry`.

# Flight Inquiry

A polished macOS SwiftUI MVP for comparing flight options. It uses Swift Package Manager and runs in mock mode by default, so no credentials or network service are required for the demo.

## Requirements

- macOS 13 or later
- Xcode 15 or later (Swift 5.9)

## Run

Open the folder in Xcode, select the `FlightInquiryApp` scheme, and run. From a macOS terminal:

```sh
swift test
swift run FlightInquiryApp
```

The app starts with route-aware demo data enabled. Different airport pairs generate different
flight IDs, departure times, and fares so it is clear that the search request is being used.
These are clearly labeled demo values, not live inventory.

## Build a `.app`

On macOS, run the included release bundle script:

```sh
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open FlightInquiry.app
```

The script creates `FlightInquiry.app` in the project root. This repository is currently being worked on from Windows, which cannot compile SwiftUI/macOS binaries; the script must be run on macOS with Xcode's Swift toolchain.

### Build from Windows with GitHub Actions

Windows cannot legally or reliably provide Apple's macOS SDK locally. The included
GitHub Actions workflow builds on a hosted macOS runner instead:

1. Push this project to a GitHub repository.
2. Open **Actions → Build macOS app → Run workflow**.
3. Download the `FlightInquiry-macOS` artifact from the completed workflow run.
4. Unzip it on a Mac and open `FlightInquiry.app`.

The workflow also runs `swift test` before packaging the app. It does not require
Apple credentials because the app is unsigned; macOS may require you to approve
the app in Privacy & Security on first launch.

## Ctrip API integration

`CtripAPIClient` is an intentionally small URLSession abstraction. It validates the request, builds a GET request with `origin`, `destination`, `date`, and `passengers`, and decodes a response shaped as:

```json
{ "flights": [{ "id": "…", "airline": "…", "flightNumber": "…",
  "departureTime": "2026-01-01T08:00:00Z", "arrivalTime": "2026-01-01T11:00:00Z",
  "durationMinutes": 180, "stops": 0, "price": 250, "currency": "USD" }] }
```

Configure the client through environment variables:

```sh
CTRIP_API_ENDPOINT=https://your-service.example/flights \
CTRIP_API_KEY=replace-with-a-real-key \
FLIGHT_INQUIRY_MOCK=false \
swift run FlightInquiryApp
```

**Caveat:** Ctrip API access, authentication requirements, endpoint, request parameters, and response schema must be supplied by an authorized Ctrip integration/provider. This project does not invent credentials or claim that the placeholder schema matches a production Ctrip API. Adapt the request and decoder to the official documentation you have access to before disabling mock mode.

There is no reliable, unrestricted public API that provides live bookable schedules and fares
from Booking.com or Trip.com without credentials or a partner agreement. Public flight APIs
that can be called anonymously generally expose aircraft positions, not route search or ticket
prices, so this app does not present them as a substitute for booking inventory. A real
provider should be added as another `FlightProviding` implementation once an authorized API
contract is available.

## Tests

`FlightInquiryCoreTests` covers mock response details, invalid request handling, and stop-label formatting. The core target is kept separate from the SwiftUI app to make these tests focused and portable.

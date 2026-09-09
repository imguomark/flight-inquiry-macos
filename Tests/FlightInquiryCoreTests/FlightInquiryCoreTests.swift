import XCTest
@testable import FlightInquiryCore

final class FlightInquiryCoreTests: XCTestCase {
    func testMockProviderReturnsExpectedFlightDetails() async throws {
        let request = FlightSearchRequest(origin: "SFO", destination: "PVG", date: Date(timeIntervalSince1970: 1_700_000_000))
        let flights = try await CtripAPIClient(configuration: CtripAPIConfiguration(useMockData: true)).search(request)

        XCTAssertEqual(flights.count, 3)
        XCTAssertEqual(flights.first?.airline, "Skyward Airlines")
        XCTAssertEqual(flights.first?.stopsLabel, "Nonstop")
        XCTAssertEqual(flights.first?.currency, "USD")
    }

    func testInvalidRequestIsRejected() async {
        let request = FlightSearchRequest(origin: "", destination: "PVG", date: .now)

        do {
            _ = try await CtripAPIClient(configuration: CtripAPIConfiguration(useMockData: true)).search(request)
            XCTFail("Expected invalid request")
        } catch let error as FlightSearchError {
            XCTAssertEqual(error, .invalidRequest("Enter both an origin and destination."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStopsLabelPluralizes() {
        let flight = Flight(id: "test", airline: "Test", flightNumber: "T1", departureTime: .now,
                            arrivalTime: .now, durationMinutes: 60, stops: 2, price: 1, currency: "USD")
        XCTAssertEqual(flight.stopsLabel, "2 stops")
    }
}

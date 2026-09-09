import XCTest
@testable import FlightInquiryCore

final class FlightInquiryCoreTests: XCTestCase {
    func testMockProviderReturnsExpectedFlightDetails() async throws {
        let request = FlightSearchRequest(origin: "SFO", destination: "PVG", date: Date(timeIntervalSince1970: 1_700_000_000))
        let flights = try await CtripAPIClient(configuration: CtripAPIConfiguration(useMockData: true)).search(request)

        XCTAssertGreaterThanOrEqual(flights.count, 3)
        XCTAssertFalse(flights.first?.airline.isEmpty ?? true)
        XCTAssertEqual(flights.first?.stopsLabel, "Nonstop")
        XCTAssertEqual(flights.first?.currency, "USD")
    }

    func testMockProviderVariesByRoute() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let provider = CtripAPIClient(configuration: CtripAPIConfiguration(useMockData: true))
        let sfoToPVG = try await provider.search(FlightSearchRequest(origin: "SFO", destination: "PVG", date: date))
        let laxToNRT = try await provider.search(FlightSearchRequest(origin: "LAX", destination: "NRT", date: date))

        XCTAssertNotEqual(sfoToPVG.map(\.id), laxToNRT.map(\.id))
        XCTAssertNotEqual(sfoToPVG.map(\.price), laxToNRT.map(\.price))
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

    func testFiltersAndSortsFlights() {
        let flights = MockFlightData.flights(for: FlightSearchRequest(origin: "SFO", destination: "PVG", date: .now))
        let filters = FlightFilters(nonstopOnly: true, sort: .price)

        XCTAssertTrue(filters.applying(to: flights).allSatisfy { $0.stops == 0 })
        XCTAssertEqual(filters.applying(to: flights).first?.price, filters.applying(to: flights).map(\.price).min())
    }
}

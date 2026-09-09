import Foundation

public struct FlightSearchRequest: Equatable, Sendable {
    public var origin: String
    public var destination: String
    public var date: Date
    public var passengers: Int

    public init(origin: String, destination: String, date: Date, passengers: Int = 1) {
        self.origin = origin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.destination = destination.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.date = date
        self.passengers = passengers
    }

}

public enum FlightSort: String, CaseIterable, Identifiable, Sendable {
    case recommended
    case price
    case duration
    case departure

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .recommended: "Recommended"
        case .price: "Lowest price"
        case .duration: "Shortest duration"
        case .departure: "Earliest departure"
        }
    }
}

public struct FlightFilters: Equatable, Sendable {
    public var nonstopOnly = false
    public var sort: FlightSort = .recommended

    public init(nonstopOnly: Bool = false, sort: FlightSort = .recommended) {
        self.nonstopOnly = nonstopOnly
        self.sort = sort
    }

    public func applying(to flights: [Flight]) -> [Flight] {
        let filtered = nonstopOnly ? flights.filter { $0.stops == 0 } : flights
        switch sort {
        case .recommended:
            return filtered
        case .price:
            return filtered.sorted { $0.price < $1.price }
        case .duration:
            return filtered.sorted { $0.durationMinutes < $1.durationMinutes }
        case .departure:
            return filtered.sorted { $0.departureTime < $1.departureTime }
        }
    }
}

public struct Flight: Identifiable, Equatable, Sendable {
    public let id: String
    public let airline: String
    public let flightNumber: String
    public let departureTime: Date
    public let arrivalTime: Date
    public let durationMinutes: Int
    public let stops: Int
    public let price: Decimal
    public let currency: String

    public init(
        id: String, airline: String, flightNumber: String, departureTime: Date,
        arrivalTime: Date, durationMinutes: Int, stops: Int, price: Decimal, currency: String
    ) {
        self.id = id
        self.airline = airline
        self.flightNumber = flightNumber
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.durationMinutes = durationMinutes
        self.stops = stops
        self.price = price
        self.currency = currency
    }

    public var stopsLabel: String {
        stops == 0 ? "Nonstop" : "\(stops) stop\(stops == 1 ? "" : "s")"
    }
}

public enum FlightSearchError: LocalizedError, Equatable {
    case invalidRequest(String)
    case invalidResponse
    case server(String)
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let message), .server(let message), .network(let message):
            return message
        case .invalidResponse:
            return "The flight provider returned an unreadable response."
        }
    }
}

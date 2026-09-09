import Foundation

public struct FlightSearchRequest: Equatable, Sendable {
    public var origin: String
    public var destination: String
    public var date: Date
    public var passengers: Int

    public init(origin: String, destination: String, date: Date, passengers: Int = 1) {
        self.origin = origin
        self.destination = destination
        self.date = date
        self.passengers = passengers
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

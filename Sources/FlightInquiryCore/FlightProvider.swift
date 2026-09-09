import Foundation

public protocol FlightProviding: Sendable {
    func search(_ request: FlightSearchRequest) async throws -> [Flight]
}

public struct CtripAPIConfiguration: Sendable {
    public var endpoint: URL
    public var apiKey: String?
    public var useMockData: Bool

    public init(
        endpoint: URL = URL(string: "https://api.example.invalid/ctrip/flights")!,
        apiKey: String? = nil,
        useMockData: Bool = true
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.useMockData = useMockData
    }

    public static var fromEnvironment: CtripAPIConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let endpoint = URL(string: environment["CTRIP_API_ENDPOINT"] ?? "https://api.example.invalid/ctrip/flights")
            ?? URL(string: "https://api.example.invalid/ctrip/flights")!
        return CtripAPIConfiguration(
            endpoint: endpoint,
            apiKey: environment["CTRIP_API_KEY"],
            useMockData: environment["FLIGHT_INQUIRY_MOCK"]?.lowercased() != "false"
        )
    }
}

public struct CtripAPIClient: FlightProviding {
    private let configuration: CtripAPIConfiguration
    private let session: URLSession

    public init(configuration: CtripAPIConfiguration = .fromEnvironment, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func search(_ request: FlightSearchRequest) async throws -> [Flight] {
        guard request.origin.count == 3, request.destination.count == 3,
              request.origin.allSatisfy(\.isLetter), request.destination.allSatisfy(\.isLetter),
              request.origin != request.destination else {
            throw FlightSearchError.invalidRequest("Enter both an origin and destination.")
        }
        guard request.passengers > 0 else {
            throw FlightSearchError.invalidRequest("Passenger count must be at least one.")
        }
        if configuration.useMockData {
            return MockFlightData.flights(for: request)
        }

        var components = URLComponents(url: configuration.endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "origin", value: request.origin.uppercased()),
            URLQueryItem(name: "destination", value: request.destination.uppercased()),
            URLQueryItem(name: "date", value: Self.dateFormatter.string(from: request.date)),
            URLQueryItem(name: "passengers", value: String(request.passengers))
        ]
        guard let url = components?.url else { throw FlightSearchError.invalidRequest("The API endpoint is invalid.") }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        if let apiKey = configuration.apiKey {
            urlRequest.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else { throw FlightSearchError.invalidResponse }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw FlightSearchError.server("The flight provider returned HTTP \(httpResponse.statusCode).")
            }
            return try Self.decoder.decode(FlightResponse.self, from: data).flights
        } catch let error as FlightSearchError {
            throw error
        } catch {
            throw FlightSearchError.network(error.localizedDescription)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private struct FlightResponse: Decodable {
    let flights: [Flight]
}

extension Flight: Codable {
    enum CodingKeys: String, CodingKey {
        case id, airline, flightNumber, departureTime, arrivalTime, durationMinutes, stops, price, currency
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(String.self, forKey: .id),
            airline: try values.decode(String.self, forKey: .airline),
            flightNumber: try values.decode(String.self, forKey: .flightNumber),
            departureTime: try values.decode(Date.self, forKey: .departureTime),
            arrivalTime: try values.decode(Date.self, forKey: .arrivalTime),
            durationMinutes: try values.decode(Int.self, forKey: .durationMinutes),
            stops: try values.decode(Int.self, forKey: .stops),
            price: try values.decode(Decimal.self, forKey: .price),
            currency: try values.decode(String.self, forKey: .currency)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(airline, forKey: .airline)
        try values.encode(flightNumber, forKey: .flightNumber)
        try values.encode(departureTime, forKey: .departureTime)
        try values.encode(arrivalTime, forKey: .arrivalTime)
        try values.encode(durationMinutes, forKey: .durationMinutes)
        try values.encode(stops, forKey: .stops)
        try values.encode(price, forKey: .price)
        try values.encode(currency, forKey: .currency)
    }
}

public enum MockFlightData {
    public static func flights(for request: FlightSearchRequest) -> [Flight] {
        let calendar = Calendar.current
        let seed = request.origin.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            + request.destination.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let start = calendar.date(bySettingHour: 6 + seed % 5, minute: seed % 4 * 15, second: 0, of: request.date) ?? request.date
        let route = "\(request.origin)-\(request.destination)"
        let basePrice = Decimal(220 + seed % 180)
        let catalogs = [
            [("United Airlines", "UA"), ("China Eastern", "MU"), ("ANA", "NH"), ("Air Canada", "AC"), ("Delta", "DL")],
            [("Singapore Airlines", "SQ"), ("Cathay Pacific", "CX"), ("Lufthansa", "LH"), ("Emirates", "EK"), ("Qantas", "QF")],
            [("American Airlines", "AA"), ("British Airways", "BA"), ("Korean Air", "KE"), ("JAL", "JL"), ("Air France", "AF")]
        ]
        let catalog = catalogs[seed % catalogs.count]
        let count = 3 + seed % 3

        return (0..<count).map { index in
            let airline = catalog[(seed + index) % catalog.count]
            let stops = index == 0 || index == 2 ? 0 : 1
            let duration = 190 + index * 35 + seed % 30
            let departure = start.addingTimeInterval(Double(index * 95) * 60)
            return Flight(
                id: "\(route)-\(airline.1)-\(index)",
                airline: airline.0,
                flightNumber: "\(airline.1) \(100 + (seed * 7 + index * 53) % 800)",
                departureTime: departure,
                arrivalTime: departure.addingTimeInterval(Double(duration + stops * 45) * 60),
                durationMinutes: duration + stops * 45,
                stops: stops,
                price: basePrice + Decimal(index * 58 - (index == 1 ? 12 : 0)),
                currency: "USD"
            )
        }
    }
}

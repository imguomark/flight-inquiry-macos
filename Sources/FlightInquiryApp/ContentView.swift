import SwiftUI
import FlightInquiryCore

@MainActor
final class FlightSearchViewModel: ObservableObject {
    @Published var origin = "SFO"
    @Published var destination = "PVG"
    @Published var date = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    @Published var passengers = 1
    @Published private(set) var flights: [Flight] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var filters = FlightFilters()
    private let provider: any FlightProviding

    init(provider: any FlightProviding = CtripAPIClient()) {
        self.provider = provider
    }

    func search() {
        let request = FlightSearchRequest(origin: origin, destination: destination, date: date, passengers: passengers)
        isLoading = true
        errorMessage = nil
        Task {
            do {
                flights = try await provider.search(request)
            } catch {
                flights = []
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    var visibleFlights: [Flight] {
        filters.applying(to: flights)
    }

    func swapRoute() {
        (origin, destination) = (destination, origin)
    }
}

struct ContentView: View {
    @StateObject private var model = FlightSearchViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    searchCard
                    if !model.flights.isEmpty {
                        Text("Demo results · not live inventory")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    results
                }
                .padding(32)
                .frame(maxWidth: 920)
                .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle("Flight Inquiry")
        }
        .frame(minWidth: 760, minHeight: 620)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find your next flight")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Compare schedules and fares in one clear view.")
                .foregroundStyle(.secondary)
        }
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                field("From", text: $model.origin, icon: "airplane.departure")
                Button(action: model.swapRoute) {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.borderless)
                .help("Swap origin and destination")
                field("To", text: $model.destination, icon: "airplane.arrival")
            }
            HStack {
                DatePicker("Departure", selection: $model.date, displayedComponents: .date)
                Divider().frame(height: 32)
                Stepper(value: $model.passengers, in: 1...9) {
                    Label("\(model.passengers) passenger\(model.passengers == 1 ? "" : "s")", systemImage: "person.2")
                }
                Spacer()
                Button("Search flights", systemImage: "magnifyingglass", action: model.search)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary))
    }

    private func field(_ title: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack {
                Image(systemName: icon).foregroundStyle(.tint)
                TextField("Airport code", text: text).textFieldStyle(.plain).textCase(.uppercase)
            }
            .padding(10)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var results: some View {
        if model.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Searching available flights…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        } else if let message = model.errorMessage {
            stateView(icon: "exclamationmark.triangle", title: "Search unavailable", message: message)
        } else if model.flights.isEmpty {
            stateView(icon: "airplane", title: "Ready when you are", message: "Enter your route and date to see flight options.")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(model.visibleFlights.count) flight options").font(.title3.bold())
                    Spacer()
                    Toggle("Nonstop only", isOn: $model.filters.nonstopOnly)
                        .toggleStyle(.checkbox)
                    Picker("Sort", selection: $model.filters.sort) {
                        ForEach(FlightSort.allCases) { sort in
                            Text(sort.title).tag(sort)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                if model.visibleFlights.isEmpty {
                    stateView(icon: "line.3.horizontal.decrease.circle", title: "No matching flights",
                              message: "Try turning off Nonstop only or choosing another route.")
                } else {
                    ForEach(model.visibleFlights) { flight in FlightRow(flight: flight) }
                }
            }
        }
    }

    private func stateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 30)).foregroundStyle(.tint)
            Text(title).font(.headline)
            Text(message).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}

private struct FlightRow: View {
    let flight: Flight
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(flight.airline).font(.headline)
                Text(flight.flightNumber).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(timeFormatter.string(from: flight.departureTime)).font(.title3.weight(.semibold))
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            Text(timeFormatter.string(from: flight.arrivalTime)).font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(flight.durationMinutes / 60)h \(flight.durationMinutes % 60)m").font(.subheadline)
                Text(flight.stopsLabel).font(.caption).foregroundStyle(flight.stops == 0 ? .green : .secondary)
            }
            Divider().frame(height: 40)
            Text(flight.price, format: .currency(code: flight.currency))
                .font(.headline)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
    }
}

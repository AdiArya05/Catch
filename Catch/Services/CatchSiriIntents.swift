import AppIntents
import CoreSpotlight
import CoreLocation
import Foundation
import OSLog
import SwiftUI

// MARK: - Shared transit context

enum CatchSiriTransitStore {
    static let logger = Logger(subsystem: "com.adityaarya.catch", category: "SiriTransit")
    private static let appGroup = "group.com.adityaarya.catch"
    private static let catalogFilename = "catch-siri-bus-stops.json"
    private static let catalogDefaultsKey = "catch-siri-bus-stops-data"
    private static let latitudeKey = "catch-siri-last-latitude"
    private static let longitudeKey = "catch-siri-last-longitude"
    private static let locationDateKey = "catch-siri-last-location-date"

    static func saveBusStops(_ stops: [BusStop]) {
        guard !stops.isEmpty, let data = try? JSONEncoder().encode(stops) else { return }
        if let url = catalogURL {
            try? data.write(to: url, options: .atomic)
        }
        UserDefaults(suiteName: appGroup)?.set(data, forKey: catalogDefaultsKey)
        UserDefaults.standard.set(data, forKey: catalogDefaultsKey)
    }

    /// Makes stop names, road names, and stop codes available to Spotlight's
    /// semantic index. Siri AI uses the same index to resolve natural-language
    /// references such as "Summerdale" without launching Catch first.
    static func indexBusStops(_ stops: [BusStop]) async {
        guard !stops.isEmpty else { return }
        let entities = stops.map(CatchBusStopEntity.init)
        do {
            let index = CSSearchableIndex(name: "Catch.BusStops")
            try await index.indexAppEntities(entities, priority: 1)
            logger.notice("Indexed \(entities.count, privacy: .public) bus stops for Siri AI")
        } catch {
            // Indexing improves discovery, but a Spotlight failure must never
            // prevent the live-arrival feature itself from working.
            logger.error("Couldn't index bus stops: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func busStops() async throws -> [BusStop] {
        if let stops = cachedBusStops() {
            logger.debug("Loaded \(stops.count, privacy: .public) cached Siri stops")
            return stops
        }

        logger.notice("No cached Siri stop catalog; fetching from LTA")
        let stops = try await LTAService.shared.fetchAllBusStops()
        saveBusStops(stops)
        return stops
    }

    static func siriReadyBusStops() -> [BusStop] {
        cachedBusStops() ?? fallbackBusStops()
    }

    static func cachedBusStops() -> [BusStop]? {
        if let url = catalogURL,
           let data = try? Data(contentsOf: url),
           let stops = try? JSONDecoder().decode([BusStop].self, from: data),
           !stops.isEmpty {
            return stops
        }

        for defaults in [UserDefaults(suiteName: appGroup), UserDefaults.standard] {
            if let data = defaults?.data(forKey: catalogDefaultsKey),
               let stops = try? JSONDecoder().decode([BusStop].self, from: data),
               !stops.isEmpty {
                return stops
            }
        }
        return nil
    }

    static func fallbackBusStops() -> [BusStop] {
        let snapshot = CatchWidgetStore.load()
        let places = snapshot.savedPlaces ?? [snapshot.home, snapshot.work].compactMap { $0 }
        var stops = places.compactMap { place -> BusStop? in
            guard let code = place.stopCode, !code.isEmpty else { return nil }
            return BusStop(
                BusStopCode: code,
                RoadName: place.label,
                Description: place.stopName,
                Latitude: 0,
                Longitude: 0
            )
        }

        // Keep the example shown in the Siri onboarding usable even before the
        // first full catalog sync finishes.
        stops.append(BusStop(
            BusStopCode: "21699",
            RoadName: "Boon Lay Way",
            Description: "Summerdale",
            Latitude: 1.34118,
            Longitude: 103.71122
        ))

        var seen = Set<String>()
        return stops.filter { seen.insert($0.BusStopCode).inserted }
    }

    static func saveLocation(_ location: CLLocation) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        defaults.set(location.coordinate.latitude, forKey: latitudeKey)
        defaults.set(location.coordinate.longitude, forKey: longitudeKey)
        defaults.set(location.timestamp, forKey: locationDateKey)
    }

    static func lastLocation() -> CLLocation? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              defaults.object(forKey: latitudeKey) != nil,
              defaults.object(forKey: longitudeKey) != nil else { return nil }
        return CLLocation(
            latitude: defaults.double(forKey: latitudeKey),
            longitude: defaults.double(forKey: longitudeKey)
        )
    }

    private static var catalogURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(catalogFilename)
    }
}

// MARK: - Siri bus-stop entity

struct CatchBusStopEntity: IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Bus Stop",
        numericFormat: "^1 bus stop"
    )
    static let defaultQuery = CatchBusStopQuery()

    let id: String

    @Property(title: "Stop Name")
    var name: String

    @Property(title: "Road")
    var roadName: String

    @Property(title: "Latitude")
    var latitude: Double

    @Property(title: "Longitude")
    var longitude: Double

    init(stop: BusStop) {
        id = stop.BusStopCode
        name = stop.Description
        roadName = stop.RoadName
        latitude = stop.Latitude
        longitude = stop.Longitude
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(roadName) · \(id)",
            image: .init(systemName: "bus.stop.fill"),
            synonyms: ["\(roadName)", "bus stop \(id)", "stop \(id)"]
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = name
        attributes.contentDescription = "Bus stop \(id) on \(roadName)"
        attributes.keywords = [name, roadName, id, "bus stop", "bus arrival"]
        attributes.latitude = NSNumber(value: latitude)
        attributes.longitude = NSNumber(value: longitude)
        return attributes
    }
}

struct CatchBusStopQuery: EntityStringQuery {
    func entities(for identifiers: [CatchBusStopEntity.ID]) async throws -> [CatchBusStopEntity] {
        CatchSiriTransitStore.logger.debug("Resolving stop identifiers: \(identifiers, privacy: .public)")
        let requested = Set(identifiers)
        let stops = CatchSiriTransitStore.siriReadyBusStops()
        return stops
            .filter { requested.contains($0.BusStopCode) }
            .map(CatchBusStopEntity.init)
    }

    func entities(matching string: String) async throws -> [CatchBusStopEntity] {
        CatchSiriTransitStore.logger.debug("Resolving spoken stop: \(string, privacy: .public)")
        let query = normalized(string)
        guard !query.isEmpty else { return try await suggestedEntities() }

        let immediateMatches = CatchSiriTransitStore.fallbackBusStops().filter {
            normalized($0.Description) == query || normalized($0.BusStopCode) == query
        }
        if !immediateMatches.isEmpty {
            return immediateMatches.map(CatchBusStopEntity.init)
        }

        let stops = CatchSiriTransitStore.siriReadyBusStops()
        return stops
            .compactMap { stop -> (BusStop, Int)? in
                let name = normalized(stop.Description)
                let road = normalized(stop.RoadName)
                let code = normalized(stop.BusStopCode)

                let score: Int
                if code == query || name == query {
                    score = 0
                } else if name.hasPrefix(query) {
                    score = 1
                } else if name.contains(query) {
                    score = 2
                } else if road.hasPrefix(query) {
                    score = 3
                } else if road.contains(query) || code.contains(query) {
                    score = 4
                } else {
                    return nil
                }
                return (stop, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.Description.localizedStandardCompare(rhs.0.Description) == .orderedAscending
            }
            .prefix(10)
            .map { CatchBusStopEntity(stop: $0.0) }
    }

    func suggestedEntities() async throws -> [CatchBusStopEntity] {
        let stops = CatchSiriTransitStore.siriReadyBusStops()
        let byCode = Dictionary(uniqueKeysWithValues: stops.map { ($0.BusStopCode, $0) })
        let snapshot = CatchWidgetStore.load()
        let savedCodes = (snapshot.savedPlaces ?? [snapshot.home, snapshot.work].compactMap { $0 })
            .compactMap(\.stopCode)

        var seen = Set<String>()
        var suggestions = savedCodes.compactMap { code -> CatchBusStopEntity? in
            guard seen.insert(code).inserted, let stop = byCode[code] else { return nil }
            return CatchBusStopEntity(stop: stop)
        }

        if let location = CatchSiriTransitStore.lastLocation() {
            suggestions.append(contentsOf: stops
                .map { stop in
                    (stop, location.distance(from: CLLocation(latitude: stop.Latitude, longitude: stop.Longitude)))
                }
                .sorted { $0.1 < $1.1 }
                .compactMap { stop, _ -> CatchBusStopEntity? in
                    guard seen.insert(stop.BusStopCode).inserted else { return nil }
                    return CatchBusStopEntity(stop: stop)
                }
                .prefix(max(0, 10 - suggestions.count)))
        }

        return Array(suggestions.prefix(10))
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}

// MARK: - Arrival intent

struct GetBusArrivalIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Bus Arrival"
    static let description = IntentDescription(
        "Checks when a specific bus is arriving at a specific Singapore bus stop.",
        categoryName: "Bus Arrivals",
        searchKeywords: ["bus", "arrival", "timing", "stop"]
    )
    static let openAppWhenRun = false
    static let isDiscoverable = true

    @Parameter(
        title: "Bus Number",
        description: "The bus service, such as 154.",
        requestValueDialog: "Which bus number?"
    )
    var busService: String?

    @Parameter(
        title: "Bus Stop",
        description: "A Singapore bus stop.",
        requestValueDialog: "Which bus stop?"
    )
    var stop: CatchBusStopEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("When is bus \(\.$busService) coming to \(\.$stop)?")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let suppliedService: String
        if let busService {
            suppliedService = busService
        } else {
            suppliedService = try await $busService.requestValue("Which bus number?")
        }

        let resolvedStop: CatchBusStopEntity
        if let stop {
            resolvedStop = stop
        } else {
            resolvedStop = try await $stop.requestValue("Which bus stop?")
        }
        let serviceNumber = suppliedService
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !serviceNumber.isEmpty else {
            let result = CatchBusArrivalSnippetModel.missingBus(stop: resolvedStop)
            return .result(dialog: "I need a bus number to check \(resolvedStop.name).", view: CatchBusArrivalSnippetView(model: result))
        }

        do {
            CatchSiriTransitStore.logger.notice(
                "Running bus \(serviceNumber, privacy: .public) at stop \(resolvedStop.id, privacy: .public)"
            )
            let response = try await LTAService.shared.fetchBusArrivals(busStopCode: resolvedStop.id)
            guard let service = response.Services.first(where: {
                $0.ServiceNo.caseInsensitiveCompare(serviceNumber) == .orderedSame
            }) else {
                let result = CatchBusArrivalSnippetModel.notServing(service: serviceNumber, stop: resolvedStop)
                return .result(
                    dialog: "Bus \(serviceNumber) is not currently serving \(resolvedStop.name).",
                    view: CatchBusArrivalSnippetView(model: result)
                )
            }

            let result = CatchBusArrivalSnippetModel(service: service, stop: resolvedStop)
            return .result(
                dialog: IntentDialog(stringLiteral: result.spokenResponse),
                view: CatchBusArrivalSnippetView(model: result)
            )
        } catch {
            CatchSiriTransitStore.logger.error("Bus arrival lookup failed: \(error.localizedDescription, privacy: .public)")
            let result = CatchBusArrivalSnippetModel.unavailable(service: serviceNumber, stop: resolvedStop)
            return .result(
                dialog: "I couldn't get live timings for bus \(serviceNumber) at \(resolvedStop.name) right now.",
                view: CatchBusArrivalSnippetView(model: result)
            )
        }
    }

}

struct CatchBusArrivalRequestEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Bus Arrival Request",
        numericFormat: "^1 bus arrival request"
    )
    static let defaultQuery = CatchBusArrivalRequestQuery()

    let id: String

    @Property(title: "Bus Number")
    var busService: String

    @Property(title: "Stop Name")
    var stopName: String

    @Property(title: "Stop Code")
    var stopCode: String

    @Property(title: "Road")
    var roadName: String

    init(busService: String, stop: CatchBusStopEntity) {
        let normalizedService = busService
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        id = "\(normalizedService)|\(stop.id)"
        self.busService = normalizedService
        stopName = stop.name
        stopCode = stop.id
        roadName = stop.roadName
    }

    var stop: CatchBusStopEntity {
        CatchBusStopEntity(stop: BusStop(
            BusStopCode: stopCode,
            RoadName: roadName,
            Description: stopName,
            Latitude: 0,
            Longitude: 0
        ))
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Bus \(busService) at \(stopName)",
            subtitle: "\(roadName) · \(stopCode)",
            image: .init(systemName: "bus.fill"),
            synonyms: [
                "\(busService) at \(stopName)",
                "bus \(busService) at \(stopName)",
                "\(busService) coming to \(stopName)",
                "bus \(busService) coming to \(stopName)",
                "\(busService) to \(stopName)"
            ]
        )
    }
}

struct CatchBusArrivalRequestQuery: EntityStringQuery {
    func entities(for identifiers: [CatchBusArrivalRequestEntity.ID]) async throws -> [CatchBusArrivalRequestEntity] {
        CatchSiriTransitStore.logger.debug("Restoring arrival requests: \(identifiers, privacy: .public)")
        let stops = CatchSiriTransitStore.siriReadyBusStops()
        let stopsByCode = Dictionary(uniqueKeysWithValues: stops.map { ($0.BusStopCode, $0) })

        return identifiers.compactMap { identifier in
            let components = identifier.split(separator: "|", maxSplits: 1).map(String.init)
            guard components.count == 2, let stop = stopsByCode[components[1]] else { return nil }
            return CatchBusArrivalRequestEntity(busService: components[0], stop: CatchBusStopEntity(stop: stop))
        }
    }

    func entities(matching string: String) async throws -> [CatchBusArrivalRequestEntity] {
        CatchSiriTransitStore.logger.debug("Resolving spoken arrival request: \(string, privacy: .public)")
        guard let parsed = Self.parse(string) else { return [] }
        let matches = (try? await CatchBusStopQuery().entities(matching: parsed.stopName)) ?? []
        return matches.prefix(5).map {
            CatchBusArrivalRequestEntity(busService: parsed.service, stop: $0)
        }
    }

    func suggestedEntities() async throws -> [CatchBusArrivalRequestEntity] {
        let summerdale = CatchBusStopEntity(stop: BusStop(
            BusStopCode: "21699",
            RoadName: "Boon Lay Way",
            Description: "Summerdale",
            Latitude: 1.34118,
            Longitude: 103.71122
        ))
        var suggestions = [CatchBusArrivalRequestEntity(busService: "154", stop: summerdale)]
        var seen = Set(suggestions.map(\.id))

        // App Shortcut phrase parameters aren't open-ended. Siri generates a
        // spoken shortcut for each entity returned here, so expose the bus and
        // stop combinations the person actually uses in Catch.
        let snapshot = CatchWidgetStore.load()
        let catalog = CatchSiriTransitStore.siriReadyBusStops()
        let byCode = Dictionary(uniqueKeysWithValues: catalog.map { ($0.BusStopCode, $0) })
        let places = snapshot.savedPlaces ?? [snapshot.home, snapshot.work].compactMap { $0 }

        for place in places {
            guard let code = place.stopCode, !code.isEmpty else { continue }
            let stop = byCode[code] ?? BusStop(
                BusStopCode: code,
                RoadName: place.label,
                Description: place.stopName,
                Latitude: 0,
                Longitude: 0
            )
            let entity = CatchBusStopEntity(stop: stop)
            for bus in place.buses {
                let request = CatchBusArrivalRequestEntity(busService: bus.serviceNo, stop: entity)
                if seen.insert(request.id).inserted {
                    suggestions.append(request)
                }
            }
        }

        if let code = snapshot.stopCode, !code.isEmpty {
            let stop = byCode[code] ?? BusStop(
                BusStopCode: code,
                RoadName: "Singapore",
                Description: snapshot.stopName,
                Latitude: 0,
                Longitude: 0
            )
            let entity = CatchBusStopEntity(stop: stop)
            for bus in snapshot.pinnedBuses {
                let request = CatchBusArrivalRequestEntity(busService: bus.serviceNo, stop: entity)
                if seen.insert(request.id).inserted {
                    suggestions.append(request)
                }
            }
        }

        return Array(suggestions.prefix(20))
    }

    private static func parse(_ text: String) -> (service: String, stopName: String)? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let expression = try? NSRegularExpression(pattern: #"(?i)\b(?:bus\s*)?([0-9]{1,3}[A-Z]?)\b"#),
              let match = expression.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
              let serviceRange = Range(match.range(at: 1), in: cleaned) else { return nil }

        let service = String(cleaned[serviceRange]).uppercased()
        let lowercased = cleaned.lowercased()
        let separators = [" coming to ", " arrive at ", " arriving at ", " at ", " to "]
        let stopName = separators.compactMap { separator -> String? in
            guard let range = lowercased.range(of: separator, options: .backwards) else { return nil }
            return String(cleaned[range.upperBound...])
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        }.first ?? ""

        guard !stopName.isEmpty else { return nil }
        return (service, stopName)
    }
}

/// App Shortcuts allow one dynamic parameter in each invocation phrase. This
/// concrete entity resolves the spoken bus and stop together, so Siri can hand
/// the intent a stable service number and stop code instead of an opaque sentence.
struct AskCatchBusArrivalIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask About a Bus"
    static let description = IntentDescription(
        "Ask when a bus is coming to a stop, for example: when is 154 coming to Summerdale?",
        categoryName: "Bus Arrivals",
        searchKeywords: ["bus", "arrival", "Siri", "timing"]
    )
    static let openAppWhenRun = false
    static let isDiscoverable = true

    @Parameter(
        title: "Bus and Stop",
        description: "A bus service and bus stop, such as 154 at Summerdale.",
        requestValueDialog: "Which bus and bus stop should I check?"
    )
    var request: CatchBusArrivalRequestEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Check \(\.$request)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let stop = request.stop
        let serviceNumber = request.busService
        CatchSiriTransitStore.logger.notice(
            "Running Siri arrival lookup for bus \(serviceNumber, privacy: .public) at stop \(request.stopCode, privacy: .public)"
        )

        do {
            let response = try await LTAService.shared.fetchBusArrivals(busStopCode: request.stopCode)
            guard let service = response.Services.first(where: {
                $0.ServiceNo.caseInsensitiveCompare(serviceNumber) == .orderedSame
            }) else {
                let result = CatchBusArrivalSnippetModel.notServing(service: serviceNumber, stop: stop)
                return .result(
                    dialog: "Bus \(serviceNumber) is not currently serving \(stop.name).",
                    view: CatchBusArrivalSnippetView(model: result)
                )
            }

            let result = CatchBusArrivalSnippetModel(service: service, stop: stop)
            return .result(
                dialog: IntentDialog(stringLiteral: result.spokenResponse),
                view: CatchBusArrivalSnippetView(model: result)
            )
        } catch {
            CatchSiriTransitStore.logger.error("Arrival lookup failed: \(error.localizedDescription, privacy: .public)")
            let result = CatchBusArrivalSnippetModel.unavailable(service: serviceNumber, stop: stop)
            return .result(
                dialog: "I couldn't get live timings for bus \(serviceNumber) at \(stop.name) right now.",
                view: CatchBusArrivalSnippetView(model: result)
            )
        }
    }
}

private struct CatchBusArrivalSnippetModel: Sendable {
    let serviceNumber: String
    let stopName: String
    let stopCode: String
    let roadName: String
    let arrivals: [Int?]
    let crowding: String
    let message: String?

    init(service: BusService, stop: CatchBusStopEntity) {
        serviceNumber = service.ServiceNo
        stopName = stop.name
        stopCode = stop.id
        roadName = stop.roadName
        arrivals = [service.NextBus.arrivalMinutes, service.NextBus2.arrivalMinutes, service.NextBus3.arrivalMinutes]
        crowding = service.NextBus.loadColor.label
        message = nil
    }

    private init(serviceNumber: String, stop: CatchBusStopEntity, message: String) {
        self.serviceNumber = serviceNumber
        stopName = stop.name
        stopCode = stop.id
        roadName = stop.roadName
        arrivals = []
        crowding = "Live data unavailable"
        self.message = message
    }

    static func missingBus(stop: CatchBusStopEntity) -> Self {
        Self(serviceNumber: "—", stop: stop, message: "Choose a bus number to see its live arrival.")
    }

    static func notServing(service: String, stop: CatchBusStopEntity) -> Self {
        Self(serviceNumber: service, stop: stop, message: "This bus is not currently listed at this stop.")
    }

    static func unavailable(service: String, stop: CatchBusStopEntity) -> Self {
        Self(serviceNumber: service, stop: stop, message: "Live timings couldn't be reached. Try again shortly.")
    }

    var spokenResponse: String {
        let available = arrivals.compactMap { $0 }
        guard let first = available.first else {
            return "There is no live arrival prediction for bus \(serviceNumber) at \(stopName) right now."
        }

        let firstText = first == 0 ? "arriving now" : first == 1 ? "one minute away" : "\(first) minutes away"
        if available.count > 1 {
            return "Bus \(serviceNumber) at \(stopName) is \(firstText). The following bus is in \(available[1]) minutes."
        }
        return "Bus \(serviceNumber) at \(stopName) is \(firstText)."
    }
}

private struct CatchBusArrivalSnippetView: View {
    let model: CatchBusArrivalSnippetModel
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }

    private var softBackground: Color {
        colorScheme == .dark ? Color(hex: "292929") : Color(hex: "F5F5F5")
    }

    private var accent: Color { Color(hex: "5AC8FA") }
    private var success: Color { Color(hex: "30D158") }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let message = model.message {
                statusMessage(message)
            } else {
                arrivalGrid
                crowdingBadge
            }
        }
        .padding(14)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), lineWidth: 1)
        )
    }

    private func arrivalText(_ minutes: Int?) -> String {
        guard let minutes else { return "—" }
        if minutes == 0 { return "Arr" }
        return "\(minutes) min"
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(model.serviceNumber)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(minHeight: 56)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "0A84FF"), accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(model.stopName)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text("\(model.roadName) · \(model.stopCode)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
    }

    private var arrivalGrid: some View {
        HStack(spacing: 8) {
            ForEach(Array(model.arrivals.enumerated()), id: \.offset) { index, minutes in
                VStack(alignment: .leading, spacing: 5) {
                    Text(index == 0 ? "Next" : index == 1 ? "Then" : "Later")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(arrivalText(minutes))
                        .font(.system(size: index == 0 ? 24 : 21, weight: .black, design: .rounded))
                        .foregroundStyle(index == 0 ? success : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                }
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .padding(.horizontal, 12)
                .background(
                    (index == 0 ? success.opacity(colorScheme == .dark ? 0.18 : 0.12) : softBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(index == 0 ? success.opacity(0.22) : Color.primary.opacity(0.05), lineWidth: 1)
                )
            }
        }
    }

    private var crowdingBadge: some View {
        Label(model.crowding, systemImage: "person.2.fill")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(softBackground, in: Capsule())
    }

    private func statusMessage(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(softBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Nearby stops intent

struct ShowNearbyBusStopsIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Nearby Bus Stops"
    static let description = IntentDescription("Shows the closest bus stops using Catch's most recent location.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let location = CatchSiriTransitStore.lastLocation() else {
            let view = CatchNearbyStopsSnippetView(stops: [], message: "Open Catch once and allow location access to find nearby stops.")
            return .result(dialog: "Open Catch once and allow location access so I can find nearby bus stops.", view: view)
        }

        let stops = CatchSiriTransitStore.siriReadyBusStops()
            .map { stop in
                CatchNearbyStopResult(
                    stop: CatchBusStopEntity(stop: stop),
                    distance: location.distance(from: CLLocation(latitude: stop.Latitude, longitude: stop.Longitude))
                )
            }
            .sorted { $0.distance < $1.distance }
            .prefix(5)

        let results = Array(stops)
        let nearest = results.first
        let dialog: IntentDialog = if let nearest {
            "The nearest stop is \(nearest.stop.name), \(nearest.distanceText) away."
        } else {
            "I couldn't find any nearby bus stops."
        }
        return .result(dialog: dialog, view: CatchNearbyStopsSnippetView(stops: results, message: nil))
    }
}

private struct CatchNearbyStopResult: Sendable {
    let stop: CatchBusStopEntity
    let distance: CLLocationDistance

    var distanceText: String {
        if distance < 1_000 { return "\(Int(distance.rounded())) m" }
        return String(format: "%.1f km", distance / 1_000)
    }
}

private struct CatchNearbyStopsSnippetView: View {
    let stops: [CatchNearbyStopResult]
    let message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Nearby bus stops", systemImage: "location.fill")
                .font(.headline)
                .foregroundStyle(Color(red: 0.08, green: 0.48, blue: 0.94))

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(stops.enumerated()), id: \.element.stop.id) { index, result in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color(red: 0.08, green: 0.48, blue: 0.94), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.stop.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text("\(result.stop.roadName) · \(result.stop.id)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(result.distanceText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Siri phrases

struct CatchAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskCatchBusArrivalIntent(),
            phrases: [
                "Ask \(.applicationName) \(\.$request)",
                "Check \(\.$request) in \(.applicationName)",
                "When is bus \(\.$request) in \(.applicationName)",
                "When is \(\.$request) with \(.applicationName)",
                "\(.applicationName) bus \(\.$request)",
                "Ask \(.applicationName) about a bus"
            ],
            shortTitle: "Ask Catch",
            systemImageName: "sparkles"
        )

        AppShortcut(
            intent: GetBusArrivalIntent(),
            phrases: [
                "Check a bus arrival in \(.applicationName)",
                "When is my bus coming with \(.applicationName)",
                "Ask \(.applicationName) for a bus arrival"
            ],
            shortTitle: "Check Bus Arrival",
            systemImageName: "bus.fill"
        )

        AppShortcut(
            intent: ShowNearbyBusStopsIntent(),
            phrases: [
                "Show nearby bus stops in \(.applicationName)",
                "Find bus stops near me with \(.applicationName)"
            ],
            shortTitle: "Nearby Bus Stops",
            systemImageName: "location.fill"
        )
    }

    static var shortcutTileColor: ShortcutTileColor { .blue }
}

import Foundation
import CoreLocation
import SwiftUI
import Combine
import UserNotifications
import SwiftData
import WidgetKit

@MainActor
class AppState: ObservableObject {
    private enum DefaultsKey {
        static let savedLocations = "catch-saved-locations"
        static let legacySavedLocations = "catch-saved-locations"
        static let userName = "catch-user-name"
        static let legacyUserName = "catch-user-name"
        static let darkMode = "catch-dark-mode"
        static let legacyDarkMode = "catch-dark-mode"
        static let isProMember = "catch-pro-member"
        static let firstUseDate = "catch-first-use-date"
        static let secondDayProPromptShown = "catch-second-day-pro-prompt-shown"
        static let pinnedBusServices = "catch-pinned-bus-services"
        static let pendingLiveBoardTrip = "catch-pending-live-board-trip"
        static let notificationsEnabled = "catch-notifications-enabled"
    }

    @Published var nearbyStops: [NearbyStop] = []
    @Published var allBusStops: [BusStop] = []
    @Published var savedLocations: [SavedLocation] = []
    @Published var isLoadingStops = false
    @Published var isLoadingNearby = false
    @Published var userName: String = "Adi"
    @Published var locationError: String?
    @Published var isDarkMode: Bool = true
    @Published var hasCompletedOnboarding: Bool = false

    @Published var catchabilityResults: [CatchabilityResult] = []
    @Published var catchabilityMessage: String = ""
    @Published var catchabilityLocationName: String = ""
    @Published var catchabilityBusStopCode: String = ""
    @Published var catchabilityBusStopDescription: String = ""
    @Published var isLoadingCatchability = false
    @Published var commuteInsight: String = ""
    @Published var showInsightCard = false
    @Published var isCatchItEnabled: Bool = true
    @Published var isLeaveNowAlertsEnabled: Bool = true
    @Published var isSmartSuggestionsEnabled: Bool = false
    @Published var areNotificationsEnabled: Bool = false
    @Published var isProMember: Bool = false
    @Published var showProPaywall: Bool = false
    @Published var proPaywallContext: String = "Catch Pro"
    @Published private var pinnedBusServicesByStop: [String: Set<String>] = [:]

    let locationManager = LocationManager()
    let freeSavedPlaceLimit = 3
    private let forceOnboardingForPolishRun = false
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private var hasLoadedStops = false
    private var lastCatchabilityRefreshLocation: CLLocation?
    private var pendingLiveBoardTrip: PendingLiveBoardTrip?
    private var cancellables = Set<AnyCancellable>()

    var customLocations: [SavedLocation] {
        savedLocations.filter { $0.id != "home" }
    }

    init(modelContainer: ModelContainer = CatchPersistence.makeContainer()) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        loadSavedLocations()
        loadUserName()
        loadDarkMode()
        loadFeatureToggles()
        loadProState()
        loadPinnedBusServices()
        loadPendingLiveBoardTrip()
        registerFirstUseDate()
        loadCommuteInsight()
        if forceOnboardingForPolishRun {
            hasCompletedOnboarding = false
            UserDefaults.standard.set(false, forKey: "catch-onboarding-done")
        } else {
            hasCompletedOnboarding = (appSettings()?.hasCompletedOnboarding ?? false) || UserDefaults.standard.bool(forKey: "catch-onboarding-done")
        }
        persistAppSettings()

        locationManager.$location
            .receive(on: RunLoop.main)
            .sink { [weak self] location in
                guard let self else { return }
                updateNearbyStops()
                refreshCatchabilityIfNeeded(for: location)
                completeLiveBoardTripIfReady()
            }
            .store(in: &cancellables)

        locationManager.$authorizationStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    self?.locationManager.startUpdating()
                }
            }
            .store(in: &cancellables)

        Task { await loadBusStops() }
        Task { await refreshWidgetSnapshot() }
        refreshNotificationSetting()
    }

    func loadBusStops() async {
        guard !hasLoadedStops else { return }
        isLoadingStops = true
        do {
            allBusStops = try await LTAService.shared.fetchAllBusStops()
            hasLoadedStops = true
            updateNearbyStops()
            refreshCatchability()
        } catch {
            #if DEBUG
            print("Failed to load bus stops: \(error)")
            #endif
            locationError = "Failed to load bus stop data: \(error.localizedDescription)"
        }
        isLoadingStops = false
    }

    func updateNearbyStops() {
        guard let location = locationManager.location, !allBusStops.isEmpty else { return }
        isLoadingNearby = true
        let sorted = allBusStops
            .map { stop in
                let stopLocation = CLLocation(latitude: stop.Latitude, longitude: stop.Longitude)
                let distance = location.distance(from: stopLocation)
                return NearbyStop(stop: stop, distance: distance)
            }
            .sorted { $0.distance < $1.distance }
            .prefix(10)
        nearbyStops = Array(sorted)
        isLoadingNearby = false
    }

    func searchBusStops(query: String) -> [BusStop] {
        let q = query.lowercased()
        return allBusStops.filter {
            $0.Description.lowercased().contains(q) ||
            $0.BusStopCode.lowercased().contains(q) ||
            $0.RoadName.lowercased().contains(q)
        }.prefix(20).map { $0 }
    }

    // MARK: - Saved Locations

    func loadSavedLocations() {
        let stored = fetchStoredLocations()
        if !stored.isEmpty {
            savedLocations = removeLegacyDefaultHomeIfNeeded(from: stored.map(\.savedLocation))
        } else {
            let savedData = UserDefaults.standard.data(forKey: DefaultsKey.savedLocations)
                ?? UserDefaults.standard.data(forKey: DefaultsKey.legacySavedLocations)

            if let data = savedData,
               let legacy = try? JSONDecoder().decode([SavedLocation].self, from: data) {
                savedLocations = removeLegacyDefaultHomeIfNeeded(from: legacy)
            } else {
                savedLocations = []
            }
        }
        saveSavedLocations()
        Task { await refreshWidgetSnapshot() }
    }

    private func removeLegacyDefaultHomeIfNeeded(from locations: [SavedLocation]) -> [SavedLocation] {
        locations.filter { location in
            !(location.id == "home"
              && location.name == "Home"
              && location.icon == "house.fill"
              && location.busStopCode == "21699"
              && location.busStopDescription == "Summerdale"
              && location.walkMinutes == 5)
        }
    }

    func saveSavedLocations() {
        let stored = fetchStoredLocations()
        stored.forEach { modelContext.delete($0) }
        for (index, location) in savedLocations.enumerated() {
            modelContext.insert(StoredSavedLocation(location: location, sortOrder: index))
        }
        try? modelContext.save()

        if let data = try? JSONEncoder().encode(savedLocations) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.savedLocations)
        }
    }

    func addLocation(_ location: SavedLocation) {
        guard isProMember || savedLocations.count < freeSavedPlaceLimit else {
            presentProPaywall(context: "Unlimited saved stops")
            return
        }
        savedLocations.append(location)
        saveSavedLocations()
    }

    func updateLocation(id: String, name: String, icon: String? = nil, colorHex: String? = nil, busStopCode: String, description: String) {
        if let index = savedLocations.firstIndex(where: { $0.id == id }) {
            savedLocations[index].name = name
            if let icon = icon {
                savedLocations[index].icon = icon
            }
            if let colorHex = colorHex {
                savedLocations[index].colorHex = colorHex
            }
            savedLocations[index].busStopCode = busStopCode
            savedLocations[index].busStopDescription = description
            saveSavedLocations()
            Task { await refreshWidgetSnapshot() }
        }
    }

    func updateWalkTime(id: String, minutes: Int) {
        if let index = savedLocations.firstIndex(where: { $0.id == id }) {
            savedLocations[index].walkMinutes = minutes
            saveSavedLocations()
            Task { await refreshWidgetSnapshot() }
        }
    }

    func removeLocation(id: String) {
        savedLocations.removeAll { $0.id == id }
        saveSavedLocations()
        Task { await refreshWidgetSnapshot() }
    }

    func savedLocation(forBusStopCode code: String) -> SavedLocation? {
        savedLocations.first { $0.busStopCode == code }
    }

    // MARK: - Pinned Buses

    func pinnedBusServices(for stopCode: String) -> Set<String> {
        pinnedBusServicesByStop[stopCode] ?? []
    }

    func isBusServicePinned(stopCode: String, serviceNo: String) -> Bool {
        pinnedBusServices(for: stopCode).contains(serviceNo)
    }

    func togglePinnedBusService(stopCode: String, serviceNo: String) {
        var pinned = pinnedBusServicesByStop[stopCode] ?? []
        if pinned.contains(serviceNo) {
            pinned.remove(serviceNo)
        } else {
            pinned.insert(serviceNo)
        }

        if pinned.isEmpty {
            pinnedBusServicesByStop.removeValue(forKey: stopCode)
        } else {
            pinnedBusServicesByStop[stopCode] = pinned
        }

        savePinnedBusServices()
        Task {
            await refreshWidgetSnapshot(preferredStopCode: stopCode)
            await refreshActiveLiveBoardIfNeeded(for: stopCode)
        }
    }

    func liveBoardServices(for stopCode: String, services: [BusService]) -> [BusService] {
        let pinned = pinnedBusServices(for: stopCode)
        let source = pinned.isEmpty ? services : services.filter { pinned.contains($0.ServiceNo) }
        return sortedBusServices(source)
    }

    func refreshActiveLiveBoardIfNeeded(for stopCode: String? = nil) async {
        guard let activity = LiveActivityManager.shared.activeActivity else { return }
        let activeStopCode = activity.attributes.stopCode
        if let stopCode, stopCode != activeStopCode { return }

        do {
            let response = try await LTAService.shared.fetchBusArrivals(busStopCode: activeStopCode)
            let sorted = sortedBusServices(response.Services)
            await LiveActivityManager.shared.updateStopWatch(
                services: liveBoardServices(for: activeStopCode, services: sorted)
            )
            await refreshWidgetSnapshot(
                preferredStopCode: activeStopCode,
                preferredStopName: activity.attributes.stopName,
                services: sorted
            )
            updateLiveBoardTrip(
                stopCode: activeStopCode,
                stopName: activity.attributes.stopName,
                services: liveBoardServices(for: activeStopCode, services: sorted)
            )
        } catch {
            #if DEBUG
            print("Live Board refresh error: \(error)")
            #endif
        }
    }

    private func loadPinnedBusServices() {
        let descriptor = FetchDescriptor<StoredPinnedBusService>(
            sortBy: [SortDescriptor(\.pinnedAt, order: .forward)]
        )
        let stored = (try? modelContext.fetch(descriptor)) ?? []
        if !stored.isEmpty {
            pinnedBusServicesByStop = Dictionary(grouping: stored, by: \.stopCode)
                .mapValues { Set($0.map(\.serviceNo)) }
            return
        }

        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.pinnedBusServices),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else { return }
        pinnedBusServicesByStop = decoded.mapValues { Set($0) }
        savePinnedBusServices()
    }

    private func savePinnedBusServices() {
        let descriptor = FetchDescriptor<StoredPinnedBusService>()
        let stored = (try? modelContext.fetch(descriptor)) ?? []
        stored.forEach { modelContext.delete($0) }

        for (stopCode, services) in pinnedBusServicesByStop {
            for serviceNo in services.sorted(by: serviceNumberSort) {
                modelContext.insert(StoredPinnedBusService(stopCode: stopCode, serviceNo: serviceNo))
            }
        }
        try? modelContext.save()

        let encodable = pinnedBusServicesByStop.mapValues { Array($0).sorted(by: serviceNumberSort) }
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.pinnedBusServices)
        }
    }

    private func sortedBusServices(_ services: [BusService]) -> [BusService] {
        services.sorted { serviceNumberSort($0.ServiceNo, $1.ServiceNo) }
    }

    private func serviceNumberSort(_ lhs: String, _ rhs: String) -> Bool {
        let lhsNumber = Int(lhs.filter(\.isNumber)) ?? Int.max
        let rhsNumber = Int(rhs.filter(\.isNumber)) ?? Int.max
        if lhsNumber != rhsNumber { return lhsNumber < rhsNumber }
        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    // MARK: - Widgets

    func refreshWidgetSnapshot(preferredStopCode: String? = nil, preferredStopName: String? = nil, services preferredServices: [BusService]? = nil) async {
        let validLocations = savedLocations.filter { !$0.busStopCode.isEmpty }
        let preferredLocation = preferredStopCode.flatMap { code in
            validLocations.first { $0.busStopCode == code }
        }
        let preferredStop = preferredStopCode.flatMap { code in
            allBusStops.first { $0.BusStopCode == code }
        }
        let selectedLocation = preferredLocation ?? closestSavedLocation(from: validLocations) ?? validLocations.first

        var stopName = preferredStopName
            ?? preferredLocation?.busStopDescription
            ?? preferredStop?.Description
            ?? selectedLocation?.busStopDescription
            ?? CatchWidgetSnapshot.empty.stopName
        var pinnedBuses: [CatchWidgetBus] = []

        if let preferredStopCode {
            let pinned = pinnedBusServices(for: preferredStopCode)
            let walkMinutes = preferredLocation?.walkMinutes ?? selectedLocation?.walkMinutes ?? 5

            if let preferredServices {
                let sorted = sortedBusServices(preferredServices)
                let source = prioritizePinnedServices(sorted, pinned: pinned)
                pinnedBuses = source.prefix(4).map { widgetBus(from: $0, walkMinutes: walkMinutes) }
            } else {
                do {
                    let response = try await LTAService.shared.fetchBusArrivals(busStopCode: preferredStopCode)
                    let sorted = sortedBusServices(response.Services)
                    let source = prioritizePinnedServices(sorted, pinned: pinned)
                    pinnedBuses = source.prefix(4).map { widgetBus(from: $0, walkMinutes: walkMinutes) }
                } catch {
                    #if DEBUG
                    print("Widget snapshot error: \(error)")
                    #endif
                }
            }
        } else if let selectedLocation {
            stopName = selectedLocation.busStopDescription
            pinnedBuses = await widgetBuses(for: selectedLocation, limit: 4, preferPinned: true)
        }

        let home = await widgetPlace(for: validLocations.first { $0.name.localizedCaseInsensitiveContains("home") }, label: "Home")
        let work = await widgetPlace(for: validLocations.first { $0.name.localizedCaseInsensitiveContains("work") }, label: "Work")

        let snapshot = CatchWidgetSnapshot(
            stopCode: preferredStopCode ?? selectedLocation?.busStopCode,
            stopName: stopName,
            updatedAt: Date(),
            pinnedBuses: pinnedBuses,
            home: home,
            work: work,
            isProMember: isProMember
        )

        CatchWidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func closestSavedLocation(from locations: [SavedLocation]) -> SavedLocation? {
        guard let location = locationManager.location else { return locations.first }

        return locations.min { lhs, rhs in
            let lhsStop = allBusStops.first { $0.BusStopCode == lhs.busStopCode }
            let rhsStop = allBusStops.first { $0.BusStopCode == rhs.busStopCode }
            let lhsDistance = lhsStop.map { location.distance(from: CLLocation(latitude: $0.Latitude, longitude: $0.Longitude)) } ?? .greatestFiniteMagnitude
            let rhsDistance = rhsStop.map { location.distance(from: CLLocation(latitude: $0.Latitude, longitude: $0.Longitude)) } ?? .greatestFiniteMagnitude
            return lhsDistance < rhsDistance
        }
    }

    private func widgetPlace(for location: SavedLocation?, label: String) async -> CatchWidgetPlace? {
        guard let location else { return nil }
        let buses = await widgetBuses(for: location, limit: 4, preferPinned: false)
        return CatchWidgetPlace(label: label, stopCode: location.busStopCode, stopName: location.busStopDescription, buses: buses)
    }

    private func widgetBuses(for location: SavedLocation, limit: Int, preferPinned: Bool) async -> [CatchWidgetBus] {
        do {
            let response = try await LTAService.shared.fetchBusArrivals(busStopCode: location.busStopCode)
            let sorted = sortedBusServices(response.Services)
            let pinned = pinnedBusServices(for: location.busStopCode)
            let source = preferPinned ? prioritizePinnedServices(sorted, pinned: pinned) : sorted
            return source.prefix(limit).map { widgetBus(from: $0, walkMinutes: location.walkMinutes) }
        } catch {
            #if DEBUG
            print("Widget snapshot error: \(error)")
            #endif
            return []
        }
    }

    private func prioritizePinnedServices(_ services: [BusService], pinned: Set<String>) -> [BusService] {
        guard !pinned.isEmpty else { return services }
        let pinnedServices = services.filter { pinned.contains($0.ServiceNo) }
        let remainingServices = services.filter { !pinned.contains($0.ServiceNo) }
        return pinnedServices + remainingServices
    }

    private func widgetBus(from service: BusService, walkMinutes: Int) -> CatchWidgetBus {
        CatchWidgetBus(
            serviceNo: service.ServiceNo,
            arrivals: [service.NextBus.arrivalMinutes, service.NextBus2.arrivalMinutes, service.NextBus3.arrivalMinutes],
            catchability: widgetCatchability(arrivalMinutes: service.NextBus.arrivalMinutes, walkMinutes: walkMinutes)
        )
    }

    private func widgetCatchability(arrivalMinutes: Int?, walkMinutes: Int) -> CatchWidgetCatchability {
        guard let arrivalMinutes else { return .unknown }
        let leaveIn = arrivalMinutes - walkMinutes
        if leaveIn > 5 { return .easy }
        if leaveIn >= 0 { return .leaveNow }
        return .tooTight
    }

    private func fetchStoredLocations() -> [StoredSavedLocation] {
        let descriptor = FetchDescriptor<StoredSavedLocation>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func estimatedWalkMinutes(to nearbyStop: NearbyStop) -> Int {
        max(1, Int(ceil(nearbyStop.distance / 80)))
    }

    // MARK: - User Name

    func loadUserName() {
        if let settings = appSettings(), !settings.userName.isEmpty {
            userName = normalizedUserName(settings.userName)
        } else if let name = UserDefaults.standard.string(forKey: DefaultsKey.userName)
            ?? UserDefaults.standard.string(forKey: DefaultsKey.legacyUserName) {
            userName = normalizedUserName(name)
        }
    }

    func saveUserName(_ name: String) {
        userName = normalizedUserName(name)
        persistAppSettings()
        UserDefaults.standard.set(userName, forKey: DefaultsKey.userName)
    }

    private func normalizedUserName(_ name: String) -> String {
        let oldPlaceholderName = ["Ya", "sh"].joined()
        return name.trimmingCharacters(in: .whitespacesAndNewlines) == oldPlaceholderName ? "Adi" : name
    }

    // MARK: - Dark Mode

    func loadDarkMode() {
        if let settings = appSettings() {
            isDarkMode = settings.isDarkMode
        } else if UserDefaults.standard.object(forKey: DefaultsKey.darkMode) != nil {
            isDarkMode = UserDefaults.standard.bool(forKey: DefaultsKey.darkMode)
        } else if UserDefaults.standard.object(forKey: DefaultsKey.legacyDarkMode) != nil {
            isDarkMode = UserDefaults.standard.bool(forKey: DefaultsKey.legacyDarkMode)
        }
    }

    func saveDarkMode(_ value: Bool) {
        isDarkMode = value
        persistAppSettings()
        UserDefaults.standard.set(value, forKey: DefaultsKey.darkMode)
    }

    // MARK: - Feature Toggles

    func loadFeatureToggles() {
        areNotificationsEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.notificationsEnabled)

        if let settings = appSettings() {
            isCatchItEnabled = settings.isCatchItEnabled
            isLeaveNowAlertsEnabled = settings.isLeaveNowAlertsEnabled
            isSmartSuggestionsEnabled = false
            areNotificationsEnabled = settings.areNotificationsEnabled
        } else {
            if UserDefaults.standard.object(forKey: "catch-catch-it-enabled") != nil {
                isCatchItEnabled = UserDefaults.standard.bool(forKey: "catch-catch-it-enabled")
            }
            if UserDefaults.standard.object(forKey: "catch-leave-now-enabled") != nil {
                isLeaveNowAlertsEnabled = UserDefaults.standard.bool(forKey: "catch-leave-now-enabled")
            }
            isSmartSuggestionsEnabled = false
        }
    }

    func saveCatchItEnabled(_ value: Bool) {
        isCatchItEnabled = value
        persistAppSettings()
        UserDefaults.standard.set(value, forKey: "catch-catch-it-enabled")
    }

    func saveLeaveNowAlerts(_ value: Bool) {
        guard isProMember || value == false else {
            presentProPaywall(context: "Smart leave-now alerts")
            return
        }
        isLeaveNowAlertsEnabled = value
        persistAppSettings()
        UserDefaults.standard.set(value, forKey: "catch-leave-now-enabled")
    }

    func saveSmartSuggestions(_ value: Bool) {
        guard isProMember || value == false else {
            presentProPaywall(context: "Catch Pro")
            return
        }
        isSmartSuggestionsEnabled = false
        persistAppSettings()
        UserDefaults.standard.set(false, forKey: "catch-smart-suggestions-enabled")
    }

    func saveNotificationsEnabled(_ value: Bool) {
        if value {
            requestNotificationPermission { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    self.saveNotificationPermissionResult(granted)
                }
            }
        } else {
            saveNotificationPermissionResult(false)
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }

    func saveNotificationPermissionResult(_ granted: Bool) {
        areNotificationsEnabled = granted
        persistAppSettings()
        UserDefaults.standard.set(granted, forKey: DefaultsKey.notificationsEnabled)
    }

    func refreshNotificationSetting() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                guard let self else { return }
                if settings.authorizationStatus == .denied || settings.authorizationStatus == .notDetermined {
                    self.areNotificationsEnabled = false
                    self.persistAppSettings()
                    UserDefaults.standard.set(false, forKey: DefaultsKey.notificationsEnabled)
                }
            }
        }
    }

    // MARK: - Pro

    func loadProState() {
        #if DEBUG
        isProMember = false
        isLeaveNowAlertsEnabled = false
        isSmartSuggestionsEnabled = false
        UserDefaults.standard.set(false, forKey: DefaultsKey.isProMember)
        CatchWidgetStore.saveProMembership(false)
        if let settings = appSettings() {
            settings.isProMember = false
            settings.isLeaveNowAlertsEnabled = false
            settings.isSmartSuggestionsEnabled = false
            try? modelContext.save()
        }
        #else
        isProMember = false
        isLeaveNowAlertsEnabled = false
        isSmartSuggestionsEnabled = false
        CatchWidgetStore.saveProMembership(false)
        #endif
    }

    func setProMembership(_ value: Bool) {
        isProMember = value
        if value {
            isLeaveNowAlertsEnabled = true
            isSmartSuggestionsEnabled = false
        } else {
            isLeaveNowAlertsEnabled = false
            isSmartSuggestionsEnabled = false
        }
        persistAppSettings()
        UserDefaults.standard.set(value, forKey: DefaultsKey.isProMember)
        UserDefaults.standard.set(isLeaveNowAlertsEnabled, forKey: "catch-leave-now-enabled")
        UserDefaults.standard.set(isSmartSuggestionsEnabled, forKey: "catch-smart-suggestions-enabled")
        CatchWidgetStore.saveProMembership(value)
        WidgetCenter.shared.reloadAllTimelines()
        if value {
            showProPaywall = false
        }
    }

    func presentProPaywall(context: String = "Catch Pro") {
        proPaywallContext = context
        showProPaywall = true
    }

    private func registerFirstUseDate() {
        let settings = ensuredAppSettings()
        if settings.firstUseDate == nil {
            let legacy = UserDefaults.standard.object(forKey: DefaultsKey.firstUseDate) as? Date
            settings.firstUseDate = legacy ?? Date()
            try? modelContext.save()
            UserDefaults.standard.set(settings.firstUseDate, forKey: DefaultsKey.firstUseDate)
        }
    }

    func presentSecondDayProOfferIfNeeded() {
        guard hasCompletedOnboarding, !isProMember else { return }
        let settings = ensuredAppSettings()
        guard !settings.secondDayProPromptShown else { return }
        guard let firstUse = settings.firstUseDate ?? UserDefaults.standard.object(forKey: DefaultsKey.firstUseDate) as? Date else { return }
        let startOfFirst = Calendar.current.startOfDay(for: firstUse)
        let startOfToday = Calendar.current.startOfDay(for: Date())
        guard startOfToday > startOfFirst else { return }
        settings.secondDayProPromptShown = true
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: DefaultsKey.secondDayProPromptShown)
        presentProPaywall(context: "Your second day with Catch")
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        hasCompletedOnboarding = true
        persistAppSettings()
        UserDefaults.standard.set(true, forKey: "catch-onboarding-done")
    }

    // MARK: - Greeting

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    // MARK: - Can I Catch It?

    func refreshCatchability() {
        guard let location = locationManager.location else { return }
        let validLocations = savedLocations.filter { !$0.busStopCode.isEmpty }
        guard !validLocations.isEmpty else { return }
        lastCatchabilityRefreshLocation = location

        var closestLoc = validLocations[0]
        var closestDistance = Double.infinity

        for loc in validLocations {
            if let busStop = allBusStops.first(where: { $0.BusStopCode == loc.busStopCode }) {
                let stopLocation = CLLocation(latitude: busStop.Latitude, longitude: busStop.Longitude)
                let dist = location.distance(from: stopLocation)
                if dist < closestDistance {
                    closestDistance = dist
                    closestLoc = loc
                }
            }
        }

        isLoadingCatchability = true
        catchabilityLocationName = closestLoc.name
        catchabilityBusStopCode = closestLoc.busStopCode
        catchabilityBusStopDescription = closestLoc.busStopDescription

        Task {
            do {
                let response = try await LTAService.shared.fetchBusArrivals(busStopCode: closestLoc.busStopCode)
                let walkMin = closestLoc.walkMinutes

                let results: [CatchabilityResult] = response.Services.compactMap { svc in
                    guard let arrival = svc.NextBus.arrivalMinutes else { return nil }
                    let leaveIn = arrival - walkMin
                    let level: CatchabilityLevel
                    if leaveIn > 5 { level = .easy }
                    else if leaveIn >= 0 { level = .tight }
                    else { level = .missed }
                    return CatchabilityResult(
                        busService: svc.ServiceNo,
                        arrivalMinutes: arrival,
                        walkMinutes: walkMin,
                        level: level,
                        nextBusMinutes: svc.NextBus2.arrivalMinutes
                    )
                }
                .sorted { a, b in
                    let order: [CatchabilityLevel] = [.tight, .easy, .missed]
                    let ai = order.firstIndex(of: a.level) ?? 3
                    let bi = order.firstIndex(of: b.level) ?? 3
                    if ai != bi { return ai < bi }
                    return a.arrivalMinutes < b.arrivalMinutes
                }

                let topResults = Array(results.prefix(3))
                catchabilityResults = topResults

                if !topResults.isEmpty {
                    catchabilityMessage = Self.localCatchabilityMessage(
                        results: topResults,
                        stopName: closestLoc.busStopDescription
                    )
                }

                checkLeaveNowAlert(results: results, stopName: closestLoc.busStopDescription)
            } catch {
                #if DEBUG
                print("Catchability error: \(error)")
                #endif
            }
            isLoadingCatchability = false
        }
    }

    private func refreshCatchabilityIfNeeded(for location: CLLocation?) {
        guard let location, hasLoadedStops, isProMember, isCatchItEnabled, !isLoadingCatchability else { return }
        if let lastCatchabilityRefreshLocation,
           location.distance(from: lastCatchabilityRefreshLocation) < 80,
           !catchabilityResults.isEmpty {
            return
        }
        refreshCatchability()
    }


    // MARK: - Smart Leave Now Alert

    func requestNotificationPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            completion?(granted)
        }
    }

    private func checkLeaveNowAlert(results: [CatchabilityResult], stopName: String) {
        guard isProMember && areNotificationsEnabled && isLeaveNowAlertsEnabled else { return }
        guard let urgent = results.first(where: { $0.level == .tight && $0.leaveInMinutes <= 3 && $0.leaveInMinutes >= 0 }) else { return }

        let lastAlertKey = "catch-last-alert-\(urgent.busService)"
        let now = Date()
        if let lastAlert = UserDefaults.standard.object(forKey: lastAlertKey) as? Date,
           now.timeIntervalSince(lastAlert) < 120 { return }
        UserDefaults.standard.set(now, forKey: lastAlertKey)

        Task {
            let message = "Leave now to catch Bus \(urgent.busService) · \(urgent.arrivalMinutes) min away from \(stopName)"

            let content = UNMutableNotificationContent()
            content.title = "Catch"
            content.body = message
            content.sound = .default

            let request = UNNotificationRequest(identifier: "leaveNow-\(urgent.busService)", content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Commute Patterns

    func beginLiveBoardTrip(stopCode: String, stopName: String, services: [BusService]) {
        guard !stopCode.isEmpty, !stopName.isEmpty else { return }
        guard let trackedService = liveBoardServices(for: stopCode, services: services).first else { return }

        if pendingLiveBoardTrip?.stopCode == stopCode,
           pendingLiveBoardTrip?.serviceNo == trackedService.ServiceNo {
            updateLiveBoardTrip(stopCode: stopCode, stopName: stopName, services: services)
            return
        }

        let stop = allBusStops.first { $0.BusStopCode == stopCode }
        let trip = PendingLiveBoardTrip(
            stopCode: stopCode,
            stopName: stopName,
            serviceNo: trackedService.ServiceNo,
            startedAt: Date(),
            stopLatitude: stop?.Latitude,
            stopLongitude: stop?.Longitude,
            initialArrivalMinutes: trackedService.NextBus.arrivalMinutes,
            sawArrivalAt: trackedService.NextBus.arrivalMinutes.map { $0 <= 0 ? Date() : nil } ?? nil
        )

        pendingLiveBoardTrip = trip
        persistPendingLiveBoardTrip()
        completeLiveBoardTripIfReady()
    }

    func updateLiveBoardTrip(stopCode: String, stopName: String, services: [BusService]) {
        guard var trip = pendingLiveBoardTrip, trip.stopCode == stopCode else { return }

        let liveServices = liveBoardServices(for: stopCode, services: services)
        let selectedService = liveServices.first { $0.ServiceNo == trip.serviceNo } ?? liveServices.first
        guard let selectedService else { return }

        trip.stopName = stopName
        trip.serviceNo = selectedService.ServiceNo
        if trip.stopLatitude == nil || trip.stopLongitude == nil,
           let stop = allBusStops.first(where: { $0.BusStopCode == stopCode }) {
            trip.stopLatitude = stop.Latitude
            trip.stopLongitude = stop.Longitude
        }

        if selectedService.NextBus.arrivalMinutes == 0 {
            trip.sawArrivalAt = trip.sawArrivalAt ?? Date()
        }

        pendingLiveBoardTrip = trip
        persistPendingLiveBoardTrip()
        completeLiveBoardTripIfReady()
    }

    func cancelLiveBoardTripTracking() {
        pendingLiveBoardTrip = nil
        UserDefaults.standard.removeObject(forKey: DefaultsKey.pendingLiveBoardTrip)
    }

    private func completeLiveBoardTripIfReady() {
        guard let trip = pendingLiveBoardTrip,
              let sawArrivalAt = trip.sawArrivalAt else { return }

        let now = Date()
        guard now.timeIntervalSince(sawArrivalAt) <= 10 * 60 else {
            cancelLiveBoardTripTracking()
            return
        }

        guard isUserAwayFromTrackedStop(trip) else { return }
        recordCompletedLiveBoardTrip(trip)
        cancelLiveBoardTripTracking()
    }

    private func isUserAwayFromTrackedStop(_ trip: PendingLiveBoardTrip) -> Bool {
        guard let location = locationManager.location,
              let latitude = trip.stopLatitude,
              let longitude = trip.stopLongitude else { return false }

        let stopLocation = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: stopLocation) > 150
    }

    private func recordCompletedLiveBoardTrip(_ trip: PendingLiveBoardTrip) {
        let now = Date()
        let recentWindow: TimeInterval = 45 * 60
        let duplicate = loadCommuteLogs().contains { log in
            log.stopCode == trip.stopCode &&
            log.busServices.contains(trip.serviceNo) &&
            now.timeIntervalSince(log.timestamp) < recentWindow
        }
        guard !duplicate else { return }

        logCommuteEntry(stopCode: trip.stopCode, stopName: trip.stopName, services: [trip.serviceNo])
    }

    private func loadPendingLiveBoardTrip() {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.pendingLiveBoardTrip),
              let trip = try? JSONDecoder().decode(PendingLiveBoardTrip.self, from: data) else { return }

        if Date().timeIntervalSince(trip.startedAt) < 2 * 60 * 60 {
            pendingLiveBoardTrip = trip
        } else {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.pendingLiveBoardTrip)
        }
    }

    private func persistPendingLiveBoardTrip() {
        guard let pendingLiveBoardTrip,
              let data = try? JSONEncoder().encode(pendingLiveBoardTrip) else { return }
        UserDefaults.standard.set(data, forKey: DefaultsKey.pendingLiveBoardTrip)
    }

    private func logCommuteEntry(stopCode: String, stopName: String, services: [String]) {
        let now = Date()
        let calendar = Calendar.current
        let entry = CommuteLogEntry(
            stopCode: stopCode,
            stopName: stopName,
            timestamp: now,
            dayOfWeek: calendar.component(.weekday, from: now),
            hour: calendar.component(.hour, from: now),
            busServices: services
        )

        var logs = loadCommuteLogs()
        logs.append(entry)
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!
        logs = logs.filter { $0.timestamp > twoWeeksAgo }
        saveCommuteLogs(logs)

        if shouldAnalyzePatterns() {
            analyzePatterns(logs: logs)
        }
    }

    func recordCommuteIntent(stopCode: String, stopName: String, services: [String]) {
        let cleanedServices = services.filter { !$0.isEmpty }
        guard !stopCode.isEmpty, !stopName.isEmpty, !cleanedServices.isEmpty else { return }

        let now = Date()
        let recentWindow: TimeInterval = 45 * 60
        let recentMatch = loadCommuteLogs().contains { log in
            log.stopCode == stopCode && now.timeIntervalSince(log.timestamp) < recentWindow
        }
        guard !recentMatch else { return }

        logCommuteEntry(stopCode: stopCode, stopName: stopName, services: cleanedServices)
    }

    private func loadCommuteLogs() -> [CommuteLogEntry] {
        let descriptor = FetchDescriptor<StoredCommuteLogEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let stored = (try? modelContext.fetch(descriptor)) ?? []
        if !stored.isEmpty {
            return stored.map(\.commuteLogEntry)
        }

        guard let data = UserDefaults.standard.data(forKey: "catch-commute-logs"),
              let logs = try? JSONDecoder().decode([CommuteLogEntry].self, from: data) else { return [] }
        saveCommuteLogs(logs)
        return logs
    }

    private func saveCommuteLogs(_ logs: [CommuteLogEntry]) {
        let descriptor = FetchDescriptor<StoredCommuteLogEntry>()
        let stored = (try? modelContext.fetch(descriptor)) ?? []
        stored.forEach { modelContext.delete($0) }
        logs.forEach { modelContext.insert(StoredCommuteLogEntry(entry: $0)) }
        try? modelContext.save()

        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: "catch-commute-logs")
        }
    }

    func commuteLogs() -> [CommuteLogEntry] {
        loadCommuteLogs()
    }

    private func shouldAnalyzePatterns() -> Bool {
        let logs = loadCommuteLogs()
        guard hasRecognizablePattern(in: logs) else { return false }
        let lastAnalysis = UserDefaults.standard.object(forKey: "catch-last-pattern-analysis") as? Date ?? .distantPast
        return Date().timeIntervalSince(lastAnalysis) > 7 * 24 * 3600
    }

    private func hasRecognizablePattern(in logs: [CommuteLogEntry]) -> Bool {
        guard logs.count >= 10 else { return false }

        var groupedCounts: [String: Int] = [:]
        for log in logs {
            let key = "\(log.stopCode)-\(log.dayOfWeek)-\(log.hour)"
            groupedCounts[key, default: 0] += 1
        }

        return groupedCounts.values.contains { $0 >= 3 }
    }

    private func analyzePatterns(logs: [CommuteLogEntry]) {
        guard isProMember, isSmartSuggestionsEnabled else { return }
        UserDefaults.standard.set(Date(), forKey: "catch-last-pattern-analysis")
        guard let insight = Self.localCommuteInsight(from: logs), hasRecognizablePattern(in: logs) else { return }
        commuteInsight = insight
        showInsightCard = true
        persistAppSettings()
        UserDefaults.standard.set(insight, forKey: "catch-commute-insight")
    }

    private func loadCommuteInsight() {
        let storedInsight = appSettings()?.commuteInsight
        let legacyInsight = UserDefaults.standard.string(forKey: "catch-commute-insight")
        let candidateInsight = storedInsight?.isEmpty == false ? storedInsight : legacyInsight
        if let insight = candidateInsight, !insight.isEmpty, hasRecognizablePattern(in: loadCommuteLogs()) {
            commuteInsight = insight.trimmingCharacters(in: .whitespacesAndNewlines)
            showInsightCard = false
        } else {
            commuteInsight = ""
            showInsightCard = false
        }
    }

    func dismissInsight() {
        showInsightCard = false
    }

    private static func localCatchabilityMessage(results: [CatchabilityResult], stopName: String) -> String {
        guard let best = results.first else { return "" }

        switch best.level {
        case .easy:
            return "You can catch \(best.busService) comfortably."
        case .tight:
            return "Leave now for \(best.busService)."
        case .missed:
            if let next = best.nextBusMinutes {
                return "\(best.busService) is too tight. Next in \(next) min."
            }
            return "\(best.busService) is too tight."
        }
    }

    private static func localCommuteInsight(from logs: [CommuteLogEntry]) -> String? {
        guard logs.count >= 10 else { return nil }

        var grouped: [String: (entry: CommuteLogEntry, count: Int)] = [:]
        for log in logs {
            let key = "\(log.stopName)|\(log.dayOfWeek)|\(log.hour)"
            let current = grouped[key]
            grouped[key] = (log, (current?.count ?? 0) + 1)
        }

        guard let strongest = grouped.values.max(by: { $0.count < $1.count }), strongest.count >= 3 else {
            return nil
        }

        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let day = dayNames[safe: strongest.entry.dayOfWeek] ?? "this day"
        return "You often check \(strongest.entry.stopName) around \(strongest.entry.hour):00 on \(day)."
    }
}

private extension AppState {
    func appSettings() -> StoredAppSettings? {
        let descriptor = FetchDescriptor<StoredAppSettings>()
        return try? modelContext.fetch(descriptor).first
    }

    func ensuredAppSettings() -> StoredAppSettings {
        if let settings = appSettings() {
            return settings
        }

        let settings = StoredAppSettings()
        modelContext.insert(settings)
        try? modelContext.save()
        return settings
    }

    func persistAppSettings() {
        let settings = ensuredAppSettings()
        settings.userName = userName
        settings.isDarkMode = isDarkMode
        settings.hasCompletedOnboarding = hasCompletedOnboarding
        settings.isCatchItEnabled = isCatchItEnabled
        settings.isLeaveNowAlertsEnabled = isLeaveNowAlertsEnabled
        settings.isSmartSuggestionsEnabled = isSmartSuggestionsEnabled
        settings.areNotificationsEnabled = areNotificationsEnabled
        settings.isProMember = isProMember
        settings.commuteInsight = commuteInsight
        try? modelContext.save()
    }
}

enum CatchPersistence {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            StoredSavedLocation.self,
            StoredPinnedBusService.self,
            StoredCommuteLogEntry.self,
            StoredAppSettings.self
        ])
        let configuration = ModelConfiguration("CatchLocal", schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create Catch SwiftData container: \(error)")
        }
    }
}

private struct PendingLiveBoardTrip: Codable {
    let stopCode: String
    var stopName: String
    var serviceNo: String
    let startedAt: Date
    var stopLatitude: Double?
    var stopLongitude: Double?
    let initialArrivalMinutes: Int?
    var sawArrivalAt: Date?
}

@Model
final class StoredSavedLocation {
    var id: String = ""
    var name: String = ""
    var icon: String = ""
    var colorHex: String = ""
    var busStopCode: String = ""
    var busStopDescription: String = ""
    var walkMinutes: Int = 5
    var sortOrder: Int = 0
    var updatedAt: Date = Date()

    init(location: SavedLocation, sortOrder: Int) {
        self.id = location.id
        self.name = location.name
        self.icon = location.icon
        self.colorHex = location.colorHex
        self.busStopCode = location.busStopCode
        self.busStopDescription = location.busStopDescription
        self.walkMinutes = location.walkMinutes
        self.sortOrder = sortOrder
        self.updatedAt = Date()
    }

    var savedLocation: SavedLocation {
        SavedLocation(
            id: id,
            name: name,
            icon: icon,
            colorHex: colorHex,
            busStopCode: busStopCode,
            busStopDescription: busStopDescription,
            walkMinutes: walkMinutes
        )
    }
}

@Model
final class StoredPinnedBusService {
    var stopCode: String = ""
    var serviceNo: String = ""
    var pinnedAt: Date = Date()

    init(stopCode: String, serviceNo: String) {
        self.stopCode = stopCode
        self.serviceNo = serviceNo
        self.pinnedAt = Date()
    }
}

@Model
final class StoredCommuteLogEntry {
    var stopCode: String = ""
    var stopName: String = ""
    var timestamp: Date = Date()
    var dayOfWeek: Int = 1
    var hour: Int = 0
    var busServicesValue: String = ""

    init(entry: CommuteLogEntry) {
        self.stopCode = entry.stopCode
        self.stopName = entry.stopName
        self.timestamp = entry.timestamp
        self.dayOfWeek = entry.dayOfWeek
        self.hour = entry.hour
        self.busServicesValue = entry.busServices.joined(separator: ",")
    }

    var commuteLogEntry: CommuteLogEntry {
        CommuteLogEntry(
            stopCode: stopCode,
            stopName: stopName,
            timestamp: timestamp,
            dayOfWeek: dayOfWeek,
            hour: hour,
            busServices: busServicesValue.split(separator: ",").map(String.init)
        )
    }
}

@Model
final class StoredAppSettings {
    var userName: String = "Adi"
    var isDarkMode: Bool = true
    var hasCompletedOnboarding: Bool = false
    var isCatchItEnabled: Bool = true
    var isLeaveNowAlertsEnabled: Bool = true
    var isSmartSuggestionsEnabled: Bool = false
    var areNotificationsEnabled: Bool = false
    var isProMember: Bool = false
    var firstUseDate: Date?
    var secondDayProPromptShown: Bool = false
    var commuteInsight: String = ""

    init() {}
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

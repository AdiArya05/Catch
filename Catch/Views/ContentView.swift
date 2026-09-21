import SwiftUI
import UniformTypeIdentifiers
import StoreKit
import UIKit


private struct BusStopRoute: Hashable, Identifiable {
    let code: String
    let name: String
    var id: String { code }
}


private struct InteractivePopGestureRestorer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.restoreInteractivePopGesture()
    }

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            restoreInteractivePopGesture()
        }

        func restoreInteractivePopGesture() {
            guard let navigationController else { return }
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = self
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            navigationController?.viewControllers.count ?? 0 > 1
        }
    }
}

private struct LocationEditorSheet: Identifiable {
    let id: String
    let editingId: String?
    let initialBusStopCode: String?
    let initialBusStopDescription: String?
    let initialWalkMinutes: Int?

    static let add = LocationEditorSheet(
        id: "add",
        editingId: nil,
        initialBusStopCode: nil,
        initialBusStopDescription: nil,
        initialWalkMinutes: nil
    )

    static func edit(_ id: String) -> LocationEditorSheet {
        LocationEditorSheet(
            id: "edit-\(id)",
            editingId: id,
            initialBusStopCode: nil,
            initialBusStopDescription: nil,
            initialWalkMinutes: nil
        )
    }

    static func addPlace(for nearby: NearbyStop, walkMinutes: Int) -> LocationEditorSheet {
        LocationEditorSheet(
            id: "add-\(nearby.stop.BusStopCode)",
            editingId: nil,
            initialBusStopCode: nearby.stop.BusStopCode,
            initialBusStopDescription: nearby.stop.Description,
            initialWalkMinutes: walkMinutes
        )
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.requestReview) private var requestReview
    @State private var stopPath: [BusStopRoute] = []
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var locationEditorSheet: LocationEditorSheet?
    @State private var showProfile = false

    var body: some View {
        NavigationStack(path: $stopPath) {
            ZStack {
                (colorScheme == .dark ? Color(hex: "292929") : Color(hex: "F5F5F5")).ignoresSafeArea()
                mainContent
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: BusStopRoute.self) { route in
                BusStopDetailView(
                    busStopCode: route.code,
                    busStopName: route.name,
                    onBack: { popToHome() }
                )
                .environmentObject(appState)
                .toolbar(.hidden, for: .navigationBar)
                .background(InteractivePopGestureRestorer())
                .onAppear {
                    if appState.shouldPromptForReviewAfterOpeningBusStop() {
                        requestReview()
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onDismiss: {
                showSettings = false
            })
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showSearch) {
            SearchView { code, name in
                showSearch = false
                openStop(code: code, name: name)
            }
            .presentationDetents([.large])
        }
        .sheet(item: $locationEditorSheet) { sheet in
            AddLocationView(
                editingId: sheet.editingId,
                initialBusStopCode: sheet.initialBusStopCode,
                initialBusStopDescription: sheet.initialBusStopDescription,
                initialWalkMinutes: sheet.initialWalkMinutes
            ) {
                locationEditorSheet = nil
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
        .onReceive(appState.locationManager.$location) { _ in
            appState.updateNearbyStops()
        }
        .onReceive(appState.$allBusStops) { _ in
            appState.updateNearbyStops()
        }
        .onReceive(NotificationCenter.default.publisher(for: .catchHomeSelected)) { _ in
            popToHome()
        }
        .onAppear {
            appState.presentSecondDayProOfferIfNeeded()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    greetingSection
                    if appState.isProMember && appState.isCatchItEnabled && (!appState.catchabilityMessage.isEmpty || appState.isLoadingCatchability) {
                        catchItCard
                    }
                    if !appState.savedLocations.isEmpty {
                        savedLocationsSection
                    }
                    divider
                    nearbySection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
            .transaction { transaction in
                transaction.animation = nil
            }
            .refreshable {
                appState.refreshCatchability()
                appState.updateNearbyStops()
                await appState.refreshActiveLiveBoardIfNeeded()
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(appState.$allBusStops) { stops in
            if !stops.isEmpty && appState.catchabilityMessage.isEmpty && !appState.isLoadingCatchability {
                appState.refreshCatchability()
            }
        }
    }

    private func openStop(code: String, name: String) {
        stopPath = [BusStopRoute(code: code, name: name)]
    }

    private func popToHome() {
        stopPath.removeAll()
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "catch" else { return }

        let host = url.host ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let stopCode = queryItems.first(where: { $0.name == "stopCode" })?.value
            ?? (host == "stop" ? url.pathComponents.dropFirst().first : nil)
        let stopName = queryItems.first(where: { $0.name == "stopName" })?.value

        switch host {
        case "stop", "refresh", "widget":
            openLinkedStop(code: stopCode, name: stopName, shouldRefresh: host == "refresh")
        case "home":
            popToHome()
        case "pro":
            appState.presentProPaywall(context: "Catch Pro widgets")
        default:
            break
        }
    }

    private func openLinkedStop(code: String?, name: String?, shouldRefresh: Bool) {
        let resolvedCode = code ?? name.flatMap { linkedName in
            appState.allBusStops.first { $0.Description.localizedCaseInsensitiveCompare(linkedName) == .orderedSame }?.BusStopCode
        }

        guard let resolvedCode, !resolvedCode.isEmpty else { return }

        let resolvedName = name
            ?? appState.allBusStops.first { $0.BusStopCode == resolvedCode }?.Description
            ?? appState.savedLocation(forBusStopCode: resolvedCode)?.busStopDescription
            ?? "Bus stop"

        if shouldRefresh, stopPath.last?.code == resolvedCode {
            popToHome()
            DispatchQueue.main.async {
                openStop(code: resolvedCode, name: resolvedName)
            }
        } else {
            openStop(code: resolvedCode, name: resolvedName)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 8) {
            Button { showSearch = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                    Text("Search bus stops").lineLimit(1).minimumScaleFactor(0.85)
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
            }
            .glassEffect(.regular.interactive(), in: Capsule())
            .accessibilityLabel("Search bus stops")
            headerButton("arrow.clockwise", label: "Refresh arrivals") {
                appState.refreshCatchability()
                appState.updateNearbyStops()
                Task { await appState.refreshActiveLiveBoardIfNeeded() }
            }
            headerButton("plus", label: "Add saved stop") { openAddSavedPlace() }
            headerButton("person.crop.circle.fill", label: "Profile") { showProfile = true }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private func headerButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(); action() }) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(label)
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                Text("\(appState.greeting), ")
                    .foregroundColor(.secondary)
                Text("\(appState.userName).")
                    .foregroundColor(.primary)
            }
            .font(.system(size: 24, weight: .bold))
            .tracking(24 * -0.025)

            Text("Where are you starting from?")
                .font(.system(size: 24, weight: .bold))
                .tracking(24 * -0.025)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Saved Locations (Home, Work, custom..., Add)

    private var savedLocationsSection: some View {
        SavedStopStrip(locations: appState.savedLocations, isDark: colorScheme == .dark,
            onSelect: { loc in
                guard !loc.busStopCode.isEmpty else { return }
                openStop(code: loc.busStopCode, name: loc.busStopDescription.isEmpty ? loc.name : loc.busStopDescription)
            }, onEdit: { loc in
                Haptics.tap(.medium)
                locationEditorSheet = .edit(loc.id)
            }, onMove: { from, to in
                appState.moveSavedLocations(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            })
            .frame(height: 48)
            .padding(.bottom, 18)
    }

    // MARK: - Divider

    private var divider: some View {
        HStack(spacing: 6) {
            ForEach(0..<40, id: \.self) { _ in
                Circle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 3, height: 3)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 4)
    }

    // MARK: - Nearby

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("Nearby")
                    .font(.system(size: 26, weight: .bold))
                    .tracking(26 * -0.025)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 16, weight: .bold))
                    .rotationEffect(.degrees(45))
            }
            .foregroundColor(.primary)

            if appState.isLoadingStops {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.gray)
                    Text("Loading bus stop data...")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(16 * -0.025)
                        .foregroundColor(Color(hex: "888888"))
                }
                .padding(.vertical, 16)
            } else if appState.locationManager.authorizationStatus == .denied ||
                        appState.locationManager.authorizationStatus == .restricted {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Location access was denied.")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(16 * -0.025)
                        .foregroundColor(Color(hex: "888888"))

                    Text("Go to Settings → Catch → Location and select \"While Using the App\".")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(14 * -0.025)
                        .foregroundColor(Color(hex: "666666"))

                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Open Settings")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(14 * -0.025)
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 16)
            } else if appState.locationManager.authorizationStatus == .notDetermined {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Use your location to see nearby stops.")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(16 * -0.025)
                        .foregroundColor(Color(hex: "888888"))

                    Button(action: {
                        appState.locationManager.requestPermission()
                    }) {
                        Text("Continue")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(14 * -0.025)
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 16)
            } else if appState.isLoadingNearby {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.gray)
                    Text("Finding nearby stops...")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(16 * -0.025)
                        .foregroundColor(Color(hex: "888888"))
                }
                .padding(.vertical, 16)
            } else if appState.locationManager.location == nil {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.gray)
                    Text("Waiting for GPS signal...")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(16 * -0.025)
                        .foregroundColor(Color(hex: "888888"))
                }
                .padding(.vertical, 16)
            } else if appState.nearbyStops.isEmpty && !appState.allBusStops.isEmpty {
                Text("No bus stops within 1.5 km.")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(16 * -0.025)
                    .foregroundColor(Color(hex: "888888"))
                    .padding(.vertical, 16)
            }

            ForEach(Array(appState.nearbyStops.enumerated()), id: \.element.id) { index, nearby in
                let savedLocation = appState.savedLocation(forBusStopCode: nearby.stop.BusStopCode)
                let walkMinutes = savedLocation?.walkMinutes ?? appState.estimatedWalkMinutes(to: nearby)

                Button(action: {
                    withAnimation(.smooth(duration: 0.26)) {
                        openStop(code: nearby.stop.BusStopCode, name: nearby.stop.Description)
                    }
                }) {
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(nearby.stop.Description)
                                    .font(.system(size: 18, weight: .bold))
                                    .tracking(18 * -0.025)
                                    .foregroundColor(.primary)

                                HStack(spacing: 8) {
                                    Text(nearby.stop.RoadName)
                                        .font(.system(size: 13, weight: .bold))
                                        .tracking(13 * -0.025)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)

                                    if savedLocation != nil {
                                        nearbyChip("Pinned", color: Color(hex: "5AC8FA"), icon: "pin.fill")
                                    }

                                    nearbyChip(walkEstimateText(minutes: walkMinutes), color: Color(hex: "8E8E93"), icon: "figure.walk")

                                    Spacer(minLength: 4)

                                    Text(nearby.distanceText)
                                        .font(.system(size: 14, weight: .bold))
                                        .tracking(14 * -0.025)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.vertical, 14)

                        if index < appState.nearbyStops.count - 1 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 0.5)
                        }
                    }
                }
                .contextMenu {
                    if savedLocation == nil {
                        Button(action: { markNearbyStopAsUsual(nearby) }) {
                            Label("Pin Stop", systemImage: "pin.fill")
                        }
                        Button(action: { openAddPlace(for: nearby) }) {
                            Label("Add Place", systemImage: "plus.circle.fill")
                        }
                    } else {
                        Button(role: .destructive, action: { removeNearbyStopPin(savedLocation) }) {
                            Label("Remove Pin", systemImage: "pin.slash.fill")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 112)
    }

    private func openAddPlace(for nearby: NearbyStop) {
        Haptics.tap(.medium)
        guard appState.isProMember || appState.savedLocations.count < appState.freeSavedPlaceLimit else {
            appState.presentProPaywall(context: "Unlimited saved stops")
            return
        }
        locationEditorSheet = .addPlace(for: nearby, walkMinutes: appState.estimatedWalkMinutes(to: nearby))
    }

    private func markNearbyStopAsUsual(_ nearby: NearbyStop) {
        Haptics.tap(.medium)
        let walkMinutes = appState.estimatedWalkMinutes(to: nearby)
        let home = SavedLocation(
            id: "home",
            name: "Home",
            icon: "house.fill",
            colorHex: SavedLocation.defaultColorHex(for: "Home"),
            busStopCode: nearby.stop.BusStopCode,
            busStopDescription: nearby.stop.Description,
            walkMinutes: walkMinutes
        )

        guard appState.savedLocations.contains(where: { $0.id == "home" })
                || appState.isProMember
                || appState.savedLocations.count < appState.freeSavedPlaceLimit else {
            appState.presentProPaywall(context: "Unlimited saved stops")
            return
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            if appState.savedLocations.contains(where: { $0.id == "home" }) {
                appState.updateLocation(
                    id: home.id,
                    name: home.name,
                    icon: home.icon,
                    colorHex: home.colorHex,
                    busStopCode: home.busStopCode,
                    description: home.busStopDescription
                )
                appState.updateWalkTime(id: home.id, minutes: walkMinutes)
            } else {
                appState.addLocation(home)
            }
        }
    }

    private func removeNearbyStopPin(_ savedLocation: SavedLocation?) {
        guard let savedLocation else { return }
        Haptics.tap(.medium)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            if savedLocation.id == "home" {
                appState.updateLocation(
                    id: savedLocation.id,
                    name: savedLocation.name,
                    icon: savedLocation.icon,
                    colorHex: savedLocation.colorHex,
                    busStopCode: "",
                    description: ""
                )
            } else {
                appState.removeLocation(id: savedLocation.id)
            }
        }
    }

    private func nearbyChip(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .tracking(11 * -0.025)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(colorScheme == .dark ? 0.18 : 0.12))
        .clipShape(Capsule())
    }

    // MARK: - Can I Catch It? Card

    private var catchItCard: some View {
        Button(action: {
            if !appState.catchabilityBusStopCode.isEmpty {
                withAnimation(.smooth(duration: 0.26)) {
                    openStop(code: appState.catchabilityBusStopCode, name: appState.catchabilityBusStopDescription)
                }
            }
        }) {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(catchItAccent)
                Text("Can I catch it?")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(13 * -0.025)
                    .foregroundColor(catchItAccent)

                Spacer()

                if !appState.catchabilityLocationName.isEmpty {
                    Text(appState.catchabilityLocationName)
                        .font(.system(size: 14, weight: .bold))
                        .tracking(14 * -0.025)
                        .foregroundColor(Color(hex: "A0A0A8"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }

            if appState.isLoadingCatchability && appState.catchabilityMessage.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.gray)
                        .scaleEffect(0.8)
                    Text("Checking buses...")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                }
            } else {
                catchItDecisionSummary

                if !appState.catchabilityResults.isEmpty {
                    VStack(spacing: 5) {
                        ForEach(appState.catchabilityResults.prefix(2)) { result in
                            catchBusRow(result)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(catchItBg)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        }
        .buttonStyle(.plain)
    }

    private var catchItDecisionSummary: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(catchItHeadline)
                .font(.system(size: 16, weight: .bold))
                .tracking(16 * -0.025)
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let best = appState.catchabilityResults.first {
                Text("Walk \(best.walkMinutes) min to \(appState.catchabilityLocationName.isEmpty ? "your stop" : appState.catchabilityLocationName).")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(11 * -0.025)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var catchItHeadline: String {
        guard let best = appState.catchabilityResults.first else {
            return appState.catchabilityMessage
        }

        switch best.level {
        case .easy:
            return "Catch \(best.busService) in \(arrivalText(best.arrivalMinutes))."
        case .tight:
            return "Leave now for \(best.busService)."
        case .missed:
            if let next = best.nextBusMinutes {
                return "\(best.busService) is too tight. Next in \(next) min."
            }
            return "\(best.busService) is too tight."
        }
    }

    private func catchBusRow(_ result: CatchabilityResult) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(catchLevelColor(result.level))
                .frame(width: 6, height: 6)

            Text(result.busService)
                .font(.system(size: 18, weight: .bold))
                .tracking(18 * -0.025)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 24, alignment: .center)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.14))
                .clipShape(Capsule())

            Capsule()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.2))
                .frame(width: 1, height: 16)

            Text(arrivalText(result.arrivalMinutes))
                .font(.system(size: 14, weight: .bold))
                .tracking(14 * -0.025)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 54, alignment: .leading)

            Spacer(minLength: 8)

            Text(result.level.label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(catchStatusTextColor(result.level))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(catchLevelColor(result.level).opacity(colorScheme == .dark ? 0.28 : 0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            (colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.045))
                .overlay(catchLevelColor(result.level).opacity(colorScheme == .dark ? 0.045 : 0.035))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func arrivalText(_ minutes: Int) -> String {
        minutes <= 0 ? "Arr" : "\(minutes) min"
    }

    private func walkEstimateText(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min walk"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours < 24 {
            return remainingMinutes == 0 ? "\(hours)h walk" : "\(hours)h \(remainingMinutes)m walk"
        }

        return "\(hours / 24)d walk"
    }

    private func catchBusPill(_ result: CatchabilityResult) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(catchLevelColor(result.level))
                .frame(width: 8, height: 8)
            Text(result.busService)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
            Text(result.arrivalMinutes <= 0 ? "Arr" : "\(result.arrivalMinutes)m")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            Text(result.level.label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(catchLevelColor(result.level))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
        .clipShape(Capsule())
    }

    private func catchLevelColor(_ level: CatchabilityLevel) -> Color {
        switch level {
        case .easy: return Color(hex: "4CD964")
        case .tight: return Color(hex: "F5A623")
        case .missed: return Color(hex: "E74C3C")
        }
    }

    private func catchStatusTextColor(_ level: CatchabilityLevel) -> Color {
        switch level {
        case .easy: return Color(hex: "6DFF8A")
        case .tight: return colorScheme == .dark ? Color(hex: "FFB833") : Color(hex: "D97706")
        case .missed: return Color(hex: "FF6B5F")
        }
    }

    private var catchItAccent: Color {
        colorScheme == .dark ? Color(hex: "5AC8FA") : Color(hex: "007AFF")
    }

    private var catchItBg: Color {
        colorScheme == .dark ? Color(hex: "1C3A5C").opacity(0.5) : Color(hex: "D6ECFF")
    }

    // MARK: - AI Insight Card

    private var insightCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "BF5AF2"))

            VStack(alignment: .leading, spacing: 4) {
                Text("Your pattern")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(12 * -0.025)
                    .foregroundColor(.secondary)
                Text(appState.commuteInsight)
                    .font(.system(size: 14, weight: .bold))
                    .tracking(14 * -0.025)
                    .foregroundColor(.primary)
                    .lineSpacing(2)
            }

            Spacer()

            Button(action: { appState.dismissInsight() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color(hex: "3A2A4A").opacity(0.5) : Color(hex: "F0E6FF"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Bottom Bar (Liquid Glass)

    private func openAddSavedPlace() {
        Haptics.tap(.medium)
        if appState.isProMember || appState.savedLocations.count < appState.freeSavedPlaceLimit {
            locationEditorSheet = .add
        } else {
            appState.presentProPaywall(context: "Unlimited saved stops")
        }
    }

    private func accessibilityLabel(forBottomIcon icon: String) -> String {
        switch icon {
        case "gearshape.fill": return "Settings"
        case "person.fill": return "Profile"
        case "plus": return "Add saved place"
        case "house.fill": return "Home"
        default: return icon
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct CatchTabView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) { ContentView().background(HomeTabObserver()) }
            Tab("Maps", systemImage: "map.fill", value: 1) { CatchMapView() }
            Tab("Settings", systemImage: "gearshape.fill", value: 2) { SettingsView(isTab: true) }
        }
        .tint(Color(hex: "5AC8FA"))
        .onChange(of: selectedTab) { _, tab in
            Haptics.tap()
            if tab == 0 { NotificationCenter.default.post(name: .catchHomeSelected, object: nil) }
        }
        .onOpenURL { url in
            guard url.scheme == "catch" else { return }
            switch url.host {
            case "maps": selectedTab = 1
            case "settings": selectedTab = 2
            case "stop", "home", "widget", "refresh": selectedTab = 0
            default: break
            }
        }
    }
}

extension Notification.Name {
    static let catchHomeSelected = Notification.Name("catch-home-tab-selected")
}

// UIKit's native drag and drop supports both a touch hold on iPhone and a mouse
// hold in Simulator while preserving the collection view's settle animation.
private struct SavedStopStrip: UIViewRepresentable {
    let locations: [SavedLocation]
    let isDark: Bool
    let onSelect: (SavedLocation) -> Void
    let onEdit: (SavedLocation) -> Void
    let onMove: (Int, Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 5, left: 24, bottom: 5, right: 24)
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        view.reorderingCadence = .fast
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "stop")
        view.dataSource = context.coordinator
        view.delegate = context.coordinator
        view.dragDelegate = context.coordinator
        view.dropDelegate = context.coordinator
        view.dragInteractionEnabled = true
        return view
    }
    func updateUIView(_ view: UICollectionView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard !coordinator.moving else { return }
        let signature = locations.map { "\($0.id)|\($0.name)|\($0.icon)|\($0.colorHex)" }.joined(separator: ";") + String(isDark)
        guard coordinator.signature != signature else { return }
        coordinator.signature = signature
        coordinator.items = locations
        view.reloadData()
    }
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
        var parent: SavedStopStrip
        var items: [SavedLocation]
        var moving = false
        var signature = ""
        init(_ parent: SavedStopStrip) { self.parent = parent; items = parent.locations }
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "stop", for: indexPath)
            let item = items[indexPath.item]
            let accent = Color(hex: item.colorHex)
            cell.contentConfiguration = UIHostingConfiguration {
                HStack(spacing: 8) {
                    Image(systemName: item.icon).font(.system(size: 13, weight: .bold))
                    Text(item.name).font(.system(size: 14, weight: .bold)).tracking(-0.35).lineLimit(1)
                }
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(accent.opacity(self.parent.isDark ? 0.24 : 0.16), in: Capsule())
            }.margins(.all, 0)
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = item.name
            cell.accessibilityHint = "Hold for edit options, or hold and drag to reorder. Double tap to open stop."
            cell.accessibilityTraits = .button
            let editAction = UIAccessibilityCustomAction(name: "Edit Saved Stop") { [weak self] _ in
                Haptics.tap(.medium)
                self?.parent.onEdit(item)
                return true
            }
            let moveActions = [-1, 1].map { direction in
                UIAccessibilityCustomAction(name: direction < 0 ? "Move earlier" : "Move later") { [weak self, weak collectionView] _ in
                    guard let self, let collectionView,
                          let from = self.items.firstIndex(where: { $0.id == item.id }),
                          self.items.indices.contains(from + direction) else { return false }
                    let to = from + direction
                    self.collectionView(collectionView, moveItemAt: IndexPath(item: from, section: 0), to: IndexPath(item: to, section: 0))
                    collectionView.moveItem(at: IndexPath(item: from, section: 0), to: IndexPath(item: to, section: 0))
                    return true
                }
            }
            cell.accessibilityCustomActions = [editAction] + moveActions
            return cell
        }
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            let width = (items[indexPath.item].name as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 14, weight: .bold)]).width
            return CGSize(width: ceil(width) + 58, height: 38)
        }
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard !moving else { return }
            Haptics.tap()
            parent.onSelect(items[indexPath.item])
        }

        func collectionView(
            _ collectionView: UICollectionView,
            contextMenuConfigurationForItemAt indexPath: IndexPath,
            point: CGPoint
        ) -> UIContextMenuConfiguration? {
            guard items.indices.contains(indexPath.item) else { return nil }
            let item = items[indexPath.item]
            return UIContextMenuConfiguration(identifier: item.id as NSString, previewProvider: nil) { [weak self] _ in
                guard let self else { return nil }
                let edit = UIAction(title: "Edit Saved Stop", image: UIImage(systemName: "pencil")) { [weak self] _ in
                    Haptics.tap(.medium)
                    self?.parent.onEdit(item)
                }
                return UIMenu(children: [edit])
            }
        }
        func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool { items.count > 1 }
        func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
            commitMove(from: sourceIndexPath.item, to: destinationIndexPath.item)
        }

        func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
            guard items.count > 1, items.indices.contains(indexPath.item) else { return [] }
            let item = items[indexPath.item]
            let dragItem = UIDragItem(itemProvider: NSItemProvider(object: item.id as NSString))
            dragItem.localObject = item.id
            moving = true
            Haptics.tap(.medium)
            return [dragItem]
        }

        func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
            UICollectionViewDropProposal(
                operation: session.localDragSession == nil ? .cancel : .move,
                intent: .insertAtDestinationIndexPath
            )
        }

        func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
            guard let destination = coordinator.destinationIndexPath,
                  let dropItem = coordinator.items.first,
                  let id = dropItem.dragItem.localObject as? String,
                  let source = items.firstIndex(where: { $0.id == id }) else { return }
            let target = min(destination.item, items.count - 1)
            guard source != target else {
                coordinator.drop(dropItem.dragItem, toItemAt: IndexPath(item: source, section: 0))
                return
            }

            let movedItem = items.remove(at: source)
            items.insert(movedItem, at: target)
            collectionView.performBatchUpdates {
                collectionView.moveItem(
                    at: IndexPath(item: source, section: 0),
                    to: IndexPath(item: target, section: 0)
                )
            }
            coordinator.drop(dropItem.dragItem, toItemAt: IndexPath(item: target, section: 0))
            finishMove(from: source, to: target)
            Haptics.tap()
        }

        func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
            moving = false
        }

        private func commitMove(from: Int, to: Int) {
            guard from != to, items.indices.contains(from), items.indices.contains(to) else { return }
            let item = items.remove(at: from)
            items.insert(item, at: to)
            finishMove(from: from, to: to)
        }

        private func finishMove(from: Int, to: Int) {
            // Match SwiftUI's new order before it publishes, so UIKit can finish the
            // native lift-and-settle animation without a reload flash.
            signature = items.map { "\($0.id)|\($0.name)|\($0.icon)|\($0.colorHex)" }.joined(separator: ";") + String(parent.isDark)
            parent.onMove(from, to)
        }
    }
}

// Observe native tab reselection without replacing its layout or touch handling.
private struct HomeTabObserver: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Observer { Observer() }
    func updateUIViewController(_ controller: Observer, context: Context) {}
    final class Observer: UIViewController, UITabBarControllerDelegate {
        private weak var previousDelegate: UITabBarControllerDelegate?
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            if let tabs = tabBarController, tabs.delegate !== self {
                previousDelegate = tabs.delegate
                tabs.delegate = self
            }
        }
        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            previousDelegate?.tabBarController?(tabBarController, didSelect: viewController)
            if tabBarController.selectedIndex == 0 {
                NotificationCenter.default.post(name: .catchHomeSelected, object: nil)
            }
        }
        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || previousDelegate?.responds(to: selector) == true
        }
        override func forwardingTarget(for selector: Selector!) -> Any? {
            previousDelegate?.responds(to: selector) == true ? previousDelegate : super.forwardingTarget(for: selector)
        }
    }
}

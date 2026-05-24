import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedBusStopCode: String?
    @State private var selectedBusStopName: String?
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var showAddLocation = false
    @State private var editingLocationId: String?
    @State private var showProfile = false

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(hex: "292929") : Color(hex: "F5F5F5")).ignoresSafeArea()

            if let code = selectedBusStopCode, let name = selectedBusStopName {
                BusStopDetailView(
                    busStopCode: code,
                    busStopName: name,
                    onBack: {
                        withAnimation(.smooth(duration: 0.26)) {
                            selectedBusStopCode = nil
                            selectedBusStopName = nil
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                mainContent
                    .transition(.move(edge: .leading).combined(with: .opacity))
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
                withAnimation(.smooth(duration: 0.26)) {
                    selectedBusStopCode = code
                    selectedBusStopName = name
                }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showAddLocation) {
            AddLocationView(editingId: editingLocationId) {
                showAddLocation = false
                editingLocationId = nil
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
        .onAppear {
            appState.presentSecondDayProOfferIfNeeded()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .animation(.smooth(duration: 0.26), value: selectedBusStopCode)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    greetingSection
                    if appState.isCatchItEnabled && (!appState.catchabilityMessage.isEmpty || appState.isLoadingCatchability) {
                        catchItCard
                    }
                    if appState.isProMember && appState.showInsightCard {
                        insightCard
                    }
                    savedLocationsSection
                    divider
                    nearbySection
                }
            }
            .refreshable {
                appState.refreshCatchability()
                appState.updateNearbyStops()
                await appState.refreshActiveLiveBoardIfNeeded()
            }

            Spacer()
            bottomBar
        }
        .onReceive(appState.$allBusStops) { stops in
            if !stops.isEmpty && appState.catchabilityMessage.isEmpty && !appState.isLoadingCatchability {
                appState.refreshCatchability()
            }
        }
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
            withAnimation(.smooth(duration: 0.26)) {
                selectedBusStopCode = nil
                selectedBusStopName = nil
            }
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

        if shouldRefresh, selectedBusStopCode == resolvedCode {
            withAnimation(.smooth(duration: 0.18)) {
                selectedBusStopCode = nil
                selectedBusStopName = nil
            }
            DispatchQueue.main.async {
                withAnimation(.smooth(duration: 0.26)) {
                    selectedBusStopCode = resolvedCode
                    selectedBusStopName = resolvedName
                }
            }
        } else {
            withAnimation(.smooth(duration: 0.26)) {
                selectedBusStopCode = resolvedCode
                selectedBusStopName = resolvedName
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            Text("\(Calendar.current.component(.day, from: Date()))")
                .font(.system(size: 64, weight: .bold))
                .tracking(64 * -0.025)
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 10) {
                Button(action: { showSearch = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                        Text("Search bus stop")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(16 * -0.025)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 25)
                    .padding(.vertical, 12)
                }
                .glassEffect(.regular.interactive())
                .clipShape(Capsule())

                Button(action: {
                    appState.refreshCatchability()
                    appState.updateNearbyStops()
                    Task { await appState.refreshActiveLiveBoardIfNeeded() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 42, height: 42)
                }
                .glassEffect(.regular.interactive())
                .clipShape(Circle())
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(appState.savedLocations) { loc in
                    let colors = pillColors(for: loc)
                    coloredPill(
                        name: loc.name,
                        icon: loc.icon,
                        bgColor: colors.bg,
                        fgColor: colors.fg
                    ) {
                        if !loc.busStopCode.isEmpty {
                            withAnimation(.smooth(duration: 0.26)) {
                                selectedBusStopCode = loc.busStopCode
                                selectedBusStopName = loc.busStopDescription.isEmpty ? loc.name : loc.busStopDescription
                            }
                        }
                    }
                    .contextMenu {
                        Button(action: {
                            editingLocationId = loc.id
                            showAddLocation = true
                        }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        if loc.id != "home" {
                            Button(role: .destructive, action: {
                                withAnimation {
                                    appState.removeLocation(id: loc.id)
                                }
                            }) {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }

                // Add — subtle gray
                coloredPill(
                    name: "Add",
                    icon: "plus.circle",
                    bgColor: colorScheme == .dark ? Color(hex: "3A3A3A") : Color(hex: "E8E8E8"),
                    fgColor: colorScheme == .dark ? Color(hex: "CCCCCC") : Color(hex: "666666")
                ) {
                    if appState.isProMember || appState.savedLocations.count < appState.freeSavedPlaceLimit {
                        editingLocationId = nil
                        showAddLocation = true
                    } else {
                        appState.presentProPaywall(context: "Unlimited saved places")
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 24)
    }

    private func coloredPill(name: String, icon: String, bgColor: Color, fgColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(name)
                    .font(.system(size: 14, weight: .bold))
                    .tracking(14 * -0.025)
            }
            .foregroundColor(fgColor)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(bgColor)
            .clipShape(Capsule())
        }
    }

    private func pillColors(for loc: SavedLocation) -> (bg: Color, fg: Color) {
        let isDark = colorScheme == .dark
        let accent = Color(hex: loc.colorHex)
        return (accent.opacity(isDark ? 0.24 : 0.16), accent)
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
                    Text("Allow location access to see nearby stops.")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(16 * -0.025)
                        .foregroundColor(Color(hex: "888888"))

                    Button(action: {
                        appState.locationManager.requestPermission()
                    }) {
                        Text("Enable Location")
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
                        selectedBusStopCode = nearby.stop.BusStopCode
                        selectedBusStopName = nearby.stop.Description
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

                                    if savedLocation != nil {
                                        nearbyChip("Usual stop", color: Color(hex: "5AC8FA"), icon: "pin.fill")
                                    }

                                    nearbyChip(walkEstimateText(minutes: walkMinutes), color: Color(hex: "8E8E93"), icon: "figure.walk")
                                }
                            }
                            Spacer()
                            Text(nearby.distanceText)
                                .font(.system(size: 14, weight: .bold))
                                .tracking(14 * -0.025)
                                .foregroundColor(.secondary)
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
                        Button(action: { saveNearbyStop(nearby, as: "Favourite", icon: "heart.fill") }) {
                            Label("Save as Favourite", systemImage: "heart.fill")
                        }
                        Button(action: { saveNearbyStop(nearby, as: "Work", icon: "briefcase.fill") }) {
                            Label("Save as Work", systemImage: "briefcase.fill")
                        }
                        Button(action: { saveNearbyStop(nearby, as: "School", icon: "book.fill") }) {
                            Label("Save as School", systemImage: "book.fill")
                        }
                    }
                    Button(action: { markNearbyStopAsUsual(nearby) }) {
                        Label("Mark as usual stop", systemImage: "pin.fill")
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 100)
    }

    private func saveNearbyStop(_ nearby: NearbyStop, as name: String, icon: String) {
        Haptics.tap(.medium)
        guard appState.isProMember || appState.savedLocations.count < appState.freeSavedPlaceLimit else {
            appState.presentProPaywall(context: "Unlimited saved places")
            return
        }
        let location = SavedLocation(
            id: UUID().uuidString,
            name: name,
            icon: icon,
            colorHex: SavedLocation.defaultColorHex(for: name),
            busStopCode: nearby.stop.BusStopCode,
            busStopDescription: nearby.stop.Description,
            walkMinutes: appState.estimatedWalkMinutes(to: nearby)
        )
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            appState.addLocation(location)
        }
    }

    private func markNearbyStopAsUsual(_ nearby: NearbyStop) {
        Haptics.tap(.medium)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            appState.updateLocation(
                id: "home",
                name: "Home",
                icon: "house.fill",
                colorHex: SavedLocation.defaultColorHex(for: "Home"),
                busStopCode: nearby.stop.BusStopCode,
                description: nearby.stop.Description
            )
            appState.updateWalkTime(id: "home", minutes: appState.estimatedWalkMinutes(to: nearby))
        }
    }

    private func nearbyChip(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .tracking(11 * -0.025)
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
                    selectedBusStopCode = appState.catchabilityBusStopCode
                    selectedBusStopName = appState.catchabilityBusStopDescription
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
                        .font(.system(size: 11, weight: .bold))
                        .tracking(11 * -0.025)
                        .foregroundColor(.secondary)
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

    private var bottomBar: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                    showSettings = true
                }
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 52, height: 52)
            }
            .glassEffect(.regular.interactive())
            .clipShape(Circle())

            Spacer()

            Button(action: {
                editingLocationId = nil
                showAddLocation = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 56, height: 56)
            }
            .glassEffect(.regular.interactive())
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()

            Button(action: { showProfile = true }) {
                Image(systemName: "person.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 52, height: 52)
            }
            .glassEffect(.regular.interactive())
            .clipShape(Circle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
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

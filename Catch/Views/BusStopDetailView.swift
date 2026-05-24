import SwiftUI

struct BusStopDetailView: View {
    let busStopCode: String
    let busStopName: String
    let onBack: () -> Void

    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var services: [BusService] = []
    @State private var isLoading = true
    @State private var timer: Timer?
    @State private var isWatchingLiveActivity = false
    @GestureState private var swipeBackTranslation: CGFloat = 0

    private var bgColor: Color { colorScheme == .dark ? Color(hex: "292929") : Color(hex: "F5F5F5") }
    private var cardBg: Color { colorScheme == .dark ? Color(hex: "1E1E1E") : Color.white }
    private var secondaryBg: Color { colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "E8E8E8") }
    private var timingStripBg: Color { colorScheme == .dark ? Color(hex: "2A2A2A").opacity(0.7) : Color(hex: "E2E4E7") }
    private var timingDividerColor: Color { colorScheme == .dark ? Color.primary.opacity(0.12) : Color(hex: "BFC3CA") }
    private var timingMetaColor: Color { colorScheme == .dark ? .secondary : Color(hex: "6E7480") }
    private var displayServices: [BusService] { sortedServices(services) }
    private var liveBoardServices: [BusService] { appState.liveBoardServices(for: busStopCode, services: services) }
    private var savedLocation: SavedLocation? { appState.savedLocation(forBusStopCode: busStopCode) }
    private var nearbyWalkMinutes: Int? {
        guard let nearby = appState.nearbyStops.first(where: { $0.stop.BusStopCode == busStopCode }) else { return nil }
        return appState.estimatedWalkMinutes(to: nearby)
    }
    private var walkMinutes: Int? { savedLocation?.walkMinutes ?? nearbyWalkMinutes }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 16) {
                    if isLoading && services.isEmpty {
                        loadingView
                    } else if services.isEmpty {
                        emptyView
                    }

                    ForEach(displayServices) { service in
                        busServiceCard(service)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .refreshable {
                await loadArrivals()
            }
        }
        .offset(x: swipeBackTranslation)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: swipeBackTranslation)
        .background(bgColor)
        .task {
            if LiveActivityManager.shared.activeActivity?.attributes.stopCode == busStopCode {
                isWatchingLiveActivity = true
            }
            await loadArrivals()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .updating($swipeBackTranslation) { value, state, _ in
                    guard value.startLocation.x <= 36,
                          value.translation.width > 0,
                          value.translation.width > abs(value.translation.height) * 1.8 else { return }
                    state = min(value.translation.width, 92)
                }
                .onEnded { value in
                    guard value.startLocation.x <= 36,
                          value.translation.width > 80,
                          value.translation.width > abs(value.translation.height) * 1.8 else { return }
                    Haptics.tap()
                    onBack()
                }
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button(action: {
                    Haptics.tap()
                    onBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive())
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(busStopName)
                        .font(.system(size: 18, weight: .bold))
                        .tracking(18 * -0.025)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    HStack(spacing: 8) {
                        Text(busStopCode)
                            .font(.system(size: 14, weight: .bold))
                            .tracking(14 * -0.025)
                            .foregroundColor(.secondary)

                        if savedLocation != nil {
                            stopChip("Usual stop", color: Color(hex: "5AC8FA"), icon: "pin.fill")
                        }

                        if let walkMinutes {
                            stopChip("\(walkMinutes) min walk", color: Color(hex: "8E8E93"), icon: "figure.walk")
                        }
                    }
                }

                Spacer()

                Button(action: {
                    Haptics.tap()
                    Task { await loadArrivals() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                }
                .glassEffect(.regular.interactive())
                .clipShape(Circle())
            }

            if !services.isEmpty {
                Button(action: {
                    Haptics.tap(.medium)
                    if appState.isProMember {
                        Task { await toggleLiveActivity() }
                    } else {
                        appState.presentProPaywall(context: "Dynamic Island Live Board")
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: isWatchingLiveActivity ? "stop.fill" : "rectangle.3.group.bubble.left.fill")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(isWatchingLiveActivity ? Color(hex: "FF5A4F") : Color(hex: "5AC8FA"))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.72))
                            .clipShape(Circle())

                        Text(isWatchingLiveActivity ? "Stop Live Board" : "Live Board")
                            .font(.system(size: 17, weight: .black))
                            .tracking(17 * -0.035)

                        Spacer(minLength: 0)

                        HStack(spacing: 5) {
                            if !appState.isProMember {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10, weight: .black))
                            }
                            Text(appState.isProMember ? busCountText(liveBoardServices.count) : "Pro")
                                .font(.system(size: 15, weight: .black))
                                .tracking(15 * -0.025)
                        }
                    }
                    .foregroundColor(isWatchingLiveActivity ? Color(hex: "FF5A4F") : Color(hex: "5AC8FA"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background((isWatchingLiveActivity ? Color(hex: "FF5A4F") : Color(hex: "5AC8FA")).opacity(colorScheme == .dark ? 0.18 : 0.14))
                    .clipShape(Capsule())
                }
                .accessibilityLabel(isWatchingLiveActivity ? "Stop Live Board" : "Start Live Board")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Bus Service Card

    private func busServiceCard(_ service: BusService) -> some View {
        let isPinned = appState.isBusServicePinned(stopCode: busStopCode, serviceNo: service.ServiceNo)

        return PinRevealBusCard(
            isPinned: isPinned,
            onTogglePin: { togglePin(for: service) }
        ) {
            VStack(spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Text(service.ServiceNo)
                        .font(.system(size: 34, weight: .bold))
                        .tracking(34 * -0.035)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Spacer(minLength: 8)

                    if isPinned {
                        pinnedChip
                    }

                    if let badge = catchabilityBadge(for: service) {
                        catchabilityChip(badge)
                    }
                }

                HStack(spacing: 0) {
                    arrivalCard(info: service.NextBus)

                    softDivider

                    arrivalCard(info: service.NextBus2)

                    softDivider

                    arrivalCard(info: service.NextBus3)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .background(timingStripBg)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.03 : 0.035), lineWidth: 1)
                )
            }
            .padding(16)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.075), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.035), radius: 12, x: 0, y: 5)
            .contextMenu {
                Button {
                    togglePin(for: service)
                } label: {
                    Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash.fill" : "pin.fill")
                }
            }
        }
    }

    private var pinnedChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "pin.fill")
                .font(.system(size: 8, weight: .black))
            Text("Pinned")
                .font(.system(size: 11, weight: .bold))
                .tracking(11 * -0.025)
        }
        .foregroundColor(Color(hex: "5AC8FA"))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color(hex: "5AC8FA").opacity(colorScheme == .dark ? 0.18 : 0.12))
        .clipShape(Capsule())
    }

    private var softDivider: some View {
        Rectangle()
            .fill(timingDividerColor)
            .frame(width: 1, height: 40)
            .padding(.horizontal, 4)
    }

    private func stopChip(_ text: String, color: Color, icon: String) -> some View {
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

    private struct CatchabilityBadge {
        let label: String
        let color: Color
        let icon: String
    }

    private func catchabilityBadge(for service: BusService) -> CatchabilityBadge? {
        guard let walkMinutes, let arrival = service.NextBus.arrivalMinutes else { return nil }
        let buffer = arrival - walkMinutes

        if buffer > 5 {
            return CatchabilityBadge(label: CatchabilityLevel.easy.label, color: CatchabilityLevel.easy.color, icon: "checkmark")
        }

        if buffer >= 0 {
            return CatchabilityBadge(label: CatchabilityLevel.tight.label, color: colorScheme == .dark ? Color(hex: "FFB02E") : Color(hex: "F5A623"), icon: "figure.walk")
        }

        if let nextArrival = service.NextBus2.arrivalMinutes, nextArrival - walkMinutes >= 0 {
            return CatchabilityBadge(label: "Next one safer", color: Color(hex: "5AC8FA"), icon: "arrow.right")
        }

        return CatchabilityBadge(label: CatchabilityLevel.missed.label, color: CatchabilityLevel.missed.color, icon: "xmark")
    }

    private func catchabilityChip(_ badge: CatchabilityBadge) -> some View {
        HStack(spacing: 5) {
            Image(systemName: badge.icon)
                .font(.system(size: 9, weight: .black))
            Text(badge.label)
                .font(.system(size: 11, weight: .bold))
                .tracking(11 * -0.025)
        }
        .foregroundColor(badge.color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(badge.color.opacity(colorScheme == .dark ? 0.18 : 0.12))
        .clipShape(Capsule())
    }

    private func arrivalCard(info: BusInfo) -> some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(arrivalMainText(for: info))
                    .font(.system(size: info.arrivalMinutes == nil ? 26 : 28, weight: .bold))
                    .tracking(28 * -0.04)
                    .foregroundColor(arrivalTextColor(for: info))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .contentTransition(.numericText())

                if let min = info.arrivalMinutes, min > 0 {
                    Text("min")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(11 * -0.025)
                        .foregroundColor(arrivalTextColor(for: info).opacity(colorScheme == .dark ? 0.55 : 0.68))
                        .contentTransition(.numericText())
                }
            }
            .animation(.smooth(duration: 0.28), value: info.arrivalMinutes)

            HStack(spacing: 5) {
                if info.BusType == "DD" {
                    Image(systemName: "bus.doubledecker")
                        .font(.system(size: 10, weight: .bold))
                }

                if info.Feature == "WAB" {
                    Image(systemName: "figure.roll")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundColor(timingMetaColor)
            .frame(height: 13)
            .opacity(info.arrivalMinutes == nil ? 0.45 : 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
    }

    private func arrivalMainText(for info: BusInfo) -> String {
        guard let min = info.arrivalMinutes else { return "—" }
        return min <= 0 ? "Arr" : "\(min)"
    }

    private func arrivalTextColor(for info: BusInfo) -> Color {
        guard let min = info.arrivalMinutes else { return .secondary.opacity(0.72) }
        if min <= 1 { return Color(hex: "FF5A4F") }
        if min <= 5 { return colorScheme == .dark ? Color(hex: "FFB02E") : Color(hex: "F5A623") }
        return .primary
    }

    private func busCountText(_ count: Int) -> String {
        count == 1 ? "1 bus" : "\(count) buses"
    }

    // MARK: - States

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.gray)
            Text("Loading arrivals...")
                .font(.system(size: 16, weight: .bold))
                .tracking(16 * -0.025)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 48)
    }

    private var emptyView: some View {
        Text("No bus services at this time.")
            .font(.system(size: 16, weight: .bold))
            .tracking(16 * -0.025)
            .foregroundColor(.secondary)
            .padding(.vertical, 48)
    }

    // MARK: - Data

    private func loadArrivals() async {
        isLoading = true
        do {
            let response = try await LTAService.shared.fetchBusArrivals(busStopCode: busStopCode)
            let sortedServices = sortedServices(response.Services)
            withAnimation(.easeInOut(duration: 0.3)) {
                services = sortedServices
            }
            if LiveActivityManager.shared.activeActivity?.attributes.stopCode == busStopCode {
                let trackedServices = appState.liveBoardServices(for: busStopCode, services: sortedServices)
                await LiveActivityManager.shared.updateStopWatch(services: trackedServices)
                isWatchingLiveActivity = true
                appState.updateLiveBoardTrip(
                    stopCode: busStopCode,
                    stopName: busStopName,
                    services: trackedServices
                )
            }
            await appState.refreshWidgetSnapshot(
                preferredStopCode: busStopCode,
                preferredStopName: busStopName,
                services: sortedServices
            )
        } catch {
            print("Failed to load arrivals: \(error)")
        }
        isLoading = false
    }

    private func toggleLiveActivity() async {
        if isWatchingLiveActivity {
            await LiveActivityManager.shared.endAll()
            appState.cancelLiveBoardTripTracking()
            isWatchingLiveActivity = false
        } else {
            var targetCode = busStopCode
            var targetName = busStopName
            var targetWalkMinutes = walkMinutes
            var targetServices = services

            if let nearest = appState.nearbyStops.first {
                targetCode = nearest.stop.BusStopCode
                targetName = nearest.stop.Description
                targetWalkMinutes = appState.estimatedWalkMinutes(to: nearest)

                do {
                    let response = try await LTAService.shared.fetchBusArrivals(busStopCode: targetCode)
                    targetServices = sortedServices(response.Services)
                } catch {
                    print("Failed to load nearest stop for Live Board: \(error)")
                }
            }

            await LiveActivityManager.shared.startStopWatch(
                stopCode: targetCode,
                stopName: targetName,
                walkMinutes: targetWalkMinutes,
                services: appState.liveBoardServices(for: targetCode, services: targetServices)
            )
            appState.beginLiveBoardTrip(
                stopCode: targetCode,
                stopName: targetName,
                services: targetServices
            )
            await appState.refreshWidgetSnapshot(
                preferredStopCode: targetCode,
                preferredStopName: targetName,
                services: targetServices
            )
            isWatchingLiveActivity = true
        }
    }

    private func sortedServices(_ services: [BusService]) -> [BusService] {
        services.sorted { a, b in
            let aPinned = appState.isBusServicePinned(stopCode: busStopCode, serviceNo: a.ServiceNo)
            let bPinned = appState.isBusServicePinned(stopCode: busStopCode, serviceNo: b.ServiceNo)
            if aPinned != bPinned { return aPinned && !bPinned }

            let numA = Int(a.ServiceNo.filter { $0.isNumber }) ?? 0
            let numB = Int(b.ServiceNo.filter { $0.isNumber }) ?? 0
            if numA != numB { return numA < numB }
            return a.ServiceNo < b.ServiceNo
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { await loadArrivals() }
        }
    }

    private func togglePin(for service: BusService) {
        Haptics.tap(.medium)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            appState.togglePinnedBusService(stopCode: busStopCode, serviceNo: service.ServiceNo)
            services = sortedServices(services)
        }
        if isWatchingLiveActivity {
            Task {
                await LiveActivityManager.shared.updateStopWatch(
                    services: appState.liveBoardServices(for: busStopCode, services: services)
                )
                await appState.refreshWidgetSnapshot(
                    preferredStopCode: busStopCode,
                    preferredStopName: busStopName,
                    services: services
                )
            }
        } else {
            Task {
                await appState.refreshWidgetSnapshot(
                    preferredStopCode: busStopCode,
                    preferredStopName: busStopName,
                    services: services
                )
            }
        }
    }
}

private struct PinRevealBusCard<Content: View>: View {
    let isPinned: Bool
    let onTogglePin: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme
    @State private var offsetX: CGFloat = 0
    @State private var isOpen = false

    private let revealWidth: CGFloat = 112

    var body: some View {
        ZStack(alignment: .leading) {
            pinButton
                .opacity(offsetX > 8 ? 1 : 0)
                .scaleEffect(offsetX > 8 ? 1 : 0.92, anchor: .leading)

            content()
                .offset(x: offsetX)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 24)
                        .onChanged { value in
                            let base = isOpen ? revealWidth : 0
                            let proposed = base + value.translation.width
                            guard value.translation.width > 0 || isOpen else { return }
                            guard abs(value.translation.width) > abs(value.translation.height) * 1.7 else { return }
                            offsetX = min(revealWidth, max(0, proposed))
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) * 1.7 else {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                    offsetX = isOpen ? revealWidth : 0
                                }
                                return
                            }
                            let shouldOpen = offsetX > revealWidth * 0.44 || value.predictedEndTranslation.width > 92
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                isOpen = shouldOpen
                                offsetX = shouldOpen ? revealWidth : 0
                            }
                        }
                )
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: offsetX)
    }

    private var pinButton: some View {
        Button {
            Haptics.tap(.medium)
            onTogglePin()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                isOpen = false
                offsetX = 0
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isPinned ? "pin.slash.fill" : "pin.fill")
                    .font(.system(size: 13, weight: .black))
                Text(isPinned ? "Unpin" : "Pin")
                    .font(.system(size: 15, weight: .black))
                    .tracking(15 * -0.025)
            }
            .foregroundColor(.white)
            .frame(width: 96, height: 44)
            .background(isPinned ? Color(hex: "FF5A4F") : Color(hex: "0A84FF"))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.leading, 6)
        .accessibilityLabel(isPinned ? "Unpin bus" : "Pin bus")
    }
}

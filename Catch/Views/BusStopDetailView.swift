import SwiftUI

struct BusStopDetailView: View {
    let busStopCode: String
    let busStopName: String
    let onBack: () -> Void
    var isMapSheet = false
    var onExpand: () -> Void = {}

    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var services: [BusService] = []
    @State private var isLoading = true
    @State private var arrivalsFailed = false
    @State private var timer: Timer?
    @State private var isWatchingLiveActivity = false
    @State private var isUpdatingLiveActivity = false
    @State private var showLiveBoardError = false
    @State private var draggedPinnedServiceNo: String?
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
            if isMapSheet {
                mapSheetHeader
            } else { header }

            ScrollView {
                LazyVStack(spacing: 16) {
                    liveBoardButton
                    if isLoading && services.isEmpty {
                        loadingView
                    } else if services.isEmpty {
                        emptyView
                    }
                    if arrivalsFailed {
                        Button {
                            Task { await loadArrivals() }
                        } label: {
                            Label("Couldn’t refresh arrivals. Tap to retry.", systemImage: "arrow.clockwise")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(displayServices) { service in
                        busServiceCard(service)
                    }
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.22),
                        value: appState.pinnedBusServiceOrder(for: busStopCode)
                    )
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
        .background(isMapSheet ? Color.clear : bgColor)
        .task {
            if LiveActivityManager.shared.activeActivity?.attributes.stopCode == busStopCode {
                isWatchingLiveActivity = LiveActivityManager.shared.activeActivity?.attributes.stopCode == busStopCode
            }
            await loadArrivals()
            guard !Task.isCancelled else { return }
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            if draggedPinnedServiceNo != nil {
                appState.persistPinnedBusServiceOrder(for: busStopCode)
                draggedPinnedServiceNo = nil
            }
        }
        .alert("Live Board couldn’t start", isPresented: $showLiveBoardError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check that Live Activities are enabled for Catch in iPhone Settings, then try again.")
        }
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
            if isMapSheet, value.translation.height < -40,
               abs(value.translation.height) > abs(value.translation.width) * 1.5 { onExpand() }
        })
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .updating($swipeBackTranslation) { value, state, transaction in
                    transaction.animation = nil
                    guard !isMapSheet, value.startLocation.x <= 36,
                          value.translation.width > 0,
                          value.translation.width > abs(value.translation.height) * 1.8 else { return }
                    state = max(0, value.translation.width)
                }
                .onEnded { value in
                    guard !isMapSheet, value.startLocation.x <= 36,
                          (value.translation.width > 100 || value.predictedEndTranslation.width > 180),
                          value.translation.width > abs(value.translation.height) * 1.8 else { return }
                    Haptics.tap()
                    onBack()
                }
        )
    }

    private var liveBoardButton: some View {
        Button {
            guard let first = displayServices.first else { return }
            Haptics.tap(.medium)
            if appState.isProMember {
                let target = displayServices.first(where: { isTracking($0) }) ?? first
                Task { await toggleLiveActivity(for: target) }
            } else { appState.presentProPaywall(context: "Live Board") }
        } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isWatchingLiveActivity ? "stop.fill" : "rectangle.3.group.bubble.left.fill")
                            .font(.system(size: 13, weight: .black))
                            .contentTransition(.symbolEffect(.replace))
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
                            Text(appState.isProMember ? busCountText(displayServices.count) : "Pro")
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
        .buttonStyle(LiveBoardPressStyle())
        .animation(reduceMotion ? nil : .smooth(duration: 0.10), value: isWatchingLiveActivity)
        .disabled(displayServices.isEmpty || isUpdatingLiveActivity)
        .accessibilityLabel(isWatchingLiveActivity ? "Stop Live Board" : "Start Live Board for the first bus")
    }

    private func liveBoardSymbol(active: Bool) -> some View {
        Image(systemName: active ? "stop.fill" : "rectangle.3.group.bubble.left.fill")
            .font(.system(size: 15, weight: .semibold))
            .contentTransition(.symbolEffect(.replace))
            .foregroundStyle(active ? Color.red : Color(hex: "5AC8FA"))
            .frame(width: 34, height: 34)
            .background((active ? Color.red : Color(hex: "5AC8FA")).opacity(0.15), in: RoundedRectangle(cornerRadius: 13))
            .animation(reduceMotion ? nil : .smooth(duration: 0.16), value: active)
    }

    private var mapSheetHeader: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap(.medium)
                if let savedLocation {
                    appState.removeLocation(id: savedLocation.id)
                    return
                }
                appState.addLocation(SavedLocation(id: UUID().uuidString, name: busStopName, icon: "bus.fill", busStopCode: busStopCode, busStopDescription: busStopName, walkMinutes: walkMinutes ?? 5))
            } label: {
                Image(systemName: savedLocation == nil ? "bookmark" : "bookmark.fill")
                    .font(.system(size: 19, weight: .bold)).frame(width: 44, height: 44)
            }
            .glassEffect(.regular.interactive(), in: Circle())
            .accessibilityLabel(savedLocation == nil ? "Save this bus stop" : "Unpin this bus stop")
            VStack(spacing: 3) {
                Text(busStopName).font(.system(size: 21, weight: .bold)).lineLimit(2).minimumScaleFactor(0.8)
                Text("Bus stop · \(busStopCode)").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            Button(action: onBack) {
                Image(systemName: "xmark").font(.system(size: 18, weight: .bold)).frame(width: 44, height: 44)
            }
            .glassEffect(.regular.interactive(), in: Circle())
            .accessibilityLabel("Close bus stop")
        }
        .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 14)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button(action: {
                    Haptics.tap()
                    onBack()
                }) {
                    Image(systemName: isMapSheet ? "xmark" : "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive())
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(busStopName)
                        .font(.system(size: 21, weight: .bold))
                        .tracking(21 * -0.025)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    HStack(spacing: 8) {
                        Text(busStopCode)
                            .font(.system(size: 14, weight: .bold))
                            .tracking(14 * -0.025)
                            .foregroundColor(.secondary)

                        if savedLocation != nil {
                            stopChip("Pinned", color: Color(hex: "5AC8FA"), icon: "pin.fill")
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

        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Bus Service Card

    private func busServiceCard(_ service: BusService) -> some View {
        let isPinned = appState.isBusServicePinned(stopCode: busStopCode, serviceNo: service.ServiceNo)

        let card = VStack(spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Text(service.ServiceNo)
                        .font(.system(size: 34, weight: .bold))
                        .tracking(34 * -0.035)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Spacer(minLength: 8)

                    if let badge = catchabilityBadge(for: service) {
                        catchabilityChip(badge)
                    }
                    HStack(spacing: 2) {
                        Button { togglePin(for: service) } label: {
                            Image(systemName: isPinned ? "pin.fill" : "pin")
                                .foregroundStyle(isPinned ? Color.blue : Color.secondary)
                                .frame(width: 40, height: 44).contentShape(Rectangle())
                        }
                        .accessibilityLabel("\(isPinned ? "Unpin" : "Pin") bus \(service.ServiceNo)")
                        Button {
                            Haptics.tap(.medium)
                            if appState.isProMember {
                                Task { await toggleLiveActivity(for: service) }
                            } else { appState.presentProPaywall(context: "Live Board") }
                        } label: {
                            liveBoardSymbol(active: isTracking(service))
                                .frame(width: 40, height: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(LiveBoardPressStyle())
                        .disabled(isUpdatingLiveActivity)
                        .accessibilityLabel(isTracking(service) ? "Stop Live Board for bus \(service.ServiceNo)" : "Start Live Board for bus \(service.ServiceNo)")
                    }
                    .font(.system(size: 17, weight: .semibold)).buttonStyle(.plain)

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
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        return Group {
            if isPinned {
                card
                    .accessibilityAction(named: "Move bus earlier") {
                        movePinnedService(service.ServiceNo, by: -1)
                    }
                    .accessibilityAction(named: "Move bus later") {
                        movePinnedService(service.ServiceNo, by: 1)
                    }
                    .onDrag {
                        Haptics.tap(.medium)
                        draggedPinnedServiceNo = service.ServiceNo
                        return NSItemProvider(object: service.ServiceNo as NSString)
                    } preview: {
                        Text(service.ServiceNo)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Color(hex: "1B3B4F"), in: RoundedRectangle(cornerRadius: 18))
                    }
                    .onDrop(
                        of: ["public.text"],
                        delegate: PinnedBusDropDelegate(
                            targetServiceNo: service.ServiceNo,
                            draggedServiceNo: $draggedPinnedServiceNo,
                            move: { source, target in
                                withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) {
                                    appState.previewPinnedBusServiceMove(
                                        stopCode: busStopCode,
                                        serviceNo: source,
                                        over: target
                                    )
                                }
                            },
                            persist: {
                                appState.persistPinnedBusServiceOrder(for: busStopCode)
                            }
                        )
                    )
            } else {
                card
            }
        }
    }

    private func movePinnedService(_ serviceNo: String, by offset: Int) {
        let order = appState.pinnedBusServiceOrder(for: busStopCode)
        guard let index = order.firstIndex(of: serviceNo),
              order.indices.contains(index + offset) else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) {
            appState.previewPinnedBusServiceMove(
                stopCode: busStopCode,
                serviceNo: serviceNo,
                over: order[index + offset]
            )
        }
        appState.persistPinnedBusServiceOrder(for: busStopCode)
        Haptics.tap(.medium)
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
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
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
        Text(arrivalsFailed ? "Arrivals unavailable" : "No bus services at this time.")
            .font(.system(size: 16, weight: .bold))
            .tracking(16 * -0.025)
            .foregroundColor(.secondary)
            .padding(.vertical, 48)
    }

    // MARK: - Data

    private func loadArrivals() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await LTAService.shared.fetchBusArrivals(busStopCode: busStopCode)
            guard !Task.isCancelled else { return }
            arrivalsFailed = false
            let sortedServices = sortedServices(response.Services)
            withAnimation(.easeInOut(duration: 0.3)) {
                services = sortedServices
            }
            if LiveActivityManager.shared.activeActivity?.attributes.stopCode == busStopCode {
                let trackedServices = appState.liveBoardServices(for: busStopCode, services: sortedServices)
                await LiveActivityManager.shared.updateStopWatch(services: trackedServices)
                isWatchingLiveActivity = LiveActivityManager.shared.activeActivity?.attributes.stopCode == busStopCode
                if !isWatchingLiveActivity { appState.cancelLiveBoardTripTracking() }
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
            guard !Task.isCancelled else { return }
            arrivalsFailed = true
            #if DEBUG
            print("Failed to load arrivals: \(error)")
            #endif
        }
    }

    private func isTracking(_ service: BusService) -> Bool {
        isWatchingLiveActivity && LiveActivityManager.shared.activeActivity?.attributes.stopCode == busStopCode &&
            LiveActivityManager.shared.activeActivity?.content.state.services.first?.serviceNo == service.ServiceNo
    }

    private func toggleLiveActivity(for service: BusService) async {
        guard !isUpdatingLiveActivity else { return }
        isUpdatingLiveActivity = true
        defer { isUpdatingLiveActivity = false }
        if isTracking(service) {
            await LiveActivityManager.shared.endAll()
            appState.cancelLiveBoardTripTracking()
            isWatchingLiveActivity = false
        } else {
            let targetCode = busStopCode
            let targetName = busStopName
            let targetWalkMinutes = walkMinutes
            let targetServices = [service]

            await LiveActivityManager.shared.startStopWatch(
                stopCode: targetCode,
                stopName: targetName,
                walkMinutes: targetWalkMinutes,
                services: targetServices,
                roadName: appState.allBusStops.first { $0.BusStopCode == targetCode }?.RoadName
            )
            guard LiveActivityManager.shared.activeActivity?.attributes.stopCode == targetCode else {
                showLiveBoardError = true
                return
            }
            appState.beginLiveBoardTrip(
                stopCode: targetCode,
                stopName: targetName,
                services: targetServices
            )
            isWatchingLiveActivity = LiveActivityManager.shared.activeActivity?.attributes.stopCode == targetCode
            if !isWatchingLiveActivity { appState.cancelLiveBoardTripTracking() }
            Task {
                await appState.refreshWidgetSnapshot(
                    preferredStopCode: targetCode,
                    preferredStopName: targetName,
                    services: targetServices
                )
            }
        }
    }

    private func sortedServices(_ services: [BusService]) -> [BusService] {
        let pinnedOrder = appState.pinnedBusServiceOrder(for: busStopCode)
        let pinnedIndexes = Dictionary(uniqueKeysWithValues: pinnedOrder.enumerated().map { ($1, $0) })
        return services.sorted { a, b in
            let aPinnedIndex = pinnedIndexes[a.ServiceNo]
            let bPinnedIndex = pinnedIndexes[b.ServiceNo]
            let aPinned = aPinnedIndex != nil
            let bPinned = bPinnedIndex != nil
            if aPinned != bPinned { return aPinned && !bPinned }
            if let aPinnedIndex, let bPinnedIndex, aPinnedIndex != bPinnedIndex {
                return aPinnedIndex < bPinnedIndex
            }

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
                isWatchingLiveActivity = LiveActivityManager.shared.activeActivity?.attributes.stopCode == busStopCode
                if !isWatchingLiveActivity { appState.cancelLiveBoardTripTracking() }
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

private struct PinnedBusDropDelegate: DropDelegate {
    let targetServiceNo: String
    @Binding var draggedServiceNo: String?
    let move: (String, String) -> Void
    let persist: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedServiceNo, draggedServiceNo != targetServiceNo else { return }
        move(draggedServiceNo, targetServiceNo)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard draggedServiceNo != nil else { return false }
        persist()
        Haptics.tap(.medium)
        draggedServiceNo = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {}
}

private struct LiveBoardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .smooth(duration: 0.12), value: configuration.isPressed)
    }
}

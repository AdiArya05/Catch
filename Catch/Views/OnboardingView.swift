import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentStep = 0
    @State private var showHomeStopSearch = false
    @State private var showPresetStopSearch = false
    @State private var showCustomLocationSetup = false
    @State private var selectedPresetName = ""
    @State private var selectedPresetIcon = ""
    @State private var showAddedConfirmation = false
    @State private var addedPlaceName = ""
    @State private var addedPlaceColor: Color = .green
    @State private var proOfferEndDate = Date().addingTimeInterval(24 * 60 * 60)
    @State private var onboardingName = ""
    @FocusState private var isNameFieldFocused: Bool
    private var hasEnteredOnboardingName: Bool {
        !onboardingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch currentStep {
            case 0: welcomeScreen
            case 1: nameScreen
            case 2: locationScreen
            case 3: homeStopScreen
            case 4: addPlacesScreen
            case 5: notificationsScreen
            case 6: allSetScreen
            default: EmptyView()
            }

            if showAddedConfirmation {
                addedPlaceColor.opacity(0.15).ignoresSafeArea()
                    .transition(.opacity)
                Color.black.opacity(0.6).ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(addedPlaceColor)

                    Text("\(addedPlaceName) added")
                        .font(.system(size: 20, weight: .bold))
                        .tracking(20 * -0.025)
                        .foregroundColor(.white)

                    Text("You can change this anytime in settings.")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(14 * -0.025)
                        .foregroundColor(.white.opacity(0.5))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showHomeStopSearch) {
            OnboardingStopSearchView(title: "Set home bus stop") { code, description in
                appState.updateLocation(id: "home", name: "Home", busStopCode: code, description: description)
                showHomeStopSearch = false
                addedPlaceName = "Home"
                addedPlaceColor = Color(hex: "5AC8FA")
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showAddedConfirmation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showAddedConfirmation = false
                    }
                    withAnimation(.easeInOut(duration: 0.3)) { currentStep = 4 }
                }
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showPresetStopSearch) {
            OnboardingStopSearchView(title: "Set \(selectedPresetName) bus stop") { code, description in
                let loc = SavedLocation(
                    id: UUID().uuidString,
                    name: selectedPresetName,
                    icon: selectedPresetIcon,
                    colorHex: SavedLocation.defaultColorHex(for: selectedPresetName),
                    busStopCode: code,
                    busStopDescription: description
                )
                appState.addLocation(loc)
                showPresetStopSearch = false
                addedPlaceName = selectedPresetName
                addedPlaceColor = presetColor(for: selectedPresetName)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showAddedConfirmation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showAddedConfirmation = false
                    }
                    withAnimation(.easeInOut(duration: 0.3)) { currentStep = 5 }
                }
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showCustomLocationSetup) {
            AddLocationView(editingId: nil, onDone: {
                showCustomLocationSetup = false
            }, onSave: {
                withAnimation(.easeInOut(duration: 0.3)) { currentStep = 5 }
            }, startWithCustom: true)
            .environmentObject(appState)
            .presentationDetents([.large])
        }
    }

    private func presetColor(for name: String) -> Color {
        switch name.lowercased() {
        case "work": return Color(hex: "FF9F0A")
        case "office": return Color(hex: "BF5AF2")
        case "school": return Color(hex: "30D158")
        case "college": return Color(hex: "00C7BE")
        case "mall": return Color(hex: "FF453A")
        case "gym": return Color(hex: "FFD60A")
        case "restaurant": return Color(hex: "FF2D55")
        case "park": return Color(hex: "30D158")
        case "temple": return Color(hex: "AF52DE")
        default: return Color(hex: "BF5AF2")
        }
    }

    // MARK: - Screen 1: Welcome

    private var welcomeScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Image("CatchIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 82, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color(hex: "5AC8FA").opacity(0.24), radius: 18, x: 0, y: 8)
                .padding(.bottom, 28)

            Text("Welcome to Catch")
                .font(.system(size: 14, weight: .bold))
                .tracking(14 * -0.025)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .padding(.bottom, 12)

            Text("Find your\nbuses faster")
                .font(.system(size: 36, weight: .bold))
                .tracking(36 * -0.025)
                .foregroundColor(.white)
                .padding(.bottom, 16)

            Text("Save the places you usually start from and see nearby bus stops instantly.")
                .font(.system(size: 16, weight: .bold))
                .tracking(16 * -0.025)
                .foregroundColor(.white.opacity(0.5))
                .lineSpacing(4)

            Spacer()

            Button(action: {
                Haptics.tap(.medium)
                withAnimation(.easeInOut(duration: 0.3)) { currentStep = 1 }
            }) {
                Text("Get started")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(16 * -0.025)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Screen 2: Name

    private var nameScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            onboardingHeader(step: 1)

            Spacer()

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 24)

            Text("What should\nwe call you?")
                .font(.system(size: 36, weight: .bold))
                .tracking(36 * -0.025)
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.92)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)
                .contentShape(Rectangle())
                .onTapGesture {
                    isNameFieldFocused = true
                }

            Text("Catch uses this for your home brief and settings. You can change it later.")
                .font(.system(size: 16, weight: .bold))
                .tracking(16 * -0.025)
                .foregroundColor(.white.opacity(0.5))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 28)
                .contentShape(Rectangle())
                .onTapGesture {
                    isNameFieldFocused = true
                }

            TextField("Your name", text: $onboardingName)
                .font(.system(size: 18, weight: .bold))
                .tracking(18 * -0.025)
                .foregroundColor(.white)
                .tint(Color(hex: "5AC8FA"))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isNameFieldFocused)
                .padding(.horizontal, 18)
                .frame(height: 58)
                .background(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer()

            Button(action: {
                guard hasEnteredOnboardingName else { return }
                Haptics.tap(.medium)
                let trimmed = onboardingName.trimmingCharacters(in: .whitespacesAndNewlines)
                appState.saveUserName(trimmed)
                withAnimation(.easeInOut(duration: 0.3)) { currentStep = 2 }
            }) {
                Text("Continue")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(16 * -0.025)
                    .foregroundColor(hasEnteredOnboardingName ? .black : .white.opacity(0.32))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(hasEnteredOnboardingName ? Color.white : Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!hasEnteredOnboardingName)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 28)
        .onAppear {
            if onboardingName.isEmpty {
                onboardingName = appState.userName == "Adi" ? "" : appState.userName
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isNameFieldFocused = true
            }
        }
    }

    // MARK: - Screen 3: Location

    private var locationScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            onboardingHeader(step: 2)

            Spacer()

            Image(systemName: "location.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 24)

            Text("Allow location\naccess")
                .font(.system(size: 36, weight: .bold))
                .tracking(36 * -0.025)
                .foregroundColor(.white)
                .padding(.bottom, 16)

            Text("Catch uses your location to show the closest bus stops around you.")
                .font(.system(size: 16, weight: .bold))
                .tracking(16 * -0.025)
                .foregroundColor(.white.opacity(0.5))
                .lineSpacing(4)

            Spacer()

            Button(action: {
                Haptics.tap(.medium)
                appState.locationManager.requestPermission()
                withAnimation(.easeInOut(duration: 0.3)) { currentStep = 3 }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Allow location")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(16 * -0.025)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            skipButton(text: "Maybe later") {
                withAnimation(.easeInOut(duration: 0.3)) { currentStep = 3 }
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Screen 4: Home Stop

    private var homeStopScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            onboardingHeader(step: 3)

            Spacer()

            Image(systemName: "house.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 24)

            Text("Set your\nhome stop")
                .font(.system(size: 36, weight: .bold))
                .tracking(36 * -0.025)
                .foregroundColor(.white)
                .padding(.bottom, 16)

            Text("Choose the bus stop you usually take when leaving from home.")
                .font(.system(size: 16, weight: .bold))
                .tracking(16 * -0.025)
                .foregroundColor(.white.opacity(0.5))
                .lineSpacing(4)

            Spacer()

            Button(action: {
                Haptics.tap(.medium)
                showHomeStopSearch = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                    Text("Search home bus stop")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(16 * -0.025)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            skipButton(text: "Skip for now") {
                withAnimation(.easeInOut(duration: 0.3)) { currentStep = 4 }
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Screen 5: Add Places

    private var addPlacesScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            onboardingHeader(step: 4)

            Spacer()

            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 24)

            Text("Add your\ndaily places")
                .font(.system(size: 36, weight: .bold))
                .tracking(36 * -0.025)
                .foregroundColor(.white)
                .padding(.bottom, 16)

            Text("Save places like work, school, camp, or gym so they appear on your home screen.")
                .font(.system(size: 16, weight: .bold))
                .tracking(16 * -0.025)
                .foregroundColor(.white.opacity(0.5))
                .lineSpacing(4)
                .padding(.bottom, 28)

            presetPills

            Spacer()

            skipButton(text: "Maybe later") {
                withAnimation(.easeInOut(duration: 0.3)) { currentStep = 5 }
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 28)
    }

    private var presetPills: some View {
        let presets: [(String, String, Color, Color)] = [
            ("Work", "briefcase.fill", Color(hex: "4A3020"), Color(hex: "FF9F0A")),
            ("Office", "building.2.fill", Color(hex: "3A2A4A"), Color(hex: "BF5AF2")),
            ("School", "book.fill", Color(hex: "1C3A20"), Color(hex: "30D158")),
            ("College", "graduationcap.fill", Color(hex: "163C3A"), Color(hex: "00C7BE")),
            ("Mall", "bag.fill", Color(hex: "4A2522"), Color(hex: "FF453A")),
            ("Gym", "dumbbell.fill", Color(hex: "3A3A1C"), Color(hex: "FFD60A")),
            ("Restaurant", "fork.knife", Color(hex: "4A1F2A"), Color(hex: "FF2D55")),
            ("Park", "leaf.fill", Color(hex: "1C3A20"), Color(hex: "30D158")),
            ("Temple", "building.columns.fill", Color(hex: "351F42"), Color(hex: "AF52DE")),
            ("Custom", "mappin", Color(hex: "2A2A2A"), Color(hex: "AAAAAA")),
        ]

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    presetPill(name: presets[i].0, icon: presets[i].1, bg: presets[i].2, fg: presets[i].3)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                ForEach(3..<6, id: \.self) { i in
                    presetPill(name: presets[i].0, icon: presets[i].1, bg: presets[i].2, fg: presets[i].3)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                ForEach(6..<9, id: \.self) { i in
                    presetPill(name: presets[i].0, icon: presets[i].1, bg: presets[i].2, fg: presets[i].3)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                presetPill(name: presets[9].0, icon: presets[9].1, bg: presets[9].2, fg: presets[9].3)
                Spacer()
            }
        }
    }

    private func presetPill(name: String, icon: String, bg: Color, fg: Color) -> some View {
        Button(action: {
            Haptics.tap(.medium)
            if name == "Custom" {
                showCustomLocationSetup = true
                return
            }
            selectedPresetName = name
            selectedPresetIcon = icon
            showPresetStopSearch = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(name)
                    .font(.system(size: 13, weight: .bold))
                    .tracking(13 * -0.025)
            }
            .foregroundColor(fg)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bg)
            .clipShape(Capsule())
        }
    }

    // MARK: - Screen 6: Notifications

    private var notificationsScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            onboardingHeader(step: 5)

            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 24)

            Text("Stay in\nthe loop")
                .font(.system(size: 36, weight: .bold))
                .tracking(36 * -0.025)
                .foregroundColor(.white)
                .padding(.bottom, 16)

            Text("Get notified when it's time to leave so you never miss your bus.")
                .font(.system(size: 16, weight: .bold))
                .tracking(16 * -0.025)
                .foregroundColor(.white.opacity(0.5))
                .lineSpacing(4)

            Spacer()

            Button(action: {
                Haptics.tap(.medium)
                appState.requestNotificationPermission { granted in
                    DispatchQueue.main.async {
                        appState.saveNotificationPermissionResult(granted)
                        withAnimation(.easeInOut(duration: 0.3)) { currentStep = 6 }
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Allow notifications")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(16 * -0.025)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            skipButton(text: "Maybe later") {
                withAnimation(.easeInOut(duration: 0.3)) { currentStep = 6 }
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Screen 7: All Set

    private var allSetScreen: some View {
        ProPaywallView(
            showsCloseButton: true,
            onClose: finishOnboarding,
            onUnlock: finishOnboarding
        )
        .environmentObject(appState)
    }

    private func finishOnboarding() {
        let status = appState.locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            appState.locationManager.startUpdating()
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            appState.completeOnboarding()
        }
    }

    private var onboardingOfferFeatures: some View {
        let features: [(String, String, Color)] = [
            ("Smart alerts", "bell.badge.fill", Color(hex: "FF9F0A")),
            ("Live Board", "rectangle.3.group.bubble.left.fill", Color(hex: "5AC8FA")),
            ("Unlimited saved stops", "bookmark.fill", Color(hex: "4CD964")),
            ("All icons", "app.badge.fill", Color(hex: "BF5AF2"))
        ]

        return VStack(spacing: 2) {
            ForEach(features, id: \.0) { feature in
                HStack(spacing: 15) {
                    Image(systemName: feature.1)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(feature.2)
                        .frame(width: 32, height: 32)

                    Text(feature.0)
                        .font(.system(size: 19, weight: .black))
                        .tracking(19 * -0.03)
                        .foregroundStyle(.white.opacity(0.94))

                    Spacer()
                }
                .frame(height: 42)
            }
        }
        .frame(maxWidth: 268)
    }

    // MARK: - Shared Components

    private func onboardingHeader(step: Int) -> some View {
        HStack {
            Button(action: {
                Haptics.tap()
                withAnimation(.easeInOut(duration: 0.3)) {
                    if currentStep > 0 { currentStep -= 1 }
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    Circle()
                        .fill(i <= currentStep ? Color.white : Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.top, 16)
    }

    private func skipButton(text: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            Text(text)
                .font(.system(size: 14, weight: .bold))
                .tracking(14 * -0.025)
                .foregroundColor(.white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        }
    }

    private var onboardingOfferBackground: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { geo in
                ZStack {
                    Color.black.ignoresSafeArea()

                    LinearGradient(
                        colors: [
                            Color.black,
                            Color(hex: "090A0C"),
                            Color(hex: "1B1B1D").opacity(0.88),
                            Color.black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color(hex: "5AC8FA").opacity(0.08),
                            .clear
                        ],
                        center: UnitPoint(x: 0.50, y: 0.74),
                        startRadius: 12,
                        endRadius: 280
                    )
                    .blendMode(.screen)

                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.10), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 1.35, height: 120)
                    .rotationEffect(.degrees(-14))
                    .offset(x: CGFloat(sin(time * 0.20)) * 90, y: 120)
                    .blur(radius: 20)
                    .blendMode(.screen)

                    Canvas { context, size in
                        for index in 0..<112 {
                            let seed = Double(index)
                            let baseX = Double((index * 41) % 1000) / 1000
                            let baseY = Double((index * 67) % 1000) / 1000
                            let driftX = sin(time * 0.20 + seed) * 11
                            let driftY = cos(time * 0.18 + seed * 0.8) * 9
                            let pulse = 0.08 + 0.24 * abs(sin(time * 0.88 + seed * 0.73))
                            let dot = 0.85 + Double(index % 4) * 0.36
                            let rect = CGRect(
                                x: baseX * size.width + driftX,
                                y: size.height * (0.18 + baseY * 0.70) + driftY,
                                width: dot,
                                height: dot
                            )

                            context.opacity = pulse
                            context.fill(Path(ellipseIn: rect), with: .color(.white))
                        }
                    }
                    .blendMode(.screen)
                    .blur(radius: 0.15)
                    .ignoresSafeArea()
                }
            }
        }
    }

    private func offerCountdownText(now: Date) -> String {
        let remaining = max(0, Int(proOfferEndDate.timeIntervalSince(now)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Onboarding Bus Stop Search

struct OnboardingStopSearchView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""

    let title: String
    let onSelect: (String, String) -> Void

    private var searchResults: [BusStop] {
        guard searchQuery.count >= 2 else { return [] }
        return appState.searchBusStops(query: searchQuery)
    }

    private var bgColor: Color { colorScheme == .dark ? Color(hex: "292929") : Color(hex: "F5F5F5") }
    private var cardBg: Color { colorScheme == .dark ? Color(hex: "1E1E1E") : Color.white }

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                        TextField("Search bus stop...", text: $searchQuery)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .autocorrectionDisabled()
                    }
                    .padding(14)
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if !searchResults.isEmpty {
                                ForEach(searchResults) { stop in
                                    Button(action: {
                                        onSelect(stop.BusStopCode, stop.Description)
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(stop.Description)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .tracking(16 * -0.025)
                                                    .foregroundColor(.primary)
                                                Text("\(stop.BusStopCode) · \(stop.RoadName)")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .tracking(13 * -0.025)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                    }
                                }
                            } else if searchQuery.count < 2 && !appState.nearbyStops.isEmpty {
                                Text("Nearby stops")
                                    .font(.system(size: 13, weight: .bold))
                                    .tracking(13 * -0.025)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)

                                ForEach(appState.nearbyStops) { nearby in
                                    Button(action: {
                                        onSelect(nearby.stop.BusStopCode, nearby.stop.Description)
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(nearby.stop.Description)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .tracking(16 * -0.025)
                                                    .foregroundColor(.primary)
                                                Text("\(nearby.stop.BusStopCode) · \(nearby.stop.RoadName)")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .tracking(13 * -0.025)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Text(nearby.distanceText)
                                                .font(.system(size: 14, weight: .bold))
                                                .tracking(14 * -0.025)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GlassCircleIconButton(
                        systemName: "xmark",
                        foregroundColor: .secondary
                    ) {
                        dismiss()
                    }
                }
            }
        }
    }
}

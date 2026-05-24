import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentStep = 0
    @State private var showHomeStopSearch = false
    @State private var showPresetStopSearch = false
    @State private var selectedPresetName = ""
    @State private var selectedPresetIcon = ""
    @State private var showAddedConfirmation = false
    @State private var addedPlaceName = ""
    @State private var addedPlaceColor: Color = .green
    @State private var proOfferEndDate = Date().addingTimeInterval(24 * 60 * 60)
    @State private var onboardingName = ""
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
    }

    private func presetColor(for name: String) -> Color {
        switch name.lowercased() {
        case "work": return Color(hex: "F5A623")
        case "office": return Color(hex: "BF5AF2")
        case "school": return Color(hex: "4CD964")
        case "college": return Color(hex: "64D2FF")
        case "mall": return Color(hex: "FF6B6B")
        case "gym": return Color(hex: "FFD60A")
        case "restaurant": return Color(hex: "FF9F0A")
        case "park": return Color(hex: "30D158")
        case "temple": return Color(hex: "FFD60A")
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
                .padding(.bottom, 16)

            Text("Catch uses this for your home brief and settings. You can change it later.")
                .font(.system(size: 16, weight: .bold))
                .tracking(16 * -0.025)
                .foregroundColor(.white.opacity(0.5))
                .lineSpacing(4)
                .padding(.bottom, 28)

            TextField("Your name", text: $onboardingName)
                .font(.system(size: 18, weight: .bold))
                .tracking(18 * -0.025)
                .foregroundColor(.white)
                .tint(Color(hex: "5AC8FA"))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
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
            ("Work", "briefcase.fill", Color(hex: "4A3520"), Color(hex: "F5A623")),
            ("Office", "building.2.fill", Color(hex: "3A2A4A"), Color(hex: "BF5AF2")),
            ("School", "book.fill", Color(hex: "2A3A2A"), Color(hex: "4CD964")),
            ("College", "graduationcap.fill", Color(hex: "1C3A3A"), Color(hex: "64D2FF")),
            ("Mall", "bag.fill", Color(hex: "4A2A2A"), Color(hex: "FF6B6B")),
            ("Gym", "dumbbell.fill", Color(hex: "3A3A1C"), Color(hex: "FFD60A")),
            ("Restaurant", "fork.knife", Color(hex: "4A3020"), Color(hex: "FF9F0A")),
            ("Park", "leaf.fill", Color(hex: "1C3A20"), Color(hex: "30D158")),
            ("Temple", "building.columns.fill", Color(hex: "4A3A1C"), Color(hex: "FFD60A")),
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
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                    DispatchQueue.main.async {
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
        ZStack {
            onboardingOfferBackground

            VStack {
                HStack {
                    Spacer()

                    GlassCircleIconButton(
                        systemName: "xmark",
                        size: 52,
                        iconSize: 20,
                        foregroundColor: .white.opacity(0.64)
                    ) {
                        appState.locationManager.requestPermission()
                        appState.locationManager.startUpdating()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState.completeOnboarding()
                        }
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .zIndex(2)

            VStack(spacing: 0) {
                Spacer(minLength: 42)

                Text("-50")
                    .font(.system(size: 122, weight: .black))
                    .tracking(122 * -0.064)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "007AFF"), Color(hex: "21A6FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .topTrailing) {
                        Text("%")
                            .font(.system(size: 34, weight: .black))
                            .tracking(34 * -0.04)
                            .foregroundStyle(Color(hex: "1F9BFF"))
                            .offset(x: 46, y: 25)
                    }
                    .padding(.trailing, 42)

                Text("Limited time offer")
                    .font(.system(size: 16, weight: .black))
                    .tracking(16 * -0.025)
                    .foregroundStyle(.white)
                    .padding(.top, -2)

                Text("Unlock Dynamic Island, smart alerts,\nroute memory, app icons and more.")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(13 * -0.025)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.32))
                    .lineSpacing(1)
                    .padding(.top, 6)

                onboardingOfferFeatures
                    .padding(.top, 22)

                VStack(spacing: 6) {
                    Text("Expires in")
                        .font(.system(size: 12, weight: .black))
                        .tracking(12 * -0.025)
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        Image(systemName: "laurel.leading")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white.opacity(0.19))

                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(offerCountdownText(now: context.date))
                                .font(.system(size: 32, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .contentTransition(.numericText(countsDown: true))
                                .animation(.smooth(duration: 0.28), value: offerCountdownText(now: context.date))
                                .shadow(color: .white.opacity(0.26), radius: 12, x: 0, y: 0)
                        }

                        Image(systemName: "laurel.trailing")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white.opacity(0.19))
                    }
                }
                .padding(.top, 22)

                Spacer(minLength: 14)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Annual")
                            .font(.system(size: 14, weight: .black))
                            .tracking(14 * -0.025)
                            .foregroundStyle(.white)
                        Text("One year with Catch")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(12 * -0.025)
                            .foregroundStyle(.white.opacity(0.34))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("$18.99")
                            .font(.system(size: 14, weight: .black))
                            .tracking(14 * -0.025)
                            .foregroundStyle(.white)
                        Text("$42.99")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(11 * -0.025)
                            .strikethrough()
                            .foregroundStyle(.white.opacity(0.28))
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: 300)
                .frame(height: 58)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.13), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.white.opacity(0.035), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

                Button(action: {
                    Haptics.tap(.medium)
                    appState.joinPro()
                    appState.locationManager.requestPermission()
                    appState.locationManager.startUpdating()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appState.completeOnboarding()
                    }
                }) {
                    Text("Claim limited offer")
                        .font(.system(size: 16, weight: .black))
                        .tracking(16 * -0.025)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .background(Color.white.opacity(0.92))
                .glassEffect(.regular.interactive())
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .buttonStyle(.plain)
                .frame(maxWidth: 300)
                .padding(.top, 12)

                Button(action: {
                    Haptics.tap()
                    appState.locationManager.requestPermission()
                    appState.locationManager.startUpdating()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appState.completeOnboarding()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Restore purchase")
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .tracking(11 * -0.025)
                    .foregroundStyle(.white.opacity(0.28))
                    .padding(.top, 10)
                }

                Text("Cancel any time")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(10 * -0.025)
                    .foregroundStyle(.white.opacity(0.20))
                    .padding(.top, 4)
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 26)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var onboardingOfferFeatures: some View {
        let features: [(String, String, Color)] = [
            ("Smart alerts", "bell.badge.fill", Color(hex: "FF9F0A")),
            ("Live Board", "rectangle.3.group.bubble.left.fill", Color(hex: "5AC8FA")),
            ("Route memory", "brain.head.profile", Color(hex: "FFD60A")),
            ("Saved places", "mappin.circle.fill", Color(hex: "4CD964")),
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

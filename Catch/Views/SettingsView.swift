import SwiftUI
import UIKit

struct SettingsView: View {
    var onDismiss: (() -> Void)?
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSavedPlaces = false
    @State private var showEditName = false
    @State private var editedName = ""
    @State private var showSettingsProPaywall = false
    @State private var selectedAppIconName: String? = UIApplication.shared.alternateIconName
    @State private var appIconErrorMessage: String?

    private var bgColor: Color { colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F5") }
    private var dotColor: Color { colorScheme == .dark ? Color(hex: "3A3A3A") : Color(hex: "CCCCCC") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    settingsHeader
                        .padding(.bottom, 24)

                    // Display name
                    Button(action: {
                        editedName = appState.userName
                        showEditName = true
                    }) {
                        row(icon: "person.crop.square.fill", iconColor: Color(hex: "8E8E93"), label: "Display name") {
                            HStack(spacing: 12) {
                                Text(appState.userName)
                                    .font(.system(size: 19, weight: .semibold))
                                    .tracking(19 * -0.025)
                                    .foregroundColor(Color(hex: "8E8E93"))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundColor(Color(hex: "555555"))
                            }
                        }
                    }
                    dotLine

                    // Saved Places
                    Button(action: { showSavedPlaces = true }) {
                        row(icon: "mappin.circle.fill", iconColor: Color(hex: "5AC8FA"), label: "Saved Places") {
                            HStack(spacing: 12) {
                                Text("\(appState.savedLocations.count)")
                                    .font(.system(size: 19, weight: .semibold))
                                    .tracking(19 * -0.025)
                                    .foregroundColor(Color(hex: "8E8E93"))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundColor(Color(hex: "555555"))
                            }
                        }
                    }
                    dotLine

                    // App Icon
                    if appState.isProMember {
                        NavigationLink {
                            AppIconPickerView(
                                selectedIconName: $selectedAppIconName,
                                errorMessage: $appIconErrorMessage,
                                onSelect: { iconName in
                                    appIconErrorMessage = nil
                                    changeAppIcon(to: iconName)
                                }
                            )
                            .preferredColorScheme(appState.isDarkMode ? .dark : .light)
                            .environmentObject(appState)
                        } label: {
                            appIconRow
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            selectedAppIconName = UIApplication.shared.alternateIconName
                            appIconErrorMessage = nil
                        })
                    } else {
                        Button(action: {
                            presentSettingsProPaywall(context: "All app icons")
                        }) {
                            appIconRow
                        }
                    }
                    dotLine

                    // Can I Catch It?
                    row(icon: "figure.walk", iconColor: Color(hex: "5AC8FA"), label: "Can I Catch It?", isPro: true) {
                        Toggle("", isOn: Binding(
                            get: { appState.isProMember && appState.isCatchItEnabled },
                            set: { newValue in
                                guard appState.isProMember else {
                                    presentSettingsProPaywall(context: "Can I Catch It?")
                                    return
                                }
                                appState.saveCatchItEnabled(newValue)
                            }
                        ))
                        .labelsHidden()
                        .tint(Color(hex: "34C759"))
                    }
                    dotLine

                    // Leave-Now Alerts
                    row(icon: "bell.badge.fill", iconColor: Color(hex: "FF9F0A"), label: "Leave-Now Alerts", isPro: true) {
                        Toggle("", isOn: Binding(
                            get: { appState.isProMember && appState.isLeaveNowAlertsEnabled },
                            set: { newValue in
                                guard appState.isProMember else {
                                    presentSettingsProPaywall(context: "Smart leave-now alerts")
                                    return
                                }
                                appState.saveLeaveNowAlerts(newValue)
                            }
                        ))
                        .labelsHidden()
                        .tint(Color(hex: "34C759"))
                    }
                    dotLine

                    // Smart Suggestions
                    row(icon: "sparkles", iconColor: Color(hex: "FFD60A"), label: "Smart Suggestions", isPro: true) {
                        Toggle("", isOn: Binding(
                            get: { appState.isProMember && appState.isSmartSuggestionsEnabled },
                            set: { newValue in
                                guard appState.isProMember else {
                                    presentSettingsProPaywall(context: "Route memory")
                                    return
                                }
                                appState.saveSmartSuggestions(newValue)
                            }
                        ))
                        .labelsHidden()
                        .tint(Color(hex: "34C759"))
                    }
                    dotLine

                    // Notifications
                    row(icon: "bell.fill", iconColor: Color(hex: "FF453A"), label: "Notifications") {
                        Toggle("", isOn: .constant(true))
                            .labelsHidden()
                            .tint(Color(hex: "34C759"))
                    }
                    dotLine

                    // Appearance
                    row(icon: "moon.fill", iconColor: Color(hex: "BF5AF2"), label: "Appearance") {
                        HStack(spacing: 14) {
                            Text(appState.isDarkMode ? "Dark" : "Light")
                                .font(.system(size: 19, weight: .semibold))
                                .tracking(19 * -0.025)
                                .foregroundColor(Color(hex: "8E8E93"))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Toggle("", isOn: Binding(
                                get: { appState.isDarkMode },
                                set: { appState.saveDarkMode($0) }
                            ))
                            .labelsHidden()
                            .tint(Color(hex: "34C759"))
                        }
                    }
                    dotLine

                    // Terms of Service
                    row(icon: "doc.text.fill", iconColor: Color(hex: "8E8E93"), label: "Terms of Service") {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(Color(hex: "555555"))
                    }
                    dotLine

                    // Privacy Policy
                    row(icon: "lock.shield.fill", iconColor: Color(hex: "8E8E93"), label: "Privacy Policy") {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(Color(hex: "555555"))
                    }

                    // Footer
                    VStack(spacing: 8) {
                        Image("CatchIcon")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )

                        Text("Catch")
                            .font(.system(size: 19, weight: .bold))
                            .tracking(19 * -0.025)
                            .foregroundColor(Color(hex: "555555"))
                        Text("Made by Aditya Arya")
                            .font(.system(size: 15, weight: .medium))
                            .tracking(15 * -0.025)
                            .foregroundColor(Color(hex: "444444"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 56)
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 34)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
            .background(bgColor)
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(appState.isDarkMode ? .dark : .light)
        .alert("Display Name", isPresented: $showEditName) {
            TextField("Name", text: $editedName)
            Button("Save") { appState.saveUserName(editedName) }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showSavedPlaces) {
            SavedPlacesListView()
        }
        .sheet(isPresented: $showSettingsProPaywall) {
            ProPaywallView()
                .environmentObject(appState)
                .presentationDetents([.large])
        }
    }

    private var settingsHeader: some View {
        ZStack {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))
                .tracking(24 * -0.025)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()

                GlassCircleIconButton(
                    systemName: "xmark",
                    foregroundColor: .secondary
                ) {
                    if let onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .frame(height: 64)
    }

    private func presentSettingsProPaywall(context: String) {
        Haptics.tap(.medium)
        appState.proPaywallContext = context
        showSettingsProPaywall = true
    }

    // MARK: - Row

    private var appIconRow: some View {
        row(icon: "app.badge.fill", iconColor: Color(hex: "5AC8FA"), label: "App Icon", isPro: true) {
            HStack(spacing: 12) {
                Image(appIconOption(for: selectedAppIconName).previewAsset)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Image(systemName: "chevron.right")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(Color(hex: "555555"))
            }
        }
    }

    private func row<Trailing: View>(icon: String, iconColor: Color, label: String, isPro: Bool = false, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 22) {
            Image(systemName: icon)
                .font(.system(size: 23, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)

            HStack(spacing: 10) {
                Text(label)
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(20 * -0.025)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                if isPro {
                    proMark
                }
            }
            .layoutPriority(1)

            Spacer()

            trailing()
        }
        .frame(minHeight: 76)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }

    private var proMark: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(Color(hex: "0A84FF"))
            .frame(width: 24, height: 24)
            .background(Color(hex: "0A84FF").opacity(0.12), in: Circle())
            .accessibilityLabel("Pro feature")
    }

    // MARK: - Dotted Line

    private var dotLine: some View {
        GeometryReader { geo in
            let dotSize: CGFloat = 2
            let spacing: CGFloat = 7
            let count = Int(geo.size.width / (dotSize + spacing))
            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle()
                        .fill(dotColor)
                        .frame(width: dotSize, height: dotSize)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 2)
    }

    private func changeAppIcon(to iconName: String?) {
        guard UIApplication.shared.alternateIconName != iconName else {
            selectedAppIconName = iconName
            appIconErrorMessage = nil
            return
        }

        guard UIApplication.shared.supportsAlternateIcons else {
            appIconErrorMessage = "Alternate icons are not available on this device."
            return
        }

        UIApplication.shared.setAlternateIconName(iconName) { error in
            DispatchQueue.main.async {
                if let error {
                    #if targetEnvironment(simulator)
                    let nsError = error as NSError
                    if nsError.domain == NSPOSIXErrorDomain && nsError.code == 35 {
                        appIconErrorMessage = "iOS 26 Simulator cannot switch app icons. This works on iPhone."
                    } else {
                        appIconErrorMessage = error.localizedDescription
                    }
                    #else
                    appIconErrorMessage = error.localizedDescription
                    #endif
                } else {
                    selectedAppIconName = iconName
                    appIconErrorMessage = nil
                }
            }
        }
    }
}

// MARK: - App Icon Picker

private struct AppIconOption: Identifiable {
    let id: String
    let title: String
    let iconName: String?
    let previewAsset: String
}

private let catchAppIconOptions: [AppIconOption] = [
    AppIconOption(id: "default", title: "Default", iconName: nil, previewAsset: "CatchIcon"),
    AppIconOption(id: "dark", title: "Dark", iconName: "CatchMonochrome", previewAsset: "CatchIconMonochrome"),
    AppIconOption(id: "light", title: "Light", iconName: "CatchWhiteBlack", previewAsset: "CatchIconWhiteBlack"),
    AppIconOption(id: "coral", title: "Coral", iconName: "CatchCoral", previewAsset: "CatchIconCoral"),
    AppIconOption(id: "chromatic", title: "Chromatic", iconName: "CatchChromatic", previewAsset: "CatchIconChromatic"),
    AppIconOption(id: "blue", title: "Blue", iconName: "CatchBlueVintage", previewAsset: "CatchIconBlueVintage"),
    AppIconOption(id: "orange", title: "Orange", iconName: "CatchOrangeVintage", previewAsset: "CatchIconOrangeVintage"),
    AppIconOption(id: "disco", title: "Disco", iconName: "CatchDiscomorphism", previewAsset: "CatchIconDiscomorphism")
]

private func appIconOption(for iconName: String?) -> AppIconOption {
    catchAppIconOptions.first { $0.iconName == iconName } ?? catchAppIconOptions[0]
}

private struct AppIconPickerView: View {
    @Binding var selectedIconName: String?
    @Binding var errorMessage: String?
    let onSelect: (String?) -> Void
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var bgColor: Color { colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F5") }
    private var cardBg: Color { colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 14)], spacing: 14) {
                    ForEach(catchAppIconOptions) { option in
                        Button {
                            if option.iconName == nil || appState.isProMember {
                                onSelect(option.iconName)
                            } else {
                                appState.presentProPaywall(context: "All app icons")
                            }
                        } label: {
                            VStack(spacing: 12) {
                                Image(option.previewAsset)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.10), radius: 12, x: 0, y: 6)

                                VStack(spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(option.title)
                                            .font(.system(size: 15, weight: .bold))
                                            .tracking(15 * -0.025)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.72)

                                        if selectedIconName == option.iconName {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(Color(hex: "5AC8FA"))
                                        } else if option.iconName != nil && !appState.isProMember {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(Color(hex: "8E8E93"))
                                        }
                                    }

                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(selectedIconName == option.iconName ? Color(hex: "5AC8FA").opacity(0.7) : Color.primary.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)

                if let errorMessage {
                    let isSimulatorNote = errorMessage.contains("Simulator")
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSimulatorNote ? Color(hex: "8E8E93") : Color(hex: "FF5A4F"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                }
            }
            .background(bgColor)
            .navigationTitle("App Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .bold))
                }
            }
        }
    }
}

// MARK: - Saved Places List

struct SavedPlacesListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAddLocation = false
    @State private var editingLocationId: String?

    private var bgColor: Color { colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F5") }
    private var dotColor: Color { colorScheme == .dark ? Color(hex: "3A3A3A") : Color(hex: "CCCCCC") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(appState.savedLocations.enumerated()), id: \.element.id) { index, loc in
                        SwipeDeleteSavedPlaceRow(
                            location: loc,
                            iconColor: iconColor(for: loc),
                            canDelete: loc.id != "home",
                            onTap: {
                                editingLocationId = loc.id
                                showAddLocation = true
                            },
                            onDelete: {
                                Haptics.tap(.medium)
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                    appState.removeLocation(id: loc.id)
                                }
                            }
                        )

                        if index < appState.savedLocations.count - 1 {
                            GeometryReader { geo in
                                let dotSize: CGFloat = 2
                                let spacing: CGFloat = 5
                                let count = Int(geo.size.width / (dotSize + spacing))
                                HStack(spacing: spacing) {
                                    ForEach(0..<count, id: \.self) { _ in
                                        Circle()
                                            .fill(dotColor)
                                            .frame(width: dotSize, height: dotSize)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .frame(height: 2)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(bgColor)
            .navigationTitle("Saved Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        editingLocationId = nil
                        showAddLocation = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .preferredColorScheme(appState.isDarkMode ? .dark : .light)
        .sheet(isPresented: $showAddLocation) {
            AddLocationView(editingId: editingLocationId) {
                showAddLocation = false
                editingLocationId = nil
            }
        }
    }

    private func iconColor(for loc: SavedLocation) -> Color {
        Color(hex: loc.colorHex)
    }
}

private struct SwipeDeleteSavedPlaceRow: View {
    let location: SavedLocation
    let iconColor: Color
    let canDelete: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var offsetX: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            if canDelete {
                Button(action: onDelete) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Delete")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 104, height: 64)
                    .background(Color(hex: "FF453A"))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button(action: onTap) {
                HStack(spacing: 14) {
                    Image(systemName: location.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                        .frame(width: 32, height: 32)
                        .background(iconColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(location.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        if !location.busStopDescription.isEmpty {
                            Text(location.busStopDescription)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Text("\(location.walkMinutes) min")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "8E8E93"))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "555555"))
                }
                .padding(.vertical, 16)
                .background(colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F5"))
                .offset(x: offsetX)
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            guard canDelete else { return }
                            offsetX = min(0, max(-112, value.translation.width))
                        }
                        .onEnded { value in
                            guard canDelete else { return }
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                offsetX = value.translation.width < -56 ? -112 : 0
                            }
                        }
                )
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 64)
    }
}

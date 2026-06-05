import SwiftUI

// MARK: - Preset Location Category

struct LocationPreset: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let colorHex: String
    let bgColor: Color
    let fgColor: Color
}

private let locationPresets: [LocationPreset] = [
    LocationPreset(name: "Home", icon: "house.fill", colorHex: "0A84FF", bgColor: Color(hex: "102A4A"), fgColor: Color(hex: "0A84FF")),
    LocationPreset(name: "Work", icon: "briefcase.fill", colorHex: "FF9F0A", bgColor: Color(hex: "4A3020"), fgColor: Color(hex: "FF9F0A")),
    LocationPreset(name: "Office", icon: "building.2.fill", colorHex: "BF5AF2", bgColor: Color(hex: "3A2A4A"), fgColor: Color(hex: "BF5AF2")),
    LocationPreset(name: "School", icon: "book.fill", colorHex: "4CD964", bgColor: Color(hex: "2A3A2A"), fgColor: Color(hex: "4CD964")),
    LocationPreset(name: "College", icon: "graduationcap.fill", colorHex: "00C7BE", bgColor: Color(hex: "163C3A"), fgColor: Color(hex: "00C7BE")),
    LocationPreset(name: "Mall", icon: "bag.fill", colorHex: "FF453A", bgColor: Color(hex: "4A2522"), fgColor: Color(hex: "FF453A")),
    LocationPreset(name: "Gym", icon: "dumbbell.fill", colorHex: "FFD60A", bgColor: Color(hex: "3A3A1C"), fgColor: Color(hex: "FFD60A")),
    LocationPreset(name: "Restaurant", icon: "fork.knife", colorHex: "FF2D55", bgColor: Color(hex: "4A1F2A"), fgColor: Color(hex: "FF2D55")),
    LocationPreset(name: "Hospital", icon: "cross.fill", colorHex: "FF453A", bgColor: Color(hex: "3A1C1C"), fgColor: Color(hex: "FF453A")),
    LocationPreset(name: "Park", icon: "leaf.fill", colorHex: "30D158", bgColor: Color(hex: "1C3A20"), fgColor: Color(hex: "30D158")),
    LocationPreset(name: "Temple", icon: "building.columns.fill", colorHex: "AF52DE", bgColor: Color(hex: "351F42"), fgColor: Color(hex: "AF52DE")),
    LocationPreset(name: "Custom", icon: "mappin", colorHex: "AAAAAA", bgColor: Color(hex: "2A2A2A"), fgColor: Color(hex: "AAAAAA")),
]

// MARK: - Add Location View

struct AddLocationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let editingId: String?
    var initialBusStopCode: String? = nil
    var initialBusStopDescription: String? = nil
    var initialWalkMinutes: Int? = nil
    let onDone: () -> Void
    var onSave: (() -> Void)? = nil
    var startWithCustom: Bool = false

    @State private var selectedPreset: LocationPreset?
    @State private var customName = ""
    @State private var busStopCode = ""
    @State private var busStopDescription = ""
    @State private var searchQuery = ""
    @State private var selectedIcon = "mappin"
    @State private var selectedColorHex = "0A84FF"

    private var bgColor: Color { colorScheme == .dark ? Color(hex: "292929") : Color(hex: "F5F5F5") }
    private var cardBg: Color { colorScheme == .dark ? Color(hex: "1E1E1E") : Color.white }
    private var secondaryBg: Color { colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "E8E8E8") }

    private var existing: SavedLocation? {
        guard let id = editingId else { return nil }
        return appState.savedLocations.first { $0.id == id }
    }

    private var searchResults: [BusStop] {
        guard searchQuery.count >= 2 else { return [] }
        return appState.searchBusStops(query: searchQuery)
    }

    private var isEditing: Bool { editingId != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()

                if isEditing {
                    editLocationFlow
                } else if let preset = selectedPreset {
                    busStopSelectionFlow(preset: preset)
                } else {
                    presetSelectionGrid
                }

                VStack {
                    addLocationHeader
                    Spacer()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            if let loc = existing {
                customName = loc.name
                busStopCode = loc.busStopCode
                busStopDescription = loc.busStopDescription
                selectedIcon = loc.icon
                selectedColorHex = loc.colorHex
            } else if startWithCustom, selectedPreset == nil {
                let customPreset = locationPresets.first { $0.name == "Custom" }
                selectedPreset = customPreset
                selectedIcon = customPreset?.icon ?? "mappin"
                selectedColorHex = customPreset?.colorHex ?? "AAAAAA"
            }

            if !isEditing, let initialBusStopCode, let initialBusStopDescription {
                busStopCode = initialBusStopCode
                busStopDescription = initialBusStopDescription
            }
        }
    }

    private var navigationTitle: String {
        if isEditing { return "Edit Location" }
        if selectedPreset != nil { return "Select Bus Stop" }
        return "Add Location"
    }

    private var addLocationHeader: some View {
        ZStack {
            Text(navigationTitle)
                .font(.system(size: 18, weight: .bold))
                .tracking(18 * -0.025)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()

                GlassCircleIconButton(
                    systemName: "xmark",
                    size: 52,
                    iconSize: 20,
                    foregroundColor: .secondary
                ) {
                    onDone()
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 56)
        .padding(.top, 6)
        .background(bgColor.opacity(0.96))
    }

    // MARK: - Step 1: Preset Selection Grid

    private var presetSelectionGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("What kind of place\nis this?")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(28 * -0.025)
                    .foregroundColor(.primary)
                    .padding(.top, 8)

                Text("Choose a category for your saved location.")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(16 * -0.025)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(locationPresets) { preset in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedIcon = preset.icon
                                selectedColorHex = preset.colorHex
                                if preset.name == "Custom" {
                                    selectedPreset = preset
                                } else {
                                    customName = preset.name
                                    selectedPreset = preset
                                }
                            }
                        }) {
                            VStack(spacing: 10) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(preset.fgColor)
                                    .frame(width: 52, height: 52)
                                    .background(preset.bgColor)
                                    .clipShape(Circle())

                                Text(preset.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .tracking(14 * -0.025)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 72)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Step 2: Bus Stop Selection

    private func busStopSelectionFlow(preset: LocationPreset) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedPreset = nil
                        customName = ""
                        busStopCode = ""
                        busStopDescription = ""
                        searchQuery = ""
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(secondaryBg)
                        .clipShape(Circle())
                }

                Image(systemName: selectedIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: selectedColorHex))
                    .frame(width: 40, height: 40)
                    .background(Color(hex: selectedColorHex).opacity(colorScheme == .dark ? 0.22 : 0.16))
                    .clipShape(Circle())

                if preset.name == "Custom" {
                    TextField("Location name", text: $customName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .autocorrectionDisabled()
                } else {
                    Text(preset.name)
                        .font(.system(size: 18, weight: .bold))
                        .tracking(18 * -0.025)
                        .foregroundColor(.primary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 76)
            .padding(.bottom, 16)

            colorPickerSection
                .padding(.horizontal, 20)
                .padding(.bottom, 18)

            if preset.name == "Custom" {
                iconPickerSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Which bus stop do you usually take?")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(16 * -0.025)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)

                if !busStopCode.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(busStopDescription)
                                .font(.system(size: 16, weight: .bold))
                                .tracking(16 * -0.025)
                                .foregroundColor(.primary)
                            Text(busStopCode)
                                .font(.system(size: 13, weight: .bold))
                                .tracking(13 * -0.025)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            busStopCode = ""
                            busStopDescription = ""
                        }) {
                            Text("Change")
                                .font(.system(size: 14, weight: .bold))
                                .tracking(14 * -0.025)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                } else {
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
                }
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    if busStopCode.isEmpty {
                        if !searchResults.isEmpty {
                            ForEach(searchResults) { stop in
                                busStopRow(stop)
                            }
                        } else if searchQuery.count < 2 {
                            if !appState.nearbyStops.isEmpty {
                                Text("Nearby stops")
                                    .font(.system(size: 13, weight: .bold))
                                    .tracking(13 * -0.025)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)

                                ForEach(appState.nearbyStops) { nearby in
                                    busStopRow(nearby.stop, distance: nearby.distanceText)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 100)
            }

            Spacer()

            Button(action: save) {
                Text("Save")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(16 * -0.025)
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSave ? (colorScheme == .dark ? Color.white : Color.black) : Color.secondary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canSave)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func busStopRow(_ stop: BusStop, distance: String? = nil) -> some View {
        Button(action: {
            busStopCode = stop.BusStopCode
            busStopDescription = stop.Description
            searchQuery = ""
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
                if let dist = distance {
                    Text(dist)
                        .font(.system(size: 14, weight: .bold))
                        .tracking(14 * -0.025)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Edit Location Flow

    private let iconOptions: [(String, String)] = [
        ("house.fill", "Home"),
        ("briefcase.fill", "Work"),
        ("building.2.fill", "Office"),
        ("book.fill", "School"),
        ("graduationcap.fill", "College"),
        ("bag.fill", "Mall"),
        ("dumbbell.fill", "Gym"),
        ("fork.knife", "Restaurant"),
        ("cross.fill", "Hospital"),
        ("leaf.fill", "Park"),
        ("building.columns.fill", "Temple"),
        ("mappin", "Custom"),
    ]

    private let colorOptions: [(name: String, hex: String)] = [
        ("Blue", "0A84FF"),
        ("Orange", "FF9F0A"),
        ("Purple", "BF5AF2"),
        ("Green", "30D158"),
        ("Teal", "00C7BE"),
        ("Red", "FF453A"),
        ("Yellow", "FFD60A"),
        ("Pink", "FF2D55"),
        ("Gray", "8E8E93"),
    ]

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color")
                .font(.system(size: 13, weight: .bold))
                .tracking(13 * -0.025)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(colorOptions, id: \.hex) { option in
                        Button(action: { selectedColorHex = option.hex }) {
                            Circle()
                                .fill(Color(hex: option.hex))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(selectedColorHex == option.hex ? 0.9 : 0), lineWidth: 2)
                                        .padding(-4)
                                )
                                .frame(width: 40, height: 40)
                        }
                        .accessibilityLabel("\(option.name) color")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editLocationFlow: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(13 * -0.025)
                        .foregroundColor(.secondary)
                    TextField("Location name", text: $customName)
                        .font(.system(size: 16, weight: .bold))
                        .padding(14)
                        .background(cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .foregroundColor(.primary)
                }

            iconPickerSection

            colorPickerSection

            VStack(alignment: .leading, spacing: 6) {
                Text("Bus Stop")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(13 * -0.025)
                    .foregroundColor(.secondary)

                if !busStopCode.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(busStopDescription)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            Text(busStopCode)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Change") {
                            busStopCode = ""
                            busStopDescription = ""
                        }
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .bold))
                    }
                    .padding(14)
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    TextField("Search bus stop...", text: $searchQuery)
                        .font(.system(size: 16, weight: .bold))
                        .padding(14)
                        .background(cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .foregroundColor(.primary)
                        .autocorrectionDisabled()

                    if !searchResults.isEmpty {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(searchResults) { stop in
                                    Button(action: {
                                        busStopCode = stop.BusStopCode
                                        busStopDescription = stop.Description
                                        searchQuery = ""
                                    }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(stop.Description)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.primary)
                                            Text("\(stop.BusStopCode) · \(stop.RoadName)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                    }
                                    Divider()
                                }
                            }
                        }
                        .frame(maxHeight: 160)
                        .background(cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }

            Spacer()

            HStack(spacing: 12) {
                if let id = editingId, id != "home" {
                    Button(action: {
                        Haptics.tap(.medium)
                        appState.removeLocation(id: id)
                        onDone()
                    }) {
                        Text("Delete")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .frame(width: 100)
                }

                Button(action: save) {
                    Text("Save")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSave ? (colorScheme == .dark ? Color.white : Color.black) : Color.secondary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canSave)
            }
            }
            .padding(20)
            .padding(.top, 72)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !effectiveName.isEmpty && !busStopCode.isEmpty
    }

    private var iconPickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Icon")
                .font(.system(size: 13, weight: .bold))
                .tracking(13 * -0.025)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(iconOptions, id: \.0) { icon, _ in
                    Button(action: { selectedIcon = icon }) {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(selectedIcon == icon ? Color(hex: selectedColorHex) : .secondary)
                            .frame(width: 48, height: 48)
                            .background(selectedIcon == icon ? Color(hex: selectedColorHex).opacity(colorScheme == .dark ? 0.22 : 0.16) : cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel(iconOptions.first(where: { $0.0 == icon })?.1 ?? "Icon")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var effectiveName: String {
        customName.isEmpty ? (selectedPreset?.name ?? "") : customName
    }

    private func save() {
        Haptics.tap(.medium)
        if editingId == nil && !appState.isProMember && appState.savedLocations.count >= appState.freeSavedPlaceLimit {
            onDone()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                appState.presentProPaywall(context: "Unlimited saved stops")
            }
            return
        }
        let finalName = effectiveName
        let finalIcon = (isEditing || selectedPreset?.name == "Custom") ? selectedIcon : (selectedPreset?.icon ?? "mappin")

        if let id = editingId {
            appState.updateLocation(id: id, name: finalName, icon: finalIcon, colorHex: selectedColorHex, busStopCode: busStopCode, description: busStopDescription)
        } else {
            let loc = SavedLocation(
                id: UUID().uuidString,
                name: finalName,
                icon: finalIcon,
                colorHex: selectedColorHex,
                busStopCode: busStopCode,
                busStopDescription: busStopDescription,
                walkMinutes: initialBusStopCode == busStopCode ? (initialWalkMinutes ?? 5) : 5
            )
            appState.addLocation(loc)
        }
        onSave?()
        onDone()
    }
}

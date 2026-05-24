import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var query = ""
    let onSelect: (String, String) -> Void

    private var bgColor: Color { colorScheme == .dark ? Color(hex: "292929") : Color(hex: "F5F5F5") }
    private var cardBg: Color { colorScheme == .dark ? Color(hex: "1E1E1E") : Color.white }

    private var results: [BusStop] {
        guard query.count >= 2 else { return [] }
        return appState.searchBusStops(query: query)
    }

    private var nearbyStops: [NearbyStop] {
        Array(appState.nearbyStops.prefix(8))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Text("Search")
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
                            dismiss()
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 60)
                .padding(.top, 8)

                // Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search bus stop name or code...", text: $query)
                        .foregroundColor(.primary)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button(action: { query = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(14)
                .background(cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
                .padding(.top, 16)

                if query.isEmpty {
                    if nearbyStops.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "location")
                                .font(.system(size: 22, weight: .bold))
                            Text("Nearby stops will appear here.")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.secondary)
                        .padding(.top, 56)
                        Spacer()
                    } else {
                        List {
                            Section {
                                ForEach(nearbyStops) { nearby in
                                    stopRow(nearby.stop, detail: "\(nearby.stop.BusStopCode) · \(nearby.stop.RoadName)", trailing: nearby.distanceText)
                                }
                            } header: {
                                Text("Nearby stops")
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(12 * 0.05)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                } else if query.count >= 2 && results.isEmpty {
                    Text("No bus stops found.")
                        .foregroundColor(.secondary)
                        .padding(.top, 48)
                    Spacer()
                } else {
                    List(results) { stop in
                        stopRow(stop, detail: "\(stop.BusStopCode) · \(stop.RoadName)", trailing: nil)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(bgColor)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func stopRow(_ stop: BusStop, detail: String, trailing: String?) -> some View {
        Button(action: {
            dismiss()
            onSelect(stop.BusStopCode, stop.Description)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stop.Description)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(colorScheme == .dark ? Color(hex: "3A3A3A") : Color(hex: "D0D0D0"))
    }
}

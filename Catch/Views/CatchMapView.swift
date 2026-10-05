import SwiftUI
import MapKit

struct CatchMapView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    @State private var camera: MapCameraPosition = .region(Self.singapore)
    @State private var visibleRegion = Self.singapore
    @State private var visibleStops: [BusStop] = []
    @State private var selectedStop: BusStop?
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var showLocationHelp = false
    @State private var didCenter = false
    @State private var followsLocation = false
    @State private var clusters: [StopCluster] = []
    @State private var mapViewportSize = CGSize(width: 390, height: 844)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sheetDetent: PresentationDetent = .medium

    private static let singapore = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 1.3125, longitude: 103.854),
        latitudinalMeters: 2400, longitudinalMeters: 2400
    )

    var body: some View {
        GeometryReader { geometry in
            Map(position: $camera, interactionModes: .all) {
                UserAnnotation()
                ForEach(clusters) { cluster in
                    Annotation("\(cluster.stops.count) bus stops", coordinate: cluster.coordinate) {
                        Button { zoomInto(cluster) } label: {
                            StopClusterMarker(count: cluster.stops.count)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(cluster.stops.count) bus stops. Zoom in")
                    }.annotationTitles(.hidden)
                }
                ForEach(visibleStops) { stop in
                    Annotation(stop.Description, coordinate: stop.coordinate, anchor: .bottom) {
                        Button { select(stop) } label: {
                            Image(systemName: "bus.fill")
                                .font(.system(size: selectedStop?.id == stop.id ? 21 : 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: selectedStop?.id == stop.id ? 48 : 34, height: selectedStop?.id == stop.id ? 48 : 34)
                                .background(.blue.gradient, in: RoundedRectangle(cornerRadius: selectedStop?.id == stop.id ? 19 : 13))
                                .overlay(RoundedRectangle(cornerRadius: selectedStop?.id == stop.id ? 19 : 13).stroke(.white.opacity(0.8), lineWidth: 2))
                                .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Bus stop \(stop.Description), \(stop.BusStopCode)")
                    }
                    .annotationTitles(!searchText.isEmpty || visibleRegion.span.latitudeDelta < 0.008 ? .visible : .hidden)
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .mapControls { MapCompass(); MapScaleView() }
            .onAppear {
                mapViewportSize = geometry.size
                updateVisibleStops()
            }
            .onChange(of: geometry.size) { _, size in
                mapViewportSize = size
                updateVisibleStops()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                updateVisibleStops()
            }
            .onChange(of: camera.positionedByUser) { _, moved in
                if moved { followsLocation = false }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                    TextField("Search bus stops", text: $searchText)
                        .focused($searchFocused).autocorrectionDisabled().submitLabel(.search)
                    if searchFocused || !searchText.isEmpty {
                        Button { searchText = ""; searchFocused = false } label: { Image(systemName: "xmark.circle.fill") }
                            .accessibilityLabel("Clear search")
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 18).frame(height: 52)
                .catchRegularGlass(in: Capsule())
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 10)
            }
            .overlay(alignment: .bottomTrailing) {
                Button(action: recenter) {
                    Image(systemName: followsLocation ? "location.fill" : "location")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(.blue)
                        .frame(width: 54, height: 54)
                        .catchInteractiveGlass(in: Circle())
                }
                .accessibilityLabel("Return to my location")
                .padding(.trailing, 18)
                .padding(.bottom, selectedStop == nil ? 32 : sheetDetent == .height(230) ? 250 : geometry.size.height * 0.52)
            }
            .overlay(alignment: .top) {
                if !searchText.isEmpty && searchResults.isEmpty {
                    Text("No matching bus stops").font(.caption.bold())
                        .padding(10).background(.regularMaterial, in: Capsule()).padding(.top, 84)
                } else if appState.isLoadingStops {
                    Label("Loading bus stops", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.caption.bold()).padding(10).background(.regularMaterial, in: Capsule()).padding(.top, 84)
                } else if appState.allBusStops.isEmpty {
                    VStack(spacing: 8) {
                        Text("Bus stops couldn’t load").font(.headline)
                        Button("Try again") { Task { await appState.loadBusStops() } }
                    }
                    .padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22)).padding(.top, 84)
                }
            }
        }
        .task {
            if appState.allBusStops.isEmpty { await appState.loadBusStops() }
            updateVisibleStops()
            centerInitially()
        }
        .onReceive(appState.$allBusStops) { stops in updateVisibleStops(stops) }
        .onReceive(appState.locationManager.$location) { location in
            guard location != nil else { return }
            if followsLocation || !didCenter { centerInitially(at: location) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .catchHomeSelected)) { _ in
            selectedStop = nil
            searchFocused = false
        }
        .sheet(item: $selectedStop) { stop in
            BusStopDetailView(busStopCode: stop.BusStopCode, busStopName: stop.Description, onBack: { selectedStop = nil }, isMapSheet: true, onExpand: {
                withAnimation(.smooth(duration: 0.3)) { sheetDetent = .large }
            })
                .id(stop.id)
                .environmentObject(appState)
                .presentationDetents([.height(230), .medium, .large], selection: $sheetDetent)
                .presentationContentInteraction(.resizes)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(34)
                .presentationBackground(.regularMaterial)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .onChange(of: searchText) { _, query in
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { updateVisibleStops(); return }
            updateVisibleStops()
            if let stop = searchResults.first {
                withAnimation(.smooth(duration: 0.3)) {
                    camera = .region(MKCoordinateRegion(center: stop.coordinate, latitudinalMeters: 700, longitudinalMeters: 700))
                }
            }
        }
        .alert("Location is unavailable", isPresented: $showLocationHelp) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow location access for Catch to return to your position. You can still explore and search bus stops on the map.")
        }
    }

    private var searchResults: [BusStop] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return Array(appState.nearbyStops.map(\.stop).prefix(20)) }
        return Array(appState.allBusStops.filter {
            $0.Description.localizedCaseInsensitiveContains(query) || $0.BusStopCode.contains(query) || $0.RoadName.localizedCaseInsensitiveContains(query)
        }.prefix(40))
    }

    private func select(_ stop: BusStop) {
        Haptics.tap()
        searchFocused = false
        sheetDetent = .medium
        selectedStop = stop
        followsLocation = false
        // Preserve street-level zoom while lifting the selected stop above the sheet.
        let span = visibleRegion.span
        let centre = CLLocationCoordinate2D(latitude: stop.Latitude - span.latitudeDelta * 0.24, longitude: stop.Longitude)
        withAnimation(.smooth(duration: 0.4)) {
            camera = .region(MKCoordinateRegion(center: centre, span: span))
        }
    }

    private func recenter() {
        Haptics.tap()
        selectedStop = nil
        switch appState.locationManager.authorizationStatus {
        case .denied, .restricted: showLocationHelp = true
        case .notDetermined:
            followsLocation = true
            appState.locationManager.requestPermission()
        default:
            followsLocation = true
            appState.locationManager.startUpdating()
            centerInitially()
        }
    }

    private func centerInitially(at suppliedLocation: CLLocation? = nil) {
        guard let location = suppliedLocation ?? appState.locationManager.location else { return }
        didCenter = true
        followsLocation = true
        withAnimation(.smooth(duration: 0.4)) {
            camera = .region(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 420, longitudinalMeters: 420))
        }
    }

    private struct StopCluster: Identifiable {
        let id: String
        let stops: [BusStop]
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: stops.map(\.Latitude).reduce(0, +) / Double(stops.count),
                                   longitude: stops.map(\.Longitude).reduce(0, +) / Double(stops.count))
        }
    }

    private struct StopClusterMarker: View {
        let count: Int

        private var diameter: CGFloat {
            if count >= 100 { return 54 }
            if count >= 25 { return 48 }
            if count >= 10 { return 42 }
            return 36
        }

        var body: some View {
            ZStack {
                Circle()
                    .fill(.thickMaterial)
                VStack(spacing: -1) {
                    Text(count.formatted())
                        .font(.system(size: count >= 100 ? 15 : 16, weight: .bold, design: .rounded))
                    if count >= 50 {
                        Text("stops")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .padding(6)
            }
            .frame(width: diameter, height: diameter)
            .overlay(Circle().stroke(Color.blue.opacity(0.82), lineWidth: 2))
            .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 1).padding(3))
            .shadow(color: .black.opacity(0.24), radius: 5, y: 3)
        }
    }

    private func zoomInto(_ cluster: StopCluster) {
        Haptics.tap()
        searchFocused = false
        followsLocation = false
        let latitudes = cluster.stops.map(\.Latitude)
        let longitudes = cluster.stops.map(\.Longitude)
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.002, (latitudes.max()! - latitudes.min()!) * 1.6),
            longitudeDelta: max(0.002, (longitudes.max()! - longitudes.min()!) * 1.6))
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) {
            camera = .region(MKCoordinateRegion(center: cluster.coordinate, span: span))
        }
    }

    private func updateVisibleStops(_ stops: [BusStop]? = nil) {
        let searching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let lat = visibleRegion.span.latitudeDelta * 0.65
        let lon = visibleRegion.span.longitudeDelta * 0.65
        let center = visibleRegion.center
        let candidates = (searching ? searchResults : (stops ?? appState.allBusStops)).filter {
            searching || (abs($0.Latitude - center.latitude) < lat && abs($0.Longitude - center.longitude) < lon)
        }
        // Quantized world-anchored cells behave like MapKit's visual clustering:
        // groups remain stable while panning and become progressively more detailed
        // as the camera moves closer. The old fixed five-column grid produced dozens
        // of equally prominent bubbles at island scale.
        let width = max(visibleRegion.span.longitudeDelta, visibleRegion.span.latitudeDelta * 0.5)
        let markerSpacing: CGFloat
        switch width {
        case 0.12...: markerSpacing = 118
        case 0.045...: markerSpacing = 96
        case 0.016...: markerSpacing = 78
        default: markerSpacing = 64
        }
        let rawCell = width * Double(markerSpacing / max(mapViewportSize.width, 1))
        let cell = pow(2, ceil(log2(max(rawCell, 0.000001))))
        var groups: [String: [BusStop]] = [:]
        var singles: [BusStop] = []
        for stop in candidates {
            if searching || width < 0.007 || stop.id == selectedStop?.id { singles.append(stop); continue }
            let key = "\(cell):\(Int(floor(stop.Latitude / cell))):\(Int(floor(stop.Longitude / cell)))"
            groups[key, default: []].append(stop)
        }
        var nextClusters: [StopCluster] = []
        for key in groups.keys.sorted() {
            let members = groups[key]!
            if members.count == 1 { singles.append(members[0]) }
            else { nextClusters.append(StopCluster(id: key, stops: members)) }
        }
        if let selectedStop, !singles.contains(where: { $0.id == selectedStop.id }) { singles.append(selectedStop) }
        visibleStops = singles.sorted { $0.id < $1.id }
        clusters = nextClusters
    }
}

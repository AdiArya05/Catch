import SwiftUI
import WidgetKit

struct CatchWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: CatchWidgetSnapshot
}

struct CatchWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CatchWidgetEntry {
        CatchWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CatchWidgetEntry) -> Void) {
        completion(CatchWidgetEntry(date: Date(), snapshot: CatchWidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CatchWidgetEntry>) -> Void) {
        let entry = CatchWidgetEntry(date: Date(), snapshot: CatchWidgetStore.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct CatchTransitWidget: Widget {
    let kind = "CatchTransitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CatchWidgetProvider()) { entry in
            CatchWidgetView(entry: entry)
                .widgetURL(URL(string: "catch://home"))
        }
        .configurationDisplayName("Catch")
        .description("See pinned buses, usual stops, and catchability at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

@main
struct CatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CatchTransitWidget()
    }
}

private struct CatchWidgetView: View {
    let entry: CatchWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .accessoryCircular {
                    Color.clear
                } else {
                    WidgetBackground()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if entry.snapshot.isProMember == true {
            if family == .accessoryCircular {
                CircularLaunchWidget()
            } else if !entry.snapshot.hasTransitData || (!entry.snapshot.hasBusData && family != .accessoryRectangular) {
                EmptyTransitWidget(family: family)
            } else {
                switch family {
                case .systemSmall:
                    SmallBusWidget(snapshot: entry.snapshot)
                case .systemMedium:
                    MediumBusWidget(snapshot: entry.snapshot)
                case .systemLarge:
                    LargeBusWidget(snapshot: entry.snapshot)
                case .accessoryRectangular:
                    RectangularBusWidget(snapshot: entry.snapshot)
                default:
                    SmallBusWidget(snapshot: entry.snapshot)
                }
            }
        } else {
            ProLockedWidget(family: family)
        }
    }
}

private struct EmptyTransitWidget: View {
    let family: WidgetFamily

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                HStack(spacing: 5) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(CatchWidgetStyle.blue)
                    Text("Open Catch")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Image("CatchIcon")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Spacer()
                    Text("Open Catch")
                        .font(.system(size: family == .systemLarge ? 28 : 22, weight: .black))
                        .tracking(titleTracking(for: family == .systemLarge ? 28 : 22))
                        .foregroundStyle(.white)
                    Text("Pin a stop to fill this widget.")
                        .font(.system(size: family == .systemLarge ? 16 : 13, weight: .bold))
                        .foregroundStyle(CatchWidgetStyle.muted)
                        .lineLimit(2)
                }
                .padding(16)
            }
        }
        .widgetURL(URL(string: "catch://pro"))
    }
}

private struct ProLockedWidget: View {
    let family: WidgetFamily

    var body: some View {
        ZStack {
            lockedPreview
                .blur(radius: family == .accessoryRectangular ? 2.5 : 5)
                .saturation(0.72)
                .opacity(0.62)

            Color.black.opacity(family == .accessoryRectangular ? 0.22 : 0.34)

            unlockOverlay
        }
        .widgetURL(URL(string: "catch://home"))
    }

    @ViewBuilder
    private var lockedPreview: some View {
        switch family {
        case .systemSmall:
            SmallBusWidget(snapshot: .placeholder)
        case .systemMedium:
            MediumBusWidget(snapshot: .placeholder)
        case .systemLarge:
            LargeBusWidget(snapshot: .placeholder)
        case .accessoryCircular:
            CircularLaunchWidget()
        case .accessoryRectangular:
            RectangularBusWidget(snapshot: .placeholder)
        default:
            SmallBusWidget(snapshot: .placeholder)
        }
    }

    @ViewBuilder
    private var unlockOverlay: some View {
        if family == .accessoryCircular {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.46), in: Circle())
        } else {
            VStack(spacing: family == .systemSmall ? 5 : 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: family == .accessoryRectangular ? 12 : 16, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: family == .accessoryRectangular ? 24 : 32, height: family == .accessoryRectangular ? 24 : 32)
                    .background(Color.white.opacity(0.16), in: Circle())

                Text("Unlock with Catch Pro")
                    .font(.system(size: unlockTitleSize, weight: .black))
                    .tracking(titleTracking(for: unlockTitleSize))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(family == .systemSmall || family == .accessoryRectangular ? 2 : 1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, family == .accessoryRectangular ? 8 : 18)
        }
    }

    private var unlockTitleSize: CGFloat {
        switch family {
        case .systemSmall: return 18
        case .systemLarge: return 26
        case .accessoryRectangular: return 13
        default: return 22
        }
    }
}

private struct SmallBusWidget: View {
    let snapshot: CatchWidgetSnapshot

    private var bus: CatchWidgetBus {
        widgetBuses(from: snapshot).first ?? CatchWidgetSnapshot.placeholder.pinnedBuses[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 8) {
                Text(shortStopName(snapshot.stopName))
                    .font(.system(size: 20, weight: .bold))
                    .tracking(titleTracking(for: 20))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .allowsTightening(true)

                Spacer(minLength: 4)

                if let refreshURL = refreshURL(stopCode: snapshot.stopCode, stopName: snapshot.stopName) {
                    Link(destination: refreshURL) {
                        SymbolButton(systemName: "arrow.clockwise", color: CatchWidgetStyle.blue, size: 34, iconSize: 16)
                    }
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)

            Text(bus.serviceNo)
                .font(.system(size: 42, weight: .black))
                .tracking(titleTracking(for: 42))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    ArrivalText(minutes: index < bus.arrivals.count ? bus.arrivals[index] : nil, size: 23)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(16)
        .widgetURL(stopURL(stopCode: snapshot.stopCode, stopName: snapshot.stopName))
    }
}

private struct MediumBusWidget: View {
    let snapshot: CatchWidgetSnapshot

    private var buses: [CatchWidgetBus] {
        Array(widgetBuses(from: snapshot).prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 6) {
                    SymbolDot(systemName: "pin.fill", color: CatchWidgetStyle.blue, size: 18)
                    Text(shortStopName(snapshot.stopName))
                        .font(.system(size: 16, weight: .bold))
                        .tracking(titleTracking(for: 16))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.48)
                        .allowsTightening(true)

                    Text("Updated now")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(CatchWidgetStyle.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                if let refreshURL = refreshURL(stopCode: snapshot.stopCode, stopName: snapshot.stopName) {
                    Link(destination: refreshURL) {
                        SymbolButton(systemName: "arrow.clockwise", color: CatchWidgetStyle.blue, size: 30, iconSize: 15)
                    }
                }
            }

            VStack(spacing: 7) {
                ForEach(buses) { bus in
                    LiveActivityStyleRow(bus: bus)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .widgetURL(stopURL(stopCode: snapshot.stopCode, stopName: snapshot.stopName))
    }
}

private struct LargeBusWidget: View {
    let snapshot: CatchWidgetSnapshot

    private var place: CatchWidgetPlace {
        snapshot.home ?? snapshot.work ?? CatchWidgetSnapshot.placeholder.home!
    }

    private var displayStopName: String {
        snapshot.pinnedBuses.isEmpty ? place.stopName : snapshot.stopName
    }

    private var displayLabel: String {
        if !snapshot.pinnedBuses.isEmpty {
            if snapshot.home?.stopName == snapshot.stopName { return "Home" }
            if snapshot.work?.stopName == snapshot.stopName { return "Work" }
            return "Pinned"
        }
        return place.label
    }

    private var buses: [CatchWidgetBus] {
        var seen = Set<String>()
        let preferred = snapshot.pinnedBuses.isEmpty ? place.buses : snapshot.pinnedBuses
        let unique = preferred.filter { bus in
            guard !seen.contains(bus.serviceNo) else { return false }
            seen.insert(bus.serviceNo)
            return true
        }
        return Array(unique.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(shortStopName(displayStopName))
                        .font(.system(size: 40, weight: .bold))
                        .tracking(titleTracking(for: 40))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)

                    HStack(spacing: 8) {
                        MetaChip(title: displayLabel, systemName: placeSymbol(displayLabel), color: placeColor(displayLabel), textSize: 14, symbolSize: 18)
                        MetaChip(title: relativeUpdatedText(snapshot.updatedAt), systemName: "clock.fill", color: CatchWidgetStyle.muted, textSize: 15, symbolSize: 18)
                    }
                }

                Spacer(minLength: 8)

                if let refreshURL = refreshURL(stopCode: snapshot.stopCode ?? place.stopCode, stopName: displayStopName) {
                    Link(destination: refreshURL) {
                        SymbolButton(systemName: "arrow.clockwise", color: CatchWidgetStyle.blue)
                            .padding(.top, 4)
                    }
                }
            }

            VStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { index in
                    if index < buses.count {
                        WidgetTimingRow(bus: buses[index], compact: false)
                    } else {
                        WidgetTimingPlaceholderRow(compact: false)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .widgetURL(stopURL(stopCode: snapshot.stopCode ?? place.stopCode, stopName: displayStopName))
    }
}

private struct WidgetTimingPlaceholderRow: View {
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 10 : 14) {
            Text("—")
                .font(.system(size: compact ? 24 : 28, weight: .heavy))
                .foregroundStyle(CatchWidgetStyle.muted)
                .frame(width: compact ? 58 : 72, alignment: .leading)

            HStack(spacing: compact ? 8 : 14) {
                ForEach(0..<3, id: \.self) { _ in
                    ArrivalCell(minutes: nil, compact: compact)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, compact ? 16 : 18)
        .frame(height: compact ? 42 : 48)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: compact ? 18 : 20, style: .continuous))
    }
}

private struct CircularLaunchWidget: View {
    var body: some View {
        Image("CatchIcon")
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .widgetURL(URL(string: "catch://home"))
    }
}

private struct RectangularBusWidget: View {
    let snapshot: CatchWidgetSnapshot

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "pin.fill")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(CatchWidgetStyle.blue)
            Text(shortStopName(snapshot.stopName))
                .font(.system(size: 16, weight: .bold))
                .tracking(titleTracking(for: 16))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .widgetURL(stopURL(stopCode: snapshot.stopCode, stopName: snapshot.stopName))
    }
}

private struct WidgetHeader: View {
    let stopName: String
    var trailing: String?
    var trailingIcon: String?
    var titleSize: CGFloat = 34

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(shortStopName(stopName))
                    .font(.system(size: titleSize, weight: .bold))
                    .tracking(titleTracking(for: titleSize))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 5) {
                    SymbolDot(systemName: "clock.fill", color: CatchWidgetStyle.muted, size: 18)
                    Text("Updated now")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(CatchWidgetStyle.muted)
            }

            Spacer(minLength: 6)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.secondary)
            } else if let trailingIcon {
                SymbolButton(systemName: trailingIcon, color: CatchWidgetStyle.blue)
            }
        }
    }
}

private struct WidgetTimingRow: View {
    let bus: CatchWidgetBus
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 10 : 14) {
            Text(bus.serviceNo)
                .font(.system(size: compact ? 24 : 28, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: compact ? 58 : 72, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            HStack(spacing: compact ? 8 : 14) {
                ForEach(0..<3, id: \.self) { index in
                    ArrivalCell(minutes: index < bus.arrivals.count ? bus.arrivals[index] : nil, compact: compact)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, compact ? 16 : 18)
        .padding(.vertical, compact ? 10 : 9)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous))
    }
}

private struct ArrivalCell: View {
    let minutes: Int?
    let compact: Bool

    var body: some View {
        ArrivalText(minutes: minutes, size: compact ? 20 : 22)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct ArrivalText: View {
    let minutes: Int?
    let size: CGFloat

    var body: some View {
        if let minutes {
            if minutes == 0 {
                Text("Arr")
                    .font(.system(size: size, weight: .heavy))
                    .foregroundStyle(CatchWidgetStyle.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("\(minutes)m")
                    .font(.system(size: size, weight: .heavy))
                    .foregroundStyle(timingColor(minutes))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            }
        } else {
            Text("—")
                .font(.system(size: size, weight: .heavy))
                .foregroundStyle(.secondary)
        }
    }
}

private struct MetaChip: View {
    let title: String
    let systemName: String
    let color: Color
    let textSize: CGFloat
    let symbolSize: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            SymbolDot(systemName: systemName, color: color, size: symbolSize)
            Text(title)
                .font(.system(size: textSize, weight: .bold))
                .foregroundStyle(CatchWidgetStyle.muted)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }
}

private struct BusCountPill: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "rectangle.3.group.bubble.left.fill")
                .font(.system(size: 10, weight: .black))
            Text(busCountText(count))
                .font(.system(size: 12, weight: .black))
                .lineLimit(1)
        }
        .foregroundStyle(CatchWidgetStyle.blue)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(CatchWidgetStyle.blue.opacity(0.18), in: Capsule())
    }
}

private func busCountText(_ count: Int) -> String {
    count == 1 ? "1 bus" : "\(count) buses"
}

private struct LiveActivityStyleRow: View {
    let bus: CatchWidgetBus

    var body: some View {
        HStack(spacing: 12) {
            Text(bus.serviceNo)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
                .frame(width: 46, alignment: .leading)

            ForEach(0..<3, id: \.self) { index in
                let minutes = index < bus.arrivals.count ? bus.arrivals[index] : nil
                Text(arrivalCompactText(minutes))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(index == 0 ? timingColor(minutes ?? 999) : Color.white.opacity(0.56))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 35)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct SymbolButton: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 34
    var iconSize: CGFloat = 17

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: iconSize, weight: .black))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.13), in: Circle())
    }
}

private struct BusNumberPill: View {
    let serviceNo: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "bus.fill")
                .font(.system(size: 12, weight: .black))
            Text(serviceNo)
                .font(.system(size: 20, weight: .black))
                .tracking(titleTracking(for: 20))
        }
        .foregroundStyle(CatchWidgetStyle.blue)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(CatchWidgetStyle.blue.opacity(0.16), in: Capsule())
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private struct SmallBusNumberBadge: View {
    let serviceNo: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "bus.fill")
                .font(.system(size: 18, weight: .black))
            Text(serviceNo)
                .font(.system(size: 24, weight: .black))
                .tracking(titleTracking(for: 24))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .foregroundStyle(CatchWidgetStyle.blue)
        .padding(.horizontal, 12)
        .frame(minWidth: 74, maxWidth: 112, minHeight: 48)
        .background(CatchWidgetStyle.blue.opacity(0.16), in: Capsule())
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

private struct CatchabilityStatusPill: View {
    let level: CatchWidgetCatchability

    var body: some View {
        let color = catchabilityColor(level)
        HStack(spacing: 6) {
            Image(systemName: catchabilitySymbol(level))
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(color, in: Circle())

            Text(catchabilityCopy(level))
                .font(.system(size: 13, weight: .black))
                .tracking(titleTracking(for: 13))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(color.opacity(0.16), in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SymbolDot: View {
    let systemName: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.58, weight: .black))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.16), in: Circle())
    }
}

private struct CatchabilityPill: View {
    let level: CatchWidgetCatchability

    var body: some View {
        Text(catchabilityCopy(level))
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(catchabilityColor(level))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

private struct WidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.09, blue: 0.10),
                Color(red: 0.10, green: 0.11, blue: 0.12),
                Color(red: 0.07, green: 0.08, blue: 0.09),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [CatchWidgetStyle.blue.opacity(0.14), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 210
            )
        )
    }
}

private struct UpdatedFooter: View {
    let updatedAt: Date

    var body: some View {
        HStack(spacing: 12) {
            MetaChip(title: "Usual stop", systemName: "pin.fill", color: CatchWidgetStyle.blue, textSize: 13, symbolSize: 18)
            MetaChip(title: relativeUpdatedText(updatedAt), systemName: "clock.fill", color: CatchWidgetStyle.muted, textSize: 13, symbolSize: 18)
            Spacer()
        }
    }
}

private enum CatchWidgetStyle {
    static let blue = Color(red: 0.36, green: 0.78, blue: 1.0)
    static let green = Color(red: 0.29, green: 0.86, blue: 0.43)
    static let amber = Color(red: 1.0, green: 0.69, blue: 0.18)
    static let red = Color(red: 1.0, green: 0.36, blue: 0.32)
    static let muted = Color(red: 0.52, green: 0.53, blue: 0.56)
}

private func timingColor(_ minutes: Int) -> Color {
    if minutes <= 1 { return CatchWidgetStyle.red }
    if minutes <= 5 { return CatchWidgetStyle.amber }
    return CatchWidgetStyle.green
}

private func catchabilityColor(_ level: CatchWidgetCatchability) -> Color {
    switch level {
    case .easy: return CatchWidgetStyle.green
    case .leaveNow: return CatchWidgetStyle.amber
    case .tooTight: return CatchWidgetStyle.red
    case .unknown: return .secondary
    }
}

private func catchabilityCopy(_ level: CatchWidgetCatchability) -> String {
    switch level {
    case .easy: return "Easy"
    case .leaveNow: return "Leave now"
    case .tooTight: return "Too tight"
    case .unknown: return "Check"
    }
}

private func catchabilitySymbol(_ level: CatchWidgetCatchability) -> String {
    switch level {
    case .easy: return "checkmark"
    case .leaveNow: return "figure.walk"
    case .tooTight: return "xmark"
    case .unknown: return "clock.fill"
    }
}

private func placeSymbol(_ label: String) -> String {
    switch label.lowercased() {
    case "home": return "house.fill"
    case "work": return "briefcase.fill"
    case "school": return "book.fill"
    case "gym": return "dumbbell.fill"
    default: return "pin.fill"
    }
}

private func placeColor(_ label: String) -> Color {
    switch label.lowercased() {
    case "home": return CatchWidgetStyle.blue
    case "work": return CatchWidgetStyle.amber
    case "school": return CatchWidgetStyle.green
    case "gym": return Color(red: 1.0, green: 0.86, blue: 0.12)
    default: return CatchWidgetStyle.blue
    }
}

private func relativeUpdatedText(_ date: Date) -> String {
    let seconds = max(0, Int(Date().timeIntervalSince(date)))
    if seconds < 60 { return "Updated now" }
    let minutes = seconds / 60
    if minutes < 60 { return "Updated \(minutes)m" }
    return "Open to refresh"
}

private func arrivalCompactText(_ minutes: Int?) -> String {
    guard let minutes else { return "—" }
    return minutes <= 0 ? "Arr" : "\(minutes)m"
}

private func widgetBuses(from snapshot: CatchWidgetSnapshot) -> [CatchWidgetBus] {
    var seen = Set<String>()
    let buses = snapshot.pinnedBuses + (snapshot.home?.buses ?? []) + (snapshot.work?.buses ?? [])
    return buses.filter { bus in
        guard !seen.contains(bus.serviceNo) else { return false }
        seen.insert(bus.serviceNo)
        return true
    }
}

private func titleTracking(for size: CGFloat) -> CGFloat {
    -(size * 0.025)
}

private func stopURL(stopCode: String?, stopName: String) -> URL? {
    var components = URLComponents()
    components.scheme = "catch"
    components.host = "stop"
    components.queryItems = [
        URLQueryItem(name: "stopCode", value: stopCode),
        URLQueryItem(name: "stopName", value: stopName)
    ].filter { $0.value != nil }
    return components.url
}

private func refreshURL(stopCode: String?, stopName: String) -> URL? {
    var components = URLComponents()
    components.scheme = "catch"
    components.host = "refresh"
    components.queryItems = [
        URLQueryItem(name: "stopCode", value: stopCode),
        URLQueryItem(name: "stopName", value: stopName)
    ].filter { $0.value != nil }
    return components.url
}

private func shortStopName(_ name: String) -> String {
    name
        .replacingOccurrences(of: "Opposite", with: "Opp")
        .replacingOccurrences(of: "Bus Interchange", with: "Int")
        .replacingOccurrences(of: "Interchange", with: "Int")
}

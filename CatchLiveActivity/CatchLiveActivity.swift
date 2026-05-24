import ActivityKit
import SwiftUI
import WidgetKit

@main
struct CatchLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        CatchStopLiveActivity()
    }
}

struct CatchStopLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CatchStopActivityAttributes.self) { context in
            LockScreenStopBoard(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedIslandStopTitle(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    IslandStatusPill(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedIslandTimings(context: context)
                }
            } compactLeading: {
                Text(context.state.services.first?.serviceNo ?? context.attributes.stopShortName)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            } compactTrailing: {
                if let firstService = context.state.services.first {
                    Text(firstService.nextArrivalText)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(timingColor(for: firstService.arrivals.first ?? nil))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .contentTransition(.numericText())
                }
            } minimal: {
                Text(context.state.services.first?.serviceNo ?? "Bus")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color(hex: "5AC8FA"))
            }
            .keylineTint(Color(hex: "5AC8FA"))
        }
    }
}

private struct ExpandedIslandStopTitle: View {
    let context: ActivityViewContext<CatchStopActivityAttributes>

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Color(hex: "5AC8FA"))

            Text(context.attributes.stopName)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.32)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 10)
    }
}

private struct ExpandedIslandTimings: View {
    let context: ActivityViewContext<CatchStopActivityAttributes>

    var body: some View {
        if let service = context.state.services.first {
            VStack(alignment: .leading, spacing: 5) {
                IslandServicePill(serviceNo: service.serviceNo)
                IslandArrivalVectorStrip(service: service)
            }
            .padding(.top, 4)
        }
    }
}

private struct IslandStatusPill: View {
    let context: ActivityViewContext<CatchStopActivityAttributes>

    private var status: (text: String, icon: String, color: Color) {
        guard let service = context.state.services.first else {
            return ("Live", "dot.radiowaves.left.and.right", Color(hex: "5AC8FA"))
        }

        guard let first = service.arrivals.first ?? nil else {
            return ("Live", "dot.radiowaves.left.and.right", Color(hex: "5AC8FA"))
        }

        guard let walkMinutes = context.attributes.walkMinutes else {
            if first <= 1 { return ("Arriving", "clock.fill", Color(hex: "FF5A4F")) }
            if first <= 5 { return ("Soon", "clock.fill", Color(hex: "FFB02E")) }
            return ("On time", "checkmark", Color(hex: "44D36E"))
        }

        let buffer = first - walkMinutes
        if buffer > 5 {
            return ("Easy", "checkmark", Color(hex: "44D36E"))
        }
        if buffer >= 0 {
            return ("Leave now", "figure.walk", Color(hex: "FFB02E"))
        }
        if let next = service.arrivals.dropFirst().compactMap({ $0 }).first, next - walkMinutes >= 0 {
            return ("Next one safer", "arrow.right", Color(hex: "5AC8FA"))
        }
        return ("Too tight", "xmark", Color(hex: "FF5A4F"))
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 8, weight: .black))
            Text(status.text)
                .font(.system(size: 10, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(status.color.opacity(0.16))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct IslandServicePill: View {
    let serviceNo: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bus.fill")
                .font(.system(size: 10, weight: .black))
            Text(serviceNo)
                .font(.system(size: 13, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Color(hex: "5AC8FA"))
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Color(hex: "5AC8FA").opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct IslandArrivalVectorStrip: View {
    let service: CatchStopActivityAttributes.ServiceTiming

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                IslandArrivalVector(
                    minutes: service.arrivals[safe: index] ?? nil,
                    busType: service.busTypes[safe: index] ?? nil,
                    feature: service.features[safe: index] ?? nil
                )

                if index < 2 {
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 1, height: 30)
                        .padding(.horizontal, 4)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct IslandArrivalVector: View {
    let minutes: Int?
    let busType: String?
    let feature: String?

    var body: some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(arrivalMainText(for: minutes))
                    .font(.system(size: 24, weight: .black))
                    .tracking(-1)
                    .foregroundStyle(timingColor(for: minutes))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .contentTransition(.numericText())

                if let minutes, minutes > 0 {
                    Text("min")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(timingColor(for: minutes).opacity(0.68))
                }
            }
            .frame(height: 26)

            HStack(spacing: 5) {
                Image(systemName: busType == "DD" ? "bus.doubledecker" : "bus.fill")
                    .font(.system(size: 10, weight: .bold))

                if feature == "WAB" {
                    Image(systemName: "figure.roll")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundStyle(Color.white.opacity(0.58))
            .frame(height: 12)
        }
        .frame(maxWidth: .infinity, minHeight: 42)
    }
}

private struct LockScreenStopBoard: View {
    let context: ActivityViewContext<CatchStopActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color(hex: "5AC8FA"))
                    Text(context.attributes.stopName)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .allowsTightening(true)

                    Text("Updated now")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.42))
                        .lineLimit(1)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)

                LockScreenSummaryPill(context: context)
            }

            VStack(spacing: 5) {
                ForEach(context.state.services.prefix(3)) { service in
                    LockScreenBusRow(service: service)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct LockScreenSummaryPill: View {
    let context: ActivityViewContext<CatchStopActivityAttributes>

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "rectangle.3.group.bubble.left.fill")
                .font(.system(size: 9, weight: .black))
            Text(busCountText(context.state.services.count))
                .font(.system(size: 10, weight: .black))
                .lineLimit(1)
        }
        .foregroundStyle(Color(hex: "5AC8FA"))
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(Color(hex: "5AC8FA").opacity(0.18))
        .clipShape(Capsule())
    }
}

private struct LockScreenBusRow: View {
    let service: CatchStopActivityAttributes.ServiceTiming

    var body: some View {
        HStack(spacing: 12) {
            Text(service.serviceNo)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
                .frame(width: 48, alignment: .leading)

            ForEach(0..<3, id: \.self) { index in
                Text(arrivalCompactText(for: service.arrivals[safe: index] ?? nil))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(index == 0 ? timingColor(for: service.arrivals[safe: index] ?? nil) : Color.white.opacity(0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private func statusColor(for service: CatchStopActivityAttributes.ServiceTiming) -> Color {
    guard let first = service.arrivals.first ?? nil else { return Color(hex: "A5ABB6") }
    if first <= 1 { return Color(hex: "FF5A4F") }
    if first <= 5 { return Color(hex: "FFB02E") }
    return Color(hex: "44D36E")
}

private func timingColor(for minutes: Int?) -> Color {
    guard let minutes else { return Color(hex: "A5ABB6") }
    if minutes <= 1 { return Color(hex: "FF5A4F") }
    if minutes <= 5 { return Color(hex: "FFB02E") }
    return Color(hex: "44D36E")
}

private func arrivalCompactText(for minutes: Int?) -> String {
    guard let minutes else { return "—" }
    return minutes <= 0 ? "Arr" : "\(minutes)m"
}

private func arrivalMainText(for minutes: Int?) -> String {
    guard let minutes else { return "—" }
    return minutes <= 0 ? "Arr" : "\(minutes)"
}

private func busCountText(_ count: Int) -> String {
    count == 1 ? "1 bus" : "\(count) buses"
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct CatchLiveActivityBundle: WidgetBundle {
    var body: some Widget { CatchStopLiveActivity() }
}

struct CatchStopLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CatchStopActivityAttributes.self) { context in
            BusArrivalCard(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .widgetURL(context.attributes.stopURL)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.services.first?.serviceNo ?? "—")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.10), in: Capsule())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.stopShortName.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BusArrivalCard(attributes: context.attributes, state: context.state,
                                   isStale: context.isStale, showsFooter: false, showsHeader: false)
                }
            } compactLeading: {
                Text(context.state.services.first?.serviceNo ?? "—")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(context.state.arrivalColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } compactTrailing: {
                ArrivalCountdown(state: context.state, isStale: context.isStale)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            } minimal: {
                Image(systemName: "bus.fill")
                    .foregroundStyle(context.state.arrivalColor)
            }
            .contentMargins(.horizontal, 12, for: .expanded)
            .widgetURL(context.attributes.stopURL)
            .keylineTint(context.state.arrivalColor)
        }
    }
}

private let busAccent = Color(red: 0.24, green: 0.91, blue: 0.65)

struct BusArrivalCard: View {
    let attributes: CatchStopActivityAttributes
    let state: CatchStopActivityAttributes.ContentState
    var isStale = false
    var showsFooter = true
    var showsHeader = true

    private var color: Color { isStale ? .gray : state.arrivalColor }
    private var service: CatchStopActivityAttributes.ServiceTiming? { state.services.first }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 5) {
                if showsHeader {
                HStack(spacing: 8) {
                    Text(service?.serviceNo ?? "—")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.08), in: Capsule())
                        .accessibilityLabel("Bus \(service?.serviceNo ?? "unknown")")
                    Text(attributes.stopName.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer(minLength: 4)
                    Text("CATCH")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }

                }

                HStack(alignment: .center, spacing: showsHeader ? 8 : 5) {
                    CurrentClock()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ArrivalCountdown(state: state, isStale: isStale)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .frame(width: showsHeader ? 88 : 72)
                    ArrivalClock(state: state, isStale: isStale)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: showsHeader ? 22 : 17, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)

                BusArrivalTrack(state: state, isStale: isStale)

                HStack(spacing: 5) {
                    if service?.features.first == "WAB" {
                        Image(systemName: "figure.roll")
                            .foregroundStyle(.white.opacity(0.5))
                            .accessibilityLabel("Wheelchair accessible")
                    }
                    Text(crowding.label)
                        .foregroundStyle(crowding.color)
                    Spacer()
                    Text(isStale ? "Update needed" : state.arrivalDate == nil ? "No prediction" : "Estimated arrival")
                        .foregroundStyle(.white.opacity(0.75))
                }
                .font(.system(size: showsHeader ? 10 : 9, weight: .bold))
                .lineLimit(1)
            }
            .padding(.horizontal, showsHeader ? 16 : 12)
            .padding(.top, showsHeader ? 10 : 4)
            .padding(.bottom, showsHeader ? 6 : 4)

            if showsFooter {
                HStack(spacing: 8) {
                    Text(isStale ? "Open Catch to refresh" : attributes.roadName ?? attributes.stopName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    Link(destination: attributes.stopURL) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk.circle.fill")
                                .font(.system(size: 21, weight: .semibold))
                            Text(actionLabel)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(Color(red: 1, green: 0.79, blue: 0), in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(color.opacity(0.09))
                .overlay(alignment: .top) { color.opacity(0.2).frame(height: 1) }
            }
        }
    }

    private var actionLabel: String {
        guard !isStale, let seconds = state.remainingSeconds, let walk = attributes.walkMinutes else { return "VIEW STOP" }
        if seconds < Double(walk * 60) { return "NEXT BUS" }
        if seconds <= Double((walk + 5) * 60) { return "LEAVE NOW" }
        return "VIEW STOP"
    }

    private var crowding: (label: String, color: Color) {
        guard !isStale else { return ("Last known timing", .gray) }
        switch service?.load {
        case "SEA": return ("Seats available", busAccent)
        case "SDA": return ("Standing", .yellow)
        case "LSD": return ("Crowded", .red)
        default: return ("Crowding unknown", .gray)
        }
    }
}

private struct CurrentClock: View {
    var body: some View {
        Text(TimeDataSource<Date>.currentDate, format: .dateTime.hour().minute())
            .monospacedDigit()
            .accessibilityLabel("Current time")
    }
}

private struct ArrivalClock: View {
    let state: CatchStopActivityAttributes.ContentState
    var isStale = false
    var body: some View {
        if let date = state.arrivalDate, !isStale {
            Text(date, format: .dateTime.hour().minute())
                .monospacedDigit()
                .accessibilityLabel("Estimated arrival \(date.formatted(date: .omitted, time: .shortened))")
        } else {
            Text("—")
        }
    }
}

private struct ArrivalCountdown: View {
    let state: CatchStopActivityAttributes.ContentState
    var isStale = false

    var body: some View {
        Group {
            if isStale {
                Text("Update")
            } else if let arrival = state.arrivalDate {
                // The system advances this timer even when the app is suspended.
                Text(TimeDataSource<Date>.currentDate, format: .timer(countingDownIn: min(state.updatedAt, arrival.addingTimeInterval(-1))..<arrival, showsHours: false, maxFieldCount: 1, maxPrecision: .seconds(60)))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
            } else {
                Text("—")
            }
        }
        .foregroundStyle(state.arrivalColor)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}

private struct BusArrivalTrack: View {
    let state: CatchStopActivityAttributes.ContentState
    var isStale = false

    var body: some View {
        Group {
            if let arrival = state.arrivalDate, !isStale {
                let start = min(state.progressStartedAt ?? state.updatedAt, arrival.addingTimeInterval(-1))
                let finish = max(start.addingTimeInterval(1), arrival.addingTimeInterval(-120))
                ZStack {
                    Capsule()
                        .fill(state.arrivalColor.opacity(0.18))
                        .frame(height: 13)

                    // Date-relative progress views are advanced by the system while
                    // the app is suspended. Apple doesn't support custom styles for
                    // this initializer, so keep the native linear style here.
                    ProgressView(timerInterval: start...finish, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .progressViewStyle(.linear)
                    .tint(state.arrivalColor)
                    .scaleEffect(x: 1, y: 3, anchor: .center)
                    .frame(height: 13)
                    .clipShape(Capsule())

                    TimelineView(.periodic(from: start, by: 1)) { timeline in
                        BusProgressMarker(progress: state.arrivalProgress(at: timeline.date))
                    }
                }
                .frame(height: 24)
            } else {
                ArrivalProgressDrawing(progress: state.arrivalProgress, color: state.arrivalColor)
                    .frame(height: 24).opacity(0.45)
            }
        }
        .accessibilityLabel("Estimated bus arrival progress")
    }
}

private struct BusProgressMarker: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let markerSize: CGFloat = 24
            let fraction = min(1, max(0, progress))
            let travel = max(0, geometry.size.width - markerSize)
            let markerX = travel * fraction

            Image(systemName: "bus.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: markerSize, height: markerSize)
                .background(.white, in: Circle())
                .overlay(Circle().stroke(.black, lineWidth: 3))
                .offset(x: markerX)
                .animation(.linear(duration: 1), value: fraction)
        }
    }
}

// One animated value drives both the filled track and its white marker.
private struct ArrivalProgressDrawing: View, Animatable {
    var progress: CGFloat
    let color: Color
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { geometry in
            let radius: CGFloat = 12
            let travel = max(0, geometry.size.width - radius * 2)
            let fraction = min(1, max(0, progress))
            let markerX = radius + travel * fraction
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.18)).frame(height: 13)
                Capsule().fill(color)
                    .frame(width: markerX, height: 13)
                Image(systemName: "bus.fill")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(.black)
                    .frame(width: radius * 2, height: radius * 2)
                    .background(.white, in: Circle())
                    .overlay(Circle().stroke(.black, lineWidth: 3))
                    .offset(x: markerX - radius)
            }
            .frame(height: 24)
        }
    }
}

extension CatchStopActivityAttributes.ContentState {
    var arrivalDate: Date? {
        guard let service = services.first else { return nil }
        return service.arrivalDate ?? (service.arrivals.first ?? nil).map {
            updatedAt.addingTimeInterval(Double($0) * 60)
        }
    }

    var remainingSeconds: TimeInterval? {
        arrivalDate.map { max(0, $0.timeIntervalSince(updatedAt)) }
    }

    var arrivalColor: Color {
        guard let seconds = remainingSeconds else { return .gray }
        if seconds > 300 { return busAccent }
        if seconds > 120 { return Color(red: 1, green: 0.79, blue: 0) }
        return Color(red: 1, green: 0.23, blue: 0.24)
    }

    var arrivalSummary: String {
        guard let seconds = remainingSeconds else { return "Timing unavailable" }
        if seconds <= 30 { return "Arriving" }
        if seconds < 60 { return "Arriving in <1 min" }
        return "Arriving in \(Int(ceil(seconds / 60))) min"
    }

    var arrivalProgress: CGFloat {
        arrivalProgress(at: updatedAt)
    }

    func arrivalProgress(at date: Date) -> CGFloat {
        guard let arrivalDate else { return 0 }
        let start = progressStartedAt ?? updatedAt
        // The ETA shown as "1 minute" begins below two minutes because bus
        // arrival minutes are intentionally floored. Complete the track at that
        // threshold so the bar and marker are at the end throughout that state.
        let finish = arrivalDate.addingTimeInterval(-120)
        let duration = finish.timeIntervalSince(start)
        guard duration > 0 else { return 1 }
        return min(1, max(0, date.timeIntervalSince(start) / duration))
    }
}

extension CatchStopActivityAttributes {
    var stopURL: URL {
        var components = URLComponents()
        components.scheme = "catch"
        components.host = "stop"
        components.queryItems = [URLQueryItem(name: "stopCode", value: stopCode), URLQueryItem(name: "stopName", value: stopName)]
        return components.url!
    }
}

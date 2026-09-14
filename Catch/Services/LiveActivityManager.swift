import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private init() {}

    var activeActivity: Activity<CatchStopActivityAttributes>? {
        Activity<CatchStopActivityAttributes>.activities.first
    }

    func startStopWatch(stopCode: String, stopName: String, walkMinutes: Int?, services: [BusService], roadName: String? = nil) async {
        guard !services.isEmpty, ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = CatchStopActivityAttributes(
            stopCode: stopCode,
            stopName: stopName,
            stopShortName: Self.shortStopName(from: stopName),
            walkMinutes: walkMinutes,
            roadName: roadName
        )
        let now = Date()
        let timings = Self.timelineServices(from: services)
        let state = CatchStopActivityAttributes.ContentState(
            services: timings,
            updatedAt: now,
            progressStartedAt: Self.progressStart(arrival: timings.first?.arrivalDate, now: now)
        )

        await endAll()

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: Self.staleDate(for: state)),
                pushType: nil
            )
        } catch {
            #if DEBUG
            print("Live Activity start failed: \(error)")
            #endif
        }
    }

    func updateStopWatch(services: [BusService]) async {
        guard let activeActivity else { return }
        guard !services.isEmpty else {
            await endAll()
            return
        }
        let previous = activeActivity.content.state
        let timings = Self.timelineServices(from: services)
        let sameBus = timings.first?.serviceNo == previous.services.first?.serviceNo
        let previousArrival = previous.services.first?.arrivalDate
        let nextArrival = timings.first?.arrivalDate
        // Start a fresh journey when the prediction rolls over to the next bus.
        let rolledOver = previousArrival.map { old in
            old <= Date() && (nextArrival?.timeIntervalSince(old) ?? 0) > 60
        } ?? false
        let now = Date()
        let baseline = Self.progressStart(arrival: nextArrival, now: now)
        let state = CatchStopActivityAttributes.ContentState(
            services: timings,
            updatedAt: now,
            progressStartedAt: sameBus && !rolledOver ? min(previous.progressStartedAt ?? baseline, baseline) : baseline
        )
        await activeActivity.update(ActivityContent(state: state, staleDate: Self.staleDate(for: state)))
    }

    func endAll() async {
        for activity in Activity<CatchStopActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // An arrival within fifteen minutes starts partway through the approach,
    // instead of measuring how long the person has had Live Board open.
    private static func progressStart(arrival: Date?, now: Date) -> Date {
        min(now, (arrival ?? now).addingTimeInterval(-15 * 60))
    }

    private static func staleDate(for state: CatchStopActivityAttributes.ContentState) -> Date {
        let freshnessLimit = state.updatedAt.addingTimeInterval(90)
        guard let arrival = state.services.first?.arrivalDate else { return freshnessLimit }
        // Preserve the explicitly labelled estimate until that bus is due.
        // Foreground refresh replaces it; after arrival the OS marks it stale.
        return max(state.updatedAt, arrival.addingTimeInterval(30))
    }

    private static func timelineServices(from services: [BusService]) -> [CatchStopActivityAttributes.ServiceTiming] {
        services.prefix(1)
            .map { service in
                CatchStopActivityAttributes.ServiceTiming(
                    serviceNo: service.ServiceNo,
                    arrivals: [
                        service.NextBus.arrivalMinutes,
                        service.NextBus2.arrivalMinutes,
                        service.NextBus3.arrivalMinutes
                    ],
                    busTypes: [
                        service.NextBus.BusType,
                        service.NextBus2.BusType,
                        service.NextBus3.BusType
                    ],
                    features: [
                        service.NextBus.Feature,
                        service.NextBus2.Feature,
                        service.NextBus3.Feature
                    ],
                    arrivalDate: service.NextBus.arrivalDate,
                    load: service.NextBus.Load
                )
            }
    }

    private static func shortStopName(from name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "Opposite", with: "Opp")
            .replacingOccurrences(of: "Before", with: "Bef")
            .replacingOccurrences(of: "After", with: "Aft")
            .replacingOccurrences(of: "Bus Stop", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let words = cleaned.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return name }

        if words.first?.lowercased() == "opp", words.count > 1 {
            return "Opp \(words[1])"
        }

        if words.count >= 2, "\(words[0]) \(words[1])".count <= 12 {
            return "\(words[0]) \(words[1])"
        }

        return words[0]
    }
}

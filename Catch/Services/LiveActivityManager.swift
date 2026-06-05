import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private init() {}

    var activeActivity: Activity<CatchStopActivityAttributes>? {
        Activity<CatchStopActivityAttributes>.activities.first
    }

    func startStopWatch(stopCode: String, stopName: String, walkMinutes: Int?, services: [BusService]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = CatchStopActivityAttributes(
            stopCode: stopCode,
            stopName: stopName,
            stopShortName: Self.shortStopName(from: stopName),
            walkMinutes: walkMinutes
        )
        let state = CatchStopActivityAttributes.ContentState(
            services: Self.timelineServices(from: services),
            updatedAt: Date()
        )

        await endAll()

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(90)),
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
        let state = CatchStopActivityAttributes.ContentState(
            services: Self.timelineServices(from: services),
            updatedAt: Date()
        )
        await activeActivity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(90)))
    }

    func endAll() async {
        for activity in Activity<CatchStopActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func timelineServices(from services: [BusService]) -> [CatchStopActivityAttributes.ServiceTiming] {
        services
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
                    ]
                )
            }
            .sorted { lhs, rhs in
                serviceSortKey(lhs.serviceNo) < serviceSortKey(rhs.serviceNo)
            }
    }

    private static func serviceSortKey(_ service: String) -> (Int, String) {
        let number = Int(service.prefix { $0.isNumber }) ?? Int.max
        return (number, service)
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

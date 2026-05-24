import ActivityKit
import Foundation

struct CatchStopActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var services: [ServiceTiming]
        var updatedAt: Date
    }

    struct ServiceTiming: Codable, Hashable, Identifiable {
        var id: String { serviceNo }
        let serviceNo: String
        let arrivals: [Int?]
        let busTypes: [String?]
        let features: [String?]

        var nextArrivalText: String {
            guard let first = arrivals.first ?? nil else { return "—" }
            return first <= 0 ? "Arr" : "\(first) min"
        }

        var expandedArrivalText: String {
            let visibleArrivals = arrivals.prefix(3).map { value -> String in
                guard let value else { return "—" }
                return value <= 0 ? "Arr" : "\(value)m"
            }
            return visibleArrivals.isEmpty ? "—" : visibleArrivals.joined(separator: "   ")
        }
    }

    let stopCode: String
    let stopName: String
    let stopShortName: String
    let walkMinutes: Int?
}

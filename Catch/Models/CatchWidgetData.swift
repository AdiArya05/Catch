import Foundation

struct CatchWidgetSnapshot: Codable {
    var stopCode: String?
    var stopName: String
    var updatedAt: Date
    var pinnedBuses: [CatchWidgetBus]
    var home: CatchWidgetPlace?
    var work: CatchWidgetPlace?
    var isProMember: Bool?

    static let placeholder = CatchWidgetSnapshot(
        stopCode: "21699",
        stopName: "Summerdale",
        updatedAt: Date(),
        pinnedBuses: [
            CatchWidgetBus(serviceNo: "30", arrivals: [4, 22, 41], catchability: .leaveNow),
            CatchWidgetBus(serviceNo: "154", arrivals: [8, 19, 29], catchability: .easy),
            CatchWidgetBus(serviceNo: "178", arrivals: [10, nil, nil], catchability: .easy),
        ],
        home: CatchWidgetPlace(
            label: "Home",
            stopCode: "21699",
            stopName: "Summerdale",
            buses: [
                CatchWidgetBus(serviceNo: "30", arrivals: [4, 22, 41], catchability: .leaveNow),
                CatchWidgetBus(serviceNo: "154", arrivals: [8, 19, 29], catchability: .easy),
                CatchWidgetBus(serviceNo: "178", arrivals: [10, nil, nil], catchability: .easy),
                CatchWidgetBus(serviceNo: "180A", arrivals: [5, 15, 25], catchability: .leaveNow),
            ]
        ),
        work: CatchWidgetPlace(
            label: "Work",
            stopCode: nil,
            stopName: "HarbourFront Int",
            buses: [
                CatchWidgetBus(serviceNo: "10", arrivals: [6, 18, 31], catchability: .easy),
                CatchWidgetBus(serviceNo: "30", arrivals: [9, 21, 42], catchability: .easy),
            ]
        )
    )
}

struct CatchWidgetPlace: Codable {
    var label: String
    var stopCode: String?
    var stopName: String
    var buses: [CatchWidgetBus]
}

struct CatchWidgetBus: Codable, Identifiable {
    var id: String { serviceNo }
    var serviceNo: String
    var arrivals: [Int?]
    var catchability: CatchWidgetCatchability

    var nextArrival: Int? {
        arrivals.first ?? nil
    }
}

enum CatchWidgetCatchability: String, Codable {
    case easy
    case leaveNow
    case tooTight
    case unknown
}

enum CatchWidgetStore {
    static let appGroup = "group.com.adityaarya.catch"
    static let snapshotKey = "catch-widget-snapshot"
    static let proKey = "catch-pro-member"

    static func load() -> CatchWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: snapshotKey),
              var snapshot = try? JSONDecoder().decode(CatchWidgetSnapshot.self, from: data) else {
            var placeholder = CatchWidgetSnapshot.placeholder
            placeholder.isProMember = UserDefaults(suiteName: appGroup)?.bool(forKey: proKey) ?? false
            return placeholder
        }
        snapshot.isProMember = defaults.bool(forKey: proKey)
        return snapshot
    }

    static func save(_ snapshot: CatchWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func saveProMembership(_ value: Bool) {
        UserDefaults(suiteName: appGroup)?.set(value, forKey: proKey)
    }
}

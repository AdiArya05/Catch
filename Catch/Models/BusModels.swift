import Foundation
import CoreLocation
import SwiftUI

// MARK: - LTA API Response Models

struct BusArrivalResponse: Codable {
    let BusStopCode: String
    let Services: [BusService]
}

struct BusService: Codable, Identifiable {
    var id: String { ServiceNo }
    let ServiceNo: String
    let NextBus: BusInfo
    let NextBus2: BusInfo
    let NextBus3: BusInfo
}

struct BusInfo: Codable {
    let EstimatedArrival: String?
    let Load: String?
    let Feature: String?
    let BusType: String?

    enum CodingKeys: String, CodingKey {
        case EstimatedArrival, Load, Feature
        case BusType = "Type"
    }

    var arrivalMinutes: Int? {
        guard let arrival = EstimatedArrival, !arrival.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatterNoFrac = ISO8601DateFormatter()
        formatterNoFrac.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: arrival) ?? formatterNoFrac.date(from: arrival) else { return nil }
        let diff = date.timeIntervalSinceNow / 60
        return max(0, Int(diff))
    }

    var arrivalText: String {
        guard let min = arrivalMinutes else { return "-" }
        if min <= 0 { return "Arr" }
        if min == 1 { return "1 min" }
        return "\(min) min"
    }

    var loadColor: LoadLevel {
        switch Load {
        case "SEA": return .seats
        case "SDA": return .standing
        case "LSD": return .limited
        default: return .unknown
        }
    }
}

enum LoadLevel {
    case seats, standing, limited, unknown

    var label: String {
        switch self {
        case .seats: return "Seats available"
        case .standing: return "Standing available"
        case .limited: return "Limited standing"
        case .unknown: return "Crowding unknown"
        }
    }

    var color: Color {
        switch self {
        case .seats: return Color(hex: "30D158")
        case .standing: return Color(hex: "FFB02E")
        case .limited: return Color(hex: "FF453A")
        case .unknown: return Color(hex: "8E8E93")
        }
    }

}

// MARK: - Bus Stop

struct BusStop: Codable, Identifiable {
    var id: String { BusStopCode }
    let BusStopCode: String
    let RoadName: String
    let Description: String
    let Latitude: Double
    let Longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: Latitude, longitude: Longitude)
    }
}

struct BusStopResponse: Codable {
    let value: [BusStop]
}

// MARK: - Nearby Stop (with distance)

struct NearbyStop: Identifiable {
    var id: String { stop.BusStopCode }
    let stop: BusStop
    let distance: CLLocationDistance

    var distanceText: String {
        if distance < 1000 {
            return "\(Int(distance))m"
        }
        return String(format: "%.1fkm", distance / 1000)
    }
}

// MARK: - Saved Location

struct SavedLocation: Codable, Identifiable {
    let id: String
    var name: String
    var icon: String
    var colorHex: String
    var busStopCode: String
    var busStopDescription: String
    var walkMinutes: Int

    init(id: String, name: String, icon: String, colorHex: String = "5AC8FA", busStopCode: String, busStopDescription: String, walkMinutes: Int = 5) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.busStopCode = busStopCode
        self.busStopDescription = busStopDescription
        self.walkMinutes = walkMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? SavedLocation.defaultColorHex(for: name)
        busStopCode = try container.decode(String.self, forKey: .busStopCode)
        busStopDescription = try container.decode(String.self, forKey: .busStopDescription)
        walkMinutes = try container.decodeIfPresent(Int.self, forKey: .walkMinutes) ?? 5
    }

    static func defaultColorHex(for name: String) -> String {
        switch name.lowercased() {
        case "home": return "0A84FF"
        case "work": return "FF9F0A"
        case "office": return "BF5AF2"
        case "school": return "30D158"
        case "college": return "00C7BE"
        case "mall": return "FF453A"
        case "gym": return "FFD60A"
        case "restaurant": return "FF2D55"
        case "park": return "30D158"
        case "temple": return "AF52DE"
        default: return "BF5AF2"
        }
    }
}

// MARK: - Commute Log Entry

struct CommuteLogEntry: Codable {
    let stopCode: String
    let stopName: String
    let timestamp: Date
    let dayOfWeek: Int
    let hour: Int
    let busServices: [String]
}

// MARK: - Catchability

struct CatchabilityResult: Identifiable {
    let id = UUID()
    let busService: String
    let arrivalMinutes: Int
    let walkMinutes: Int
    let level: CatchabilityLevel
    let nextBusMinutes: Int?

    var leaveInMinutes: Int { arrivalMinutes - walkMinutes }
}

enum CatchabilityLevel {
    case easy, tight, missed

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .tight: return "Leave now"
        case .missed: return "Too tight"
        }
    }

    var color: Color {
        switch self {
        case .easy: return Color(hex: "4CD964")
        case .tight: return Color(hex: "F5A623")
        case .missed: return Color(hex: "E74C3C")
        }
    }
}

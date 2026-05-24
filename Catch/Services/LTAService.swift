import Foundation

class LTAService {
    static let shared = LTAService()
    private let apiKey = "8SlaHtOZRzyfeVqOOJPgaQ=="
    private let baseURL = "https://datamall2.mytransport.sg/ltaodataservice"

    private init() {}

    func fetchBusArrivals(busStopCode: String) async throws -> BusArrivalResponse {
        let url = URL(string: "\(baseURL)/v3/BusArrival?BusStopCode=\(busStopCode)")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "AccountKey")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(BusArrivalResponse.self, from: data)
    }

    func fetchAllBusStops() async throws -> [BusStop] {
        var allStops: [BusStop] = []
        var skip = 0
        while true {
            let url = URL(string: "\(baseURL)/BusStops?$skip=\(skip)")!
            var request = URLRequest(url: url)
            request.setValue(apiKey, forHTTPHeaderField: "AccountKey")
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(BusStopResponse.self, from: data)
            if response.value.isEmpty { break }
            allStops.append(contentsOf: response.value)
            skip += 500
        }
        return allStops
    }
}

import Foundation

class LTAService {
    static let shared = LTAService()
    private let apiKey = "8SlaHtOZRzyfeVqOOJPgaQ=="
    private let baseURL = "https://datamall2.mytransport.sg/ltaodataservice"

    private init() {}

    func fetchBusArrivals(busStopCode: String) async throws -> BusArrivalResponse {
        var components = URLComponents(string: "\(baseURL)/v3/BusArrival")!
        components.queryItems = [URLQueryItem(name: "BusStopCode", value: busStopCode)]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 12
        request.setValue(apiKey, forHTTPHeaderField: "AccountKey")
        let data = try await perform(request)
        return try JSONDecoder().decode(BusArrivalResponse.self, from: data)
    }

    func fetchAllBusStops() async throws -> [BusStop] {
        var allStops: [BusStop] = []
        var skip = 0
        while true {
            var components = URLComponents(string: "\(baseURL)/BusStops")!
            components.queryItems = [URLQueryItem(name: "$skip", value: "\(skip)")]
            var request = URLRequest(url: components.url!)
            request.timeoutInterval = 18
            request.setValue(apiKey, forHTTPHeaderField: "AccountKey")
            let data = try await perform(request)
            let response = try JSONDecoder().decode(BusStopResponse.self, from: data)
            if response.value.isEmpty { break }
            allStops.append(contentsOf: response.value)
            skip += 500
        }
        return allStops
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw LTAServiceError.invalidResponse
        }
        return data
    }
}

enum LTAServiceError: Error {
    case invalidResponse
}

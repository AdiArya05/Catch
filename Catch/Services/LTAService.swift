import Foundation

actor LTAService {
    static let shared = LTAService()
    private let apiKey = "8SlaHtOZRzyfeVqOOJPgaQ=="
    private let baseURL = "https://datamall2.mytransport.sg/ltaodataservice"
    private var cachedBusRouteSummaries: [BusRouteSummary]?

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
            let pageSkips = stride(from: skip, through: skip + 1_500, by: 500).map { $0 }
            let pages = try await withThrowingTaskGroup(of: (Int, [BusStop]).self) { group in
                for pageSkip in pageSkips {
                    group.addTask { [self] in
                        (pageSkip, try await fetchBusStopPage(skip: pageSkip))
                    }
                }

                var loaded: [(Int, [BusStop])] = []
                for try await page in group {
                    loaded.append(page)
                }
                return loaded.sorted { $0.0 < $1.0 }
            }

            for (_, page) in pages {
                allStops.append(contentsOf: page)
            }
            if pages.contains(where: { $0.1.count < 500 }) { break }
            skip += 2_000
        }
        return allStops
    }

    private func fetchBusStopPage(skip: Int) async throws -> [BusStop] {
        var components = URLComponents(string: "\(baseURL)/BusStops")!
        components.queryItems = [URLQueryItem(name: "$skip", value: "\(skip)")]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 12
        request.setValue(apiKey, forHTTPHeaderField: "AccountKey")
        let data = try await perform(request)
        return try JSONDecoder().decode(BusStopResponse.self, from: data).value
    }

    func fetchBusRouteSummaries(serviceNo: String) async throws -> [BusRouteSummary] {
        let allSummaries: [BusRouteSummary]
        if let cachedBusRouteSummaries {
            allSummaries = cachedBusRouteSummaries
        } else {
            var fetched: [BusRouteSummary] = []
            var skip = 0
            while true {
                var components = URLComponents(string: "\(baseURL)/BusServices")!
                components.queryItems = [URLQueryItem(name: "$skip", value: "\(skip)")]
                var request = URLRequest(url: components.url!)
                request.timeoutInterval = 18
                request.setValue(apiKey, forHTTPHeaderField: "AccountKey")
                let data = try await perform(request)
                let response = try JSONDecoder().decode(BusRouteSummaryResponse.self, from: data)
                if response.value.isEmpty { break }
                fetched.append(contentsOf: response.value)
                skip += 500
            }
            cachedBusRouteSummaries = fetched
            allSummaries = fetched
        }

        return allSummaries
            .filter { $0.ServiceNo.caseInsensitiveCompare(serviceNo) == .orderedSame }
            .sorted { $0.Direction < $1.Direction }
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

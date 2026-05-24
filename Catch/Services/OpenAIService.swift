import Foundation

enum OpenAIServiceError: Error {
    case disabled
}

actor OpenAIService {
    static let shared = OpenAIService()

    private init() {}

    func generateCatchMessage(results: [CatchabilityResult], stopName: String) async throws -> String {
        throw OpenAIServiceError.disabled
    }

    func generateLeaveNowMessage(busService: String, arrivalMinutes: Int, stopName: String) async throws -> String {
        throw OpenAIServiceError.disabled
    }

    func analyzeCommutePatterns(logs: [CommuteLogEntry]) async throws -> String {
        throw OpenAIServiceError.disabled
    }
}

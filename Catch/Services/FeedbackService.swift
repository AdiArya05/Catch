import Foundation
import Security

struct FeedbackPost: Decodable, Identifiable {
    let id: UUID
    let body: String
    let status: String
    let developer_response: String?
    let created_at: String
}

actor FeedbackService {
    static let shared = FeedbackService()
    private struct Session: Codable { let access_token: String; let refresh_token: String; let expires_in: Double }
    private var token: String?
    private var expiry = Date.distantPast
    private var config: (URL, String)? {
        guard let path = Bundle.main.url(forResource: "FeedbackConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: path),
              let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
              let raw = values["URL"], let url = URL(string: raw), url.scheme == "https",
              let key = values["PublishableKey"], !key.isEmpty else { return nil }
        return (url, key)
    }
    enum Failure: LocalizedError {
        case unavailable, server, http(Int), invalid, storage
        var errorDescription: String? {
            switch self {
            case .unavailable: "Feedback is not connected yet. Please try again after the next app update."
            case .server, .http: "Couldn’t reach the feedback board. Your message is still here. Please try again."
            case .invalid: "Please write between 10 and 4,000 characters."
            case .storage: "Couldn’t securely save your feedback session. Please try again."
            }
        }
    }
    private var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.adityaarya.catch.feedback", kSecAttrAccount as String: "refresh"]
    }
    private func authenticate() async throws -> String {
        if let token, expiry > Date() { return token }
        var query = keychainQuery
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        let found = SecItemCopyMatching(query as CFDictionary, &result)
        let refresh = (result as? Data).flatMap { String(data: $0, encoding: .utf8) }
        let data: Data
        if found == errSecSuccess, let refresh {
            do {
                data = try await request("auth/v1/token?grant_type=refresh_token", method: "POST", body: ["refresh_token": refresh])
            } catch Failure.http(let status) where status == 400 || status == 401 {
                // A revoked/expired anonymous session must not permanently brick feedback.
                SecItemDelete(keychainQuery as CFDictionary)
                data = try await request("auth/v1/signup", method: "POST", body: [:])
            }
        } else {
            data = try await request("auth/v1/signup", method: "POST", body: [:])
        }
        let session = try JSONDecoder().decode(Session.self, from: data)
        let attributes: [String: Any] = [kSecValueData as String: Data(session.refresh_token.utf8), kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let updated = SecItemUpdate(keychainQuery as CFDictionary, attributes as CFDictionary)
        if updated == errSecItemNotFound {
            guard SecItemAdd(keychainQuery.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess else { throw Failure.storage }
        } else if updated != errSecSuccess { throw Failure.storage }
        token = session.access_token
        expiry = Date().addingTimeInterval(session.expires_in - 60)
        return session.access_token
    }
    private func request(_ path: String, method: String = "GET", body: [String: String]? = nil, bearer: String? = nil) async throws -> Data {
        guard let (base, key) = config,
              let url = URL(string: base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + path) else { throw Failure.unavailable }
        var req = URLRequest(url: url); req.httpMethod = method; req.timeoutInterval = 20
        req.setValue(key, forHTTPHeaderField: "apikey")
        if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body); req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: req) }
        catch { throw Failure.server }
        guard let http = response as? HTTPURLResponse else { throw Failure.server }
        guard (200..<300).contains(http.statusCode) else { throw Failure.http(http.statusCode) }
        return data
    }
    func posts() async throws -> [FeedbackPost] {
        let bearer = try await authenticate()
        let data = try await request("rest/v1/feedback?select=id,body,status,developer_response,created_at&order=created_at.desc&limit=100", bearer: bearer)
        return try JSONDecoder().decode([FeedbackPost].self, from: data)
    }
    func submit(_ body: String, id: UUID) async throws {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (10...4000).contains(trimmed.count) else { throw Failure.invalid }
        let bearer = try await authenticate()
        _ = try await request("rest/v1/rpc/submit_feedback", method: "POST", body: ["message": trimmed, "request_id": id.uuidString], bearer: bearer)
    }
}

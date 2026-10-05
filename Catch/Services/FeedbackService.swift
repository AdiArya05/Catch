import Foundation
import Security

struct FeedbackPost: Decodable, Identifiable {
    let id: UUID
    let body: String
    let status: String
    let developer_response: String?
    let created_at: String
    let upvote_count: Int?
    let did_upvote: Bool?
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
                data = try await request("auth/v1/token?grant_type=refresh_token", method: "POST", body: ["refresh_token": refresh], retryTransientFailures: true)
            } catch Failure.http(let status) where status == 400 || status == 401 {
                // A revoked/expired anonymous session must not permanently brick feedback.
                SecItemDelete(keychainQuery as CFDictionary)
                data = try await request("auth/v1/signup", method: "POST", body: [:], retryTransientFailures: true)
            }
        } else {
            data = try await request("auth/v1/signup", method: "POST", body: [:], retryTransientFailures: true)
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
    private func request(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        bearer: String? = nil,
        retryTransientFailures: Bool = false
    ) async throws -> Data {
        guard let (base, key) = config,
              let url = URL(string: base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + path) else { throw Failure.unavailable }
        var req = URLRequest(url: url); req.httpMethod = method; req.timeoutInterval = 20
        req.setValue(key, forHTTPHeaderField: "apikey")
        if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body); req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let attempts = retryTransientFailures ? 2 : 1
        for attempt in 0..<attempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse else { throw Failure.server }
                if (200..<300).contains(http.statusCode) { return data }
                if retryTransientFailures, attempt == 0, (500..<600).contains(http.statusCode) {
                    try? await Task.sleep(for: .milliseconds(350))
                    continue
                }
                throw Failure.http(http.statusCode)
            } catch let failure as Failure {
                if retryTransientFailures, attempt == 0, case .server = failure {
                    try? await Task.sleep(for: .milliseconds(350))
                    continue
                }
                throw failure
            } catch {
                if retryTransientFailures, attempt == 0 {
                    try? await Task.sleep(for: .milliseconds(350))
                    continue
                }
                throw Failure.server
            }
        }
        throw Failure.server
    }

    private func authenticatedRequest(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        retryTransientFailures: Bool = false
    ) async throws -> Data {
        var bearer = try await authenticate()
        do {
            return try await request(
                path,
                method: method,
                body: body,
                bearer: bearer,
                retryTransientFailures: retryTransientFailures
            )
        } catch Failure.http(let status) where status == 401 {
            // Access tokens can be revoked before their advertised expiry. Refresh the
            // anonymous session once instead of leaving the board stuck until relaunch.
            token = nil
            expiry = .distantPast
            bearer = try await authenticate()
            return try await request(
                path,
                method: method,
                body: body,
                bearer: bearer,
                retryTransientFailures: retryTransientFailures
            )
        }
    }
    func posts() async throws -> [FeedbackPost] {
        let data = try await authenticatedRequest(
            "rest/v1/rpc/feedback_feed",
            method: "POST",
            body: [:],
            retryTransientFailures: true
        )
        guard let posts = try? JSONDecoder().decode([FeedbackPost].self, from: data) else { throw Failure.server }
        return posts
    }
    func submit(_ body: String, id: UUID) async throws {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (10...4000).contains(trimmed.count) else { throw Failure.invalid }
        _ = try await authenticatedRequest(
            "rest/v1/rpc/submit_feedback",
            method: "POST",
            body: ["message": trimmed, "request_id": id.uuidString],
            retryTransientFailures: true
        )
    }

    func toggleUpvote(postID: UUID) async throws {
        _ = try await authenticatedRequest(
            "rest/v1/rpc/toggle_feedback_upvote",
            method: "POST",
            body: ["feedback_id": postID.uuidString]
        )
    }

    func registerLiveActivity(
        activityID: String,
        pushToken: String,
        stopCode: String,
        serviceNo: String,
        progressStartedAt: Date,
        environment: String
    ) async throws {
        let bearer = try await authenticate()
        _ = try await request(
            "functions/v1/live-activity-refresh",
            method: "POST",
            body: [
                "action": "register",
                "activity_id": activityID,
                "push_token": pushToken,
                "stop_code": stopCode,
                "service_no": serviceNo,
                "progress_started_at": ISO8601DateFormatter().string(from: progressStartedAt),
                "environment": environment
            ],
            bearer: bearer
        )
    }

    func removeLiveActivity(activityID: String) async {
        guard let bearer = try? await authenticate() else { return }
        _ = try? await request(
            "functions/v1/live-activity-refresh",
            method: "POST",
            body: ["action": "remove", "activity_id": activityID],
            bearer: bearer
        )
    }
}

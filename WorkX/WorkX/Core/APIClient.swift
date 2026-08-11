//
//  APIClient.swift
//  WorkX
//

import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case server(String)
    case http(Int, String)
    case decode

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL không hợp lệ"
        case .server(let m): return m
        case .http(let c, let m): return "Lỗi \(c): \(m)"
        case .decode: return "Không đọc được phản hồi từ server"
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let defaults = UserDefaults.standard
    private let tokenKey = "workx.access_token"

    var accessToken: String? {
        get { defaults.string(forKey: tokenKey) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: tokenKey)
            } else {
                defaults.removeObject(forKey: tokenKey)
            }
        }
    }

    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        authorized: Bool = true
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: APIConfig.baseURL) else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if authorized, let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        if let envelope = try? JSONDecoder().decode(APIEnvelope<T>.self, from: data) {
            if status >= 400 || envelope.code >= 400 {
                let msg = envelope.message?.isEmpty == false
                    ? envelope.message!
                    : (String(data: data, encoding: .utf8) ?? "Request failed")
                throw APIError.server(msg)
            }
            guard let payload = envelope.data else {
                throw APIError.server(envelope.message ?? "Empty response")
            }
            return payload
        }

        // detail error from FastAPI
        if let err = try? JSONDecoder().decode(DetailError.self, from: data) {
            throw APIError.server(err.detail)
        }
        if status >= 400 {
            throw APIError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        throw APIError.decode
    }

    func login(username: String, password: String) async throws -> LoginData {
        try await request(
            path: "/api/v1/auth/login",
            method: "POST",
            body: LoginRequest(username: username, password: password),
            authorized: false
        )
    }

    func me() async throws -> MeData {
        try await request(path: "/api/v1/auth/me")
    }
}

private struct DetailError: Decodable {
    let detail: String
}

private struct AnyEncodable: Encodable {
    private let box: (Encoder) throws -> Void
    init(_ value: Encodable) { box = value.encode }
    func encode(to encoder: Encoder) throws { try box(encoder) }
}

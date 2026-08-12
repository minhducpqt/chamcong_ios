//
//  APIConfig.swift
//  WorkX
//

import Foundation

enum AppEnvironment: String, CaseIterable, Identifiable {
    case development
    case production

    var id: String { rawValue }

    var label: String {
        switch self {
        case .development: return "DEV"
        case .production: return "PROD"
        }
    }
}

enum APIConfig {
    private static let environmentKey = "workx.app_environment"

    /// Persisted; mặc định production (kể cả build DEBUG).
    static var environment: AppEnvironment {
        get {
            if let raw = UserDefaults.standard.string(forKey: environmentKey),
               let env = AppEnvironment(rawValue: raw) {
                return env
            }
            return .production
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: environmentKey)
        }
    }

    static var baseURL: URL {
        switch environment {
        case .development:
            // Simulator → máy host. Device thật: đổi sang IP máy chạy Backend.
            return URL(string: "http://localhost:8810")!
        case .production:
            return URL(string: "https://hr.vntechx.vn")!
        }
    }

    static var isProduction: Bool { environment == .production }

    /// Staff chỉ thấy nút Đăng xuất khi không phải production.
    static var showsLogoutForStaff: Bool { !isProduction }
}

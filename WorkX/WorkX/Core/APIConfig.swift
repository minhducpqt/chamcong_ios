//
//  APIConfig.swift
//  WorkX
//

import Foundation

enum APIConfig {
    /// Simulator → máy host. Device thật: đổi sang IP máy chạy Backend.
    static let baseURL = URL(string: "http://localhost:8810")!
}

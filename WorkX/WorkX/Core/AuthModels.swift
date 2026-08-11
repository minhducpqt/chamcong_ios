//
//  AuthModels.swift
//  WorkX
//

import Foundation

struct APIEnvelope<T: Decodable>: Decodable {
    let code: Int
    let data: T?
    let message: String?
}

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct LoginData: Decodable {
    let token: TokenPayload
    let user: Account
    let company: CompanyBrief?
}

struct TokenPayload: Decodable {
    let access_token: String
    let token_type: String?
    let expires_in: Int?
}

struct Account: Codable, Identifiable {
    let id: Int
    let company_id: Int?
    let username: String
    let username_local: String?
    let full_name: String
    let email: String?
    let phone: String?
    let role: String
    let is_active: Bool
}

struct CompanyBrief: Codable {
    let id: Int
    let company_code: String
    let name: String
    let is_active: Bool
}

struct MeData: Decodable {
    let user: Account
    let company: CompanyBrief?
}

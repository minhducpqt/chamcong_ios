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

struct Account: Codable, Identifiable, Hashable {
    let id: Int
    let company_id: Int?
    let username: String
    let username_local: String?
    let full_name: String
    let email: String?
    let phone: String?
    let role: String
    let is_active: Bool

    var roleLabel: String {
        switch role {
        case "super_admin": return "Super Admin"
        case "company_admin": return "Admin công ty"
        case "staff": return "Nhân viên"
        default: return role
        }
    }
}

struct CompanyBrief: Codable, Hashable {
    let id: Int
    let company_code: String
    let name: String
    let is_active: Bool
}

struct MeData: Decodable {
    let user: Account
    let company: CompanyBrief?
}

// MARK: - Company admin models

struct Company: Codable, Identifiable, Hashable {
    let id: Int
    let company_code: String
    let name: String
    let address: String?
    let phone: String?
    let email: String?
    let is_active: Bool
    let created_at: String?
    let updated_at: String?
}

struct CompanyDetail: Codable, Identifiable {
    let id: Int
    let company_code: String
    let name: String
    let address: String?
    let phone: String?
    let email: String?
    let is_active: Bool
    let created_at: String?
    let updated_at: String?
    let account_count: Int?
    // settings omitted (json object)
}

struct PagedData<T: Decodable>: Decodable {
    let data: [T]
    let page: Int
    let size: Int
    let total: Int
}

struct CompanyCreateRequest: Encodable {
    let company_code: String
    let name: String
    let address: String?
    let phone: String?
    let email: String?
    let admin_username_local: String?
    let admin_password: String?
    let admin_full_name: String?
}

struct AccountCreateRequest: Encodable {
    let username_local: String
    let password: String
    let full_name: String
    let role: String
    let email: String?
    let phone: String?
}

struct AccountUpdateRequest: Encodable {
    let full_name: String?
    let email: String?
    let phone: String?
    let role: String?
}

struct ChangePasswordRequest: Encodable {
    let new_password: String
}

enum AppRole {
    static let superAdmin = "super_admin"
    static let companyAdmin = "company_admin"
    static let staff = "staff"
}

// MARK: - Work shifts

struct WorkShift: Codable, Identifiable, Hashable {
    let id: Int
    let company_id: Int?
    let code: String
    let name: String
    let start_time: String
    let end_time: String
    let is_system: Bool
    let is_active: Bool
    let crosses_midnight: Bool?

    var timeLabel: String {
        let s = String(start_time.prefix(5))
        let e = String(end_time.prefix(5))
        return "\(s)–\(e)"
    }
}

struct WorkShiftCreateRequest: Encodable {
    let code: String
    let name: String
    let start_time: String
    let end_time: String
}

struct ApplyShiftAllRequest: Encodable {
    let shift_id: Int
    let from_date: String
    let note: String?
}

struct ApplyShiftAllResult: Decodable {
    let shift_id: Int
    let from_date: String
    let members_assigned: Int?
    let previous_assignments_closed: Int?
}

// MARK: - Company offices

struct OfficeIpNetwork: Codable, Identifiable, Hashable {
    let id: Int
    let office_id: Int
    let network: String
    let label: String?
    let is_active: Bool
}

struct CompanyOffice: Codable, Identifiable, Hashable {
    let id: Int
    let company_id: Int
    let name: String
    let address: String?
    let is_default: Bool
    let is_active: Bool
    let ips: [OfficeIpNetwork]?

    var ipCount: Int { ips?.count ?? 0 }
}

struct OfficeCreateRequest: Encodable {
    let name: String
    let address: String?
    let is_default: Bool
}

struct OfficeUpdateRequest: Encodable {
    let name: String?
    let address: String?
    let is_default: Bool?
    let is_active: Bool?
}

struct IpNetworkRequest: Encodable {
    let network: String
    let label: String?
}

struct ReplaceIpsRequest: Encodable {
    let networks: [IpNetworkRequest]
}

struct SetAccountOfficesRequest: Encodable {
    let office_ids: [Int]
}

struct AccountOfficesResult: Decodable {
    let account_id: Int
    let company_id: Int
    let office_ids: [Int]
    let offices: [CompanyOffice]?
}

struct DeleteIpResult: Decodable {
    let deleted: Bool?
    let id: Int?
}

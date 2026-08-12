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

struct MyIpData: Decodable {
    let ip: String
    let is_public: Bool
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
    let auto_assigned_default: Bool?
}

struct ApplyDefaultOfficeResult: Decodable {
    let office_id: Int
    let office: CompanyOffice
    let members_updated: Int
}

struct DeleteIpResult: Decodable {
    let deleted: Bool?
    let id: Int?
}

// MARK: - Attendance

struct AttendanceCheckRequest: Encodable {
    let source: String
}

struct AttendanceOfficeBrief: Codable, Hashable {
    let id: Int
    let name: String
}

struct AttendancePunch: Codable, Identifiable, Hashable {
    let id: Int
    let punched_at: String
    let work_date: String
    let client_ip: String?
    let office_id: Int?
    let is_valid: Bool
    let source: String
}

struct DaySummary: Codable, Identifiable, Hashable {
    let date: String
    let weekday: Int
    let weekday_label: String
    let is_weekend: Bool
    let is_off: Bool
    let checkin_at: String?
    let checkout_at: String?
    let checkout_provisional: Bool
    let late_minutes: Int
    let early_minutes: Int
    let severity: String
    let office_name: String?
    let shift_name: String?
    let has_punch: Bool

    var id: String { date }

    var timeLabel: String {
        let cin = Self.shortTime(checkin_at)
        let cout = Self.shortTime(checkout_at)
        if cin == nil && cout == nil { return "—" }
        var out = "\(cin ?? "—") → \(cout ?? "—")"
        if checkout_provisional { out += " (tạm)" }
        return out
    }

    private static func shortTime(_ iso: String?) -> String? {
        guard let iso, iso.count >= 16 else { return nil }
        // 2026-08-12T08:05:00+07:00 → 08:05
        let start = iso.index(iso.startIndex, offsetBy: 11)
        let end = iso.index(start, offsetBy: 5)
        return String(iso[start..<end])
    }
}

struct MonthStats: Codable, Hashable {
    let year: Int
    let month: Int
    let late_days: Int
    let early_days: Int
    let total_late_minutes: Int
    let total_early_minutes: Int
}

struct AttendanceHistoryData: Codable {
    let days: [DaySummary]
    let month: MonthStats
    let timezone: String
}

struct AttendanceCheckData: Codable {
    let accepted: Bool
    let reason: String?
    let message: String?
    let client_ip: String?
    let office: AttendanceOfficeBrief?
    let punch: AttendancePunch?
    let today_summary: DaySummary?
}

struct WorkCalendarData: Codable, Hashable {
    let preset: String
    let off_weekdays: [Int]
    let half_day_off: [String: String]
    let weekday_convention: String?
}

struct WorkCalendarUpdateRequest: Encodable {
    let preset: String
    let off_weekdays: [Int]?
    let half_day_off: [String: String]?
}

// MARK: - Admin attendance overview

struct OfficeOverviewItem: Codable, Identifiable, Hashable {
    let office_id: Int
    let name: String
    let is_default: Bool
    let is_active: Bool
    let employee_count: Int
    let late_days: Int
    let early_days: Int
    let total_late_minutes: Int
    let total_early_minutes: Int
    let employees_with_late: Int
    let employees_with_early: Int
    let severity_hint: String

    var id: Int { office_id }

    var totalMinutes: Int { total_late_minutes + total_early_minutes }
}

struct AttendanceOverviewData: Codable {
    let days: Int
    let office_count: Int
    let offices: [OfficeOverviewItem]
}

struct OfficeBriefAdmin: Codable, Hashable {
    let id: Int
    let name: String
    let is_default: Bool
    let is_active: Bool
    let address: String?
}

struct OfficeAttendanceStats: Codable, Hashable {
    let late_days: Int
    let early_days: Int
    let total_late_minutes: Int
    let total_early_minutes: Int
    let employees_with_late: Int
    let employees_with_early: Int
    let employee_count: Int
}

struct EmployeeAttendanceRow: Codable, Identifiable, Hashable {
    let account_id: Int
    let full_name: String
    let username: String
    let role: String
    let late_days: Int
    let early_days: Int
    let total_late_minutes: Int
    let total_early_minutes: Int
    let severity: String
    let last_checkin_at: String?
    let last_checkout_at: String?

    var id: Int { account_id }

    var totalMinutes: Int { total_late_minutes + total_early_minutes }
}

struct OfficeAttendanceData: Codable {
    let office: OfficeBriefAdmin
    let stats: OfficeAttendanceStats
    let employees: [EmployeeAttendanceRow]
}

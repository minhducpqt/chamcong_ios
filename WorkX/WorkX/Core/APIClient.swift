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

        if let err = try? JSONDecoder().decode(DetailError.self, from: data) {
            throw APIError.server(err.detail)
        }
        if status >= 400 {
            throw APIError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        throw APIError.decode
    }

    // MARK: Auth

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

    /// IP external như backend nhìn thấy (dùng thêm nhanh IP trụ sở).
    func myIp() async throws -> MyIpData {
        try await request(path: "/api/v1/auth/my-ip")
    }

    /// Fallback khi backend trả IP private/loopback (dev local).
    func fetchPublicIpFallback() async throws -> String {
        guard let url = URL(string: "https://api.ipify.org") else {
            throw APIError.invalidURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let ip = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !ip.isEmpty else { throw APIError.server("Không lấy được IP") }
        return ip
    }

    // MARK: Super — companies

    func listCompanies(q: String? = nil) async throws -> PagedData<Company> {
        var path = "/api/v1/super/companies?page=1&size=100"
        if let q, !q.isEmpty {
            path += "&q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)"
        }
        return try await request(path: path)
    }

    func getCompany(id: Int) async throws -> CompanyDetail {
        try await request(path: "/api/v1/super/companies/\(id)")
    }

    func createCompany(_ body: CompanyCreateRequest) async throws -> CompanyDetail {
        try await request(path: "/api/v1/super/companies", method: "POST", body: body)
    }

    func enableCompany(id: Int) async throws -> Company {
        try await request(path: "/api/v1/super/companies/\(id)/enable", method: "POST")
    }

    func disableCompany(id: Int) async throws -> Company {
        try await request(path: "/api/v1/super/companies/\(id)/disable", method: "POST")
    }

    // MARK: Super — accounts trong cty

    func superListAccounts(companyId: Int, q: String? = nil) async throws -> PagedData<Account> {
        var path = "/api/v1/super/companies/\(companyId)/accounts?page=1&size=100"
        if let q, !q.isEmpty {
            path += "&q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)"
        }
        return try await request(path: path)
    }

    func superCreateAccount(companyId: Int, body: AccountCreateRequest) async throws -> Account {
        try await request(
            path: "/api/v1/super/companies/\(companyId)/accounts",
            method: "POST",
            body: body
        )
    }

    func superEnableAccount(id: Int) async throws -> Account {
        try await request(path: "/api/v1/super/accounts/\(id)/enable", method: "POST")
    }

    func superDisableAccount(id: Int) async throws -> Account {
        try await request(path: "/api/v1/super/accounts/\(id)/disable", method: "POST")
    }

    func superDeleteAccount(id: Int) async throws {
        let _: DeleteAccountResult = try await request(
            path: "/api/v1/super/accounts/\(id)",
            method: "DELETE"
        )
    }

    func superPurgeCompanyAccounts(companyId: Int) async throws -> PurgeAccountsResult {
        try await request(
            path: "/api/v1/super/companies/\(companyId)/accounts/purge",
            method: "DELETE"
        )
    }

    func superChangePassword(id: Int, newPassword: String) async throws -> Account {
        try await request(
            path: "/api/v1/super/accounts/\(id)/change-password",
            method: "POST",
            body: ChangePasswordRequest(new_password: newPassword)
        )
    }

    func superUpdateAccount(id: Int, body: AccountUpdateRequest) async throws -> Account {
        try await request(path: "/api/v1/super/accounts/\(id)", method: "PATCH", body: body)
    }

    // MARK: Company admin — accounts

    func companyListAccounts(q: String? = nil) async throws -> PagedData<Account> {
        var path = "/api/v1/company/accounts?page=1&size=100"
        if let q, !q.isEmpty {
            path += "&q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)"
        }
        return try await request(path: path)
    }

    func companyCreateAccount(body: AccountCreateRequest) async throws -> Account {
        try await request(path: "/api/v1/company/accounts", method: "POST", body: body)
    }

    func companyEnableAccount(id: Int) async throws -> Account {
        try await request(path: "/api/v1/company/accounts/\(id)/enable", method: "POST")
    }

    func companyDisableAccount(id: Int) async throws -> Account {
        try await request(path: "/api/v1/company/accounts/\(id)/disable", method: "POST")
    }

    func companyDeleteAccount(id: Int) async throws {
        let _: DeleteAccountResult = try await request(
            path: "/api/v1/company/accounts/\(id)",
            method: "DELETE"
        )
    }

    func companyChangePassword(id: Int, newPassword: String) async throws -> Account {
        try await request(
            path: "/api/v1/company/accounts/\(id)/change-password",
            method: "POST",
            body: ChangePasswordRequest(new_password: newPassword)
        )
    }

    func companyUpdateAccount(id: Int, body: AccountUpdateRequest) async throws -> Account {
        try await request(path: "/api/v1/company/accounts/\(id)", method: "PATCH", body: body)
    }

    func companyMe() async throws -> CompanyDetail {
        try await request(path: "/api/v1/company/me")
    }

    // MARK: Company admin — shifts

    func companyListShifts() async throws -> [WorkShift] {
        try await request(path: "/api/v1/company/shifts")
    }

    func companyListCustomShifts() async throws -> [WorkShift] {
        try await request(path: "/api/v1/company/shifts/custom")
    }

    func companyCreateShift(_ body: WorkShiftCreateRequest) async throws -> WorkShift {
        try await request(path: "/api/v1/company/shifts", method: "POST", body: body)
    }

    func companyApplyShiftAll(_ body: ApplyShiftAllRequest) async throws -> ApplyShiftAllResult {
        try await request(path: "/api/v1/company/shifts/apply-all", method: "POST", body: body)
    }

    // MARK: Super — shifts for a company

    func superListShifts(companyId: Int) async throws -> [WorkShift] {
        try await request(path: "/api/v1/super/companies/\(companyId)/shifts")
    }

    func superListCustomShifts(companyId: Int) async throws -> [WorkShift] {
        try await request(path: "/api/v1/super/companies/\(companyId)/shifts/custom")
    }

    func superCreateShift(companyId: Int, body: WorkShiftCreateRequest) async throws -> WorkShift {
        try await request(
            path: "/api/v1/super/companies/\(companyId)/shifts",
            method: "POST",
            body: body
        )
    }

    func superApplyShiftAll(companyId: Int, body: ApplyShiftAllRequest) async throws -> ApplyShiftAllResult {
        try await request(
            path: "/api/v1/super/companies/\(companyId)/shifts/apply-all",
            method: "POST",
            body: body
        )
    }

    // MARK: Company admin — offices

    func companyListOffices() async throws -> [CompanyOffice] {
        try await request(path: "/api/v1/company/offices")
    }

    func companyGetOffice(id: Int) async throws -> CompanyOffice {
        try await request(path: "/api/v1/company/offices/\(id)")
    }

    func companyCreateOffice(_ body: OfficeCreateRequest) async throws -> CompanyOffice {
        try await request(path: "/api/v1/company/offices", method: "POST", body: body)
    }

    func companyUpdateOffice(id: Int, body: OfficeUpdateRequest) async throws -> CompanyOffice {
        try await request(path: "/api/v1/company/offices/\(id)", method: "PATCH", body: body)
    }

    func companyDeactivateOffice(id: Int) async throws -> CompanyOffice {
        try await request(path: "/api/v1/company/offices/\(id)/deactivate", method: "POST")
    }

    func companyApplyDefaultOfficeAll() async throws -> ApplyDefaultOfficeResult {
        try await request(path: "/api/v1/company/offices/apply-default-all", method: "POST")
    }

    func companyAddOfficeIp(officeId: Int, body: IpNetworkRequest) async throws -> OfficeIpNetwork {
        try await request(path: "/api/v1/company/offices/\(officeId)/ips", method: "POST", body: body)
    }

    func companyReplaceOfficeIps(officeId: Int, body: ReplaceIpsRequest) async throws -> [OfficeIpNetwork] {
        try await request(path: "/api/v1/company/offices/\(officeId)/ips", method: "PUT", body: body)
    }

    func companyDeleteOfficeIp(officeId: Int, ipId: Int) async throws {
        let _: DeleteIpResult = try await request(
            path: "/api/v1/company/offices/\(officeId)/ips/\(ipId)",
            method: "DELETE"
        )
    }

    func companyGetAccountOffices(accountId: Int) async throws -> AccountOfficesResult {
        try await request(path: "/api/v1/company/accounts/\(accountId)/offices")
    }

    func companySetAccountOffices(accountId: Int, officeIds: [Int]) async throws -> AccountOfficesResult {
        try await request(
            path: "/api/v1/company/accounts/\(accountId)/offices",
            method: "PUT",
            body: SetAccountOfficesRequest(office_ids: officeIds)
        )
    }

    // MARK: Super — offices for a company

    func superListOffices(companyId: Int) async throws -> [CompanyOffice] {
        try await request(path: "/api/v1/super/companies/\(companyId)/offices")
    }

    func superApplyDefaultOfficeAll(companyId: Int) async throws -> ApplyDefaultOfficeResult {
        try await request(
            path: "/api/v1/super/companies/\(companyId)/offices/apply-default-all",
            method: "POST"
        )
    }

    func superGetOffice(companyId: Int, officeId: Int) async throws -> CompanyOffice {
        try await request(path: "/api/v1/super/companies/\(companyId)/offices/\(officeId)")
    }

    func superCreateOffice(companyId: Int, body: OfficeCreateRequest) async throws -> CompanyOffice {
        try await request(
            path: "/api/v1/super/companies/\(companyId)/offices",
            method: "POST",
            body: body
        )
    }

    func superUpdateOffice(companyId: Int, officeId: Int, body: OfficeUpdateRequest) async throws -> CompanyOffice {
        try await request(
            path: "/api/v1/super/companies/\(companyId)/offices/\(officeId)",
            method: "PATCH",
            body: body
        )
    }

    func superDeactivateOffice(companyId: Int, officeId: Int) async throws -> CompanyOffice {
        try await request(
            path: "/api/v1/super/companies/\(companyId)/offices/\(officeId)/deactivate",
            method: "POST"
        )
    }

    func superAddOfficeIp(companyId: Int, officeId: Int, body: IpNetworkRequest) async throws -> OfficeIpNetwork {
        try await request(
            path: "/api/v1/super/companies/\(companyId)/offices/\(officeId)/ips",
            method: "POST",
            body: body
        )
    }

    func superReplaceOfficeIps(companyId: Int, officeId: Int, body: ReplaceIpsRequest) async throws -> [OfficeIpNetwork] {
        try await request(
            path: "/api/v1/super/companies/\(companyId)/offices/\(officeId)/ips",
            method: "PUT",
            body: body
        )
    }

    func superDeleteOfficeIp(companyId: Int, officeId: Int, ipId: Int) async throws {
        let _: DeleteIpResult = try await request(
            path: "/api/v1/super/companies/\(companyId)/offices/\(officeId)/ips/\(ipId)",
            method: "DELETE"
        )
    }

    func superGetAccountOffices(companyId: Int, accountId: Int) async throws -> AccountOfficesResult {
        try await request(path: "/api/v1/super/companies/\(companyId)/accounts/\(accountId)/offices")
    }

    func superSetAccountOffices(companyId: Int, accountId: Int, officeIds: [Int]) async throws -> AccountOfficesResult {
        try await request(
            path: "/api/v1/super/companies/\(companyId)/accounts/\(accountId)/offices",
            method: "PUT",
            body: SetAccountOfficesRequest(office_ids: officeIds)
        )
    }

    // MARK: Attendance

    func attendanceCheck(source: String) async throws -> AttendanceCheckData {
        try await request(
            path: "/api/v1/company/attendance/check",
            method: "POST",
            body: AttendanceCheckRequest(source: source)
        )
    }

    func attendanceMe(days: Int = 30) async throws -> AttendanceHistoryData {
        try await request(path: "/api/v1/company/attendance/me?days=\(days)")
    }

    func companyAttendanceOverview(days: Int = 30) async throws -> AttendanceOverviewData {
        try await request(path: "/api/v1/company/attendance/overview?days=\(days)")
    }

    func companyAttendanceOffice(officeId: Int, days: Int = 30) async throws -> OfficeAttendanceData {
        try await request(path: "/api/v1/company/attendance/offices/\(officeId)?days=\(days)")
    }

    func companyAttendanceEmployee(accountId: Int, days: Int = 100) async throws -> AttendanceHistoryData {
        try await request(path: "/api/v1/company/attendance/employees/\(accountId)?days=\(days)")
    }

    func superAttendanceOverview(companyId: Int, days: Int = 30) async throws -> AttendanceOverviewData {
        try await request(
            path: "/api/v1/super/companies/\(companyId)/attendance/overview?days=\(days)"
        )
    }

    func superAttendanceOffice(
        companyId: Int, officeId: Int, days: Int = 30
    ) async throws -> OfficeAttendanceData {
        try await request(
            path: "/api/v1/super/companies/\(companyId)/attendance/offices/\(officeId)?days=\(days)"
        )
    }

    func superAttendanceEmployee(
        companyId: Int, accountId: Int, days: Int = 100
    ) async throws -> AttendanceHistoryData {
        try await request(
            path: "/api/v1/super/companies/\(companyId)/attendance/employees/\(accountId)?days=\(days)"
        )
    }

    func getWorkCalendar() async throws -> WorkCalendarData {
        try await request(path: "/api/v1/company/work-calendar")
    }

    func putWorkCalendar(_ body: WorkCalendarUpdateRequest) async throws -> WorkCalendarData {
        try await request(
            path: "/api/v1/company/work-calendar",
            method: "PUT",
            body: body
        )
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

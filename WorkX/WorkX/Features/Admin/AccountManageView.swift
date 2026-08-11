//
//  AccountManageView.swift
//  WorkX
//

import SwiftUI

enum AccountActionMode {
    case superAdmin
    case companyAdmin
}

struct AccountManageView: View {
    let account: Account
    let mode: AccountActionMode
    var onChanged: () -> Void

    @State private var current: Account
    @State private var fullName: String
    @State private var email: String
    @State private var phone: String
    @State private var role: String
    @State private var newPassword = ""
    @State private var message: String?
    @State private var error: String?
    @State private var loading = false

    init(account: Account, mode: AccountActionMode, onChanged: @escaping () -> Void) {
        self.account = account
        self.mode = mode
        self.onChanged = onChanged
        _current = State(initialValue: account)
        _fullName = State(initialValue: account.full_name)
        _email = State(initialValue: account.email ?? "")
        _phone = State(initialValue: account.phone ?? "")
        _role = State(initialValue: account.role)
    }

    var body: some View {
        Form {
            Section("Thông tin") {
                LabeledContent("Username", value: current.username)
                TextField("Họ tên", text: $fullName)
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                TextField("SĐT", text: $phone)
                Picker("Role", selection: $role) {
                    Text("Nhân viên").tag("staff")
                    Text("Admin cty").tag("company_admin")
                }
                LabeledContent("Trạng thái", value: current.is_active ? "Active" : "Disabled")
            }
            Section {
                Button("Lưu thông tin") { Task { await saveInfo() } }
                    .disabled(loading)
            }
            Section("Mật khẩu") {
                SecureField("Mật khẩu mới (min 6)", text: $newPassword)
                Button("Đổi mật khẩu") { Task { await changePassword() } }
                    .disabled(loading || newPassword.count < 6)
            }
            Section("Trạng thái TK") {
                if current.is_active {
                    Button("Disable tài khoản", role: .destructive) {
                        Task { await setActive(false) }
                    }
                } else {
                    Button("Enable tài khoản") {
                        Task { await setActive(true) }
                    }
                }
            }
            if let message {
                Text(message).foregroundStyle(.green)
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
        }
        .navigationTitle(current.username)
    }

    private func saveInfo() async {
        loading = true
        defer { loading = false }
        let body = AccountUpdateRequest(
            full_name: fullName,
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            role: role
        )
        do {
            switch mode {
            case .superAdmin:
                current = try await APIClient.shared.superUpdateAccount(id: current.id, body: body)
            case .companyAdmin:
                current = try await APIClient.shared.companyUpdateAccount(id: current.id, body: body)
            }
            message = "Đã lưu"
            error = nil
            onChanged()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func changePassword() async {
        loading = true
        defer { loading = false }
        do {
            switch mode {
            case .superAdmin:
                current = try await APIClient.shared.superChangePassword(id: current.id, newPassword: newPassword)
            case .companyAdmin:
                current = try await APIClient.shared.companyChangePassword(id: current.id, newPassword: newPassword)
            }
            newPassword = ""
            message = "Đã đổi mật khẩu"
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func setActive(_ enable: Bool) async {
        loading = true
        defer { loading = false }
        do {
            switch mode {
            case .superAdmin:
                current = enable
                    ? try await APIClient.shared.superEnableAccount(id: current.id)
                    : try await APIClient.shared.superDisableAccount(id: current.id)
            case .companyAdmin:
                current = enable
                    ? try await APIClient.shared.companyEnableAccount(id: current.id)
                    : try await APIClient.shared.companyDisableAccount(id: current.id)
            }
            message = enable ? "Đã enable" : "Đã disable"
            error = nil
            onChanged()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

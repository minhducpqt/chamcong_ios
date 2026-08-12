//
//  CreateAccountView.swift
//  WorkX
//

import SwiftUI

enum AccountManageMode {
    case superAdmin(companyId: Int)
    case companyAdmin
}

struct CreateAccountView: View {
    let mode: AccountManageMode
    var onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var local = ""
    @State private var fullName = ""
    @State private var password = "User@123"
    @State private var role = "staff"
    @State private var email = ""
    @State private var phone = ""
    @State private var error: String?
    @State private var loading = false

    private let roles = ["staff", "company_admin"]

    var body: some View {
        Form {
            Section("Tài khoản") {
                TextField("username local (vd: trangnt)", text: $local)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("Full login: {company_code}.\(local.isEmpty ? "..." : local)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Họ tên", text: $fullName)
                SecureField("Mật khẩu", text: $password)
                Picker("Vai trò", selection: $role) {
                    ForEach(roles, id: \.self) { r in
                        Text(r == "staff" ? "Nhân viên" : "Admin cty").tag(r)
                    }
                }
            }
            Section("Liên hệ") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("SĐT", text: $phone)
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
        }
        .navigationTitle("Tạo tài khoản")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Huỷ") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Tạo") { Task { await submit() } }
                    .disabled(loading || local.isEmpty || fullName.isEmpty || password.count < 6)
            }
        }
    }

    private func submit() async {
        loading = true
        defer { loading = false }
        let body = AccountCreateRequest(
            username_local: local.trimmingCharacters(in: .whitespaces).lowercased(),
            password: password,
            full_name: fullName.trimmingCharacters(in: .whitespaces),
            role: role,
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone
        )
        do {
            switch mode {
            case .superAdmin(let companyId):
                _ = try await APIClient.shared.superCreateAccount(companyId: companyId, body: body)
            case .companyAdmin:
                _ = try await APIClient.shared.companyCreateAccount(body: body)
            }
            onCreated()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

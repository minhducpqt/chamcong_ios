//
//  CreateCompanyView.swift
//  WorkX
//

import SwiftUI

struct CreateCompanyView: View {
    var onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var adminLocal = "admin"
    @State private var adminPassword = "Admin@123"
    @State private var adminName = ""
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        Form {
            Section("Công ty") {
                TextField("Mã (vd: kinhdo)", text: $code)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Tên công ty", text: $name)
                TextField("Địa chỉ", text: $address)
                TextField("SĐT", text: $phone)
            }
            Section("Admin đầu tiên (tuỳ chọn)") {
                TextField("username local → code.local", text: $adminLocal)
                    .textInputAutocapitalization(.never)
                SecureField("Mật khẩu admin", text: $adminPassword)
                TextField("Họ tên admin", text: $adminName)
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
        }
        .navigationTitle("Tạo công ty")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Huỷ") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Tạo") {
                    Task { await submit() }
                }
                .disabled(loading || code.isEmpty || name.isEmpty)
            }
        }
    }

    private func submit() async {
        loading = true
        defer { loading = false }
        let local = adminLocal.trimmingCharacters(in: .whitespaces)
        let body = CompanyCreateRequest(
            company_code: code.trimmingCharacters(in: .whitespaces).lowercased(),
            name: name.trimmingCharacters(in: .whitespaces),
            address: address.isEmpty ? nil : address,
            phone: phone.isEmpty ? nil : phone,
            email: nil,
            admin_username_local: local.isEmpty ? nil : local,
            admin_password: local.isEmpty ? nil : adminPassword,
            admin_full_name: adminName.isEmpty ? nil : adminName
        )
        do {
            _ = try await APIClient.shared.createCompany(body)
            onCreated()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

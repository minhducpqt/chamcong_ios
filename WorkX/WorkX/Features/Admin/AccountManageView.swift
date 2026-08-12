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
    @Environment(\.dismiss) private var dismiss

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
    @State private var showDeleteConfirm = false
    @State private var deleteConfirmText = ""

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
                Picker("Vai trò", selection: $role) {
                    Text("Nhân viên").tag("staff")
                    Text("Admin cty").tag("company_admin")
                }
                LabeledContent("Trạng thái", value: current.is_active ? "Hoạt động" : "Đã tắt")
            }
            Section {
                Button("Lưu thông tin") { Task { await saveInfo() } }
                    .disabled(loading)
            }
            Section("Trụ sở") {
                NavigationLink {
                    OfficeAssignView(account: current, mode: mode) {
                        message = "Đã gán trụ sở"
                        error = nil
                    }
                } label: {
                    Label("Gán trụ sở", systemImage: "building.2")
                }
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
                    Button("Xóa vĩnh viễn", role: .destructive) {
                        deleteConfirmText = ""
                        showDeleteConfirm = true
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
        .sheet(isPresented: $showDeleteConfirm) {
            DeleteAccountConfirmSheet(
                username: current.username,
                confirmText: $deleteConfirmText,
                isDeleting: loading,
                onCancel: {
                    showDeleteConfirm = false
                    deleteConfirmText = ""
                },
                onConfirm: {
                    Task { await deleteAccount() }
                }
            )
        }
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

    private func deleteAccount() async {
        loading = true
        defer { loading = false }
        do {
            switch mode {
            case .superAdmin:
                try await APIClient.shared.superDeleteAccount(id: current.id)
            case .companyAdmin:
                try await APIClient.shared.companyDeleteAccount(id: current.id)
            }
            showDeleteConfirm = false
            deleteConfirmText = ""
            onChanged()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct DeleteAccountConfirmSheet: View {
    let username: String
    @Binding var confirmText: String
    let isDeleting: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var canConfirm: Bool {
        confirmText.trimmingCharacters(in: .whitespacesAndNewlines) == "xoa"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Tài khoản \(username) sẽ bị xóa vĩnh viễn. Thao tác không thể hoàn tác.")
                }
                Section("Xác nhận") {
                    TextField("Nhập xoa", text: $confirmText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                }
            }
            .navigationTitle("Xóa tài khoản")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xóa", role: .destructive, action: onConfirm)
                        .disabled(!canConfirm || isDeleting)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

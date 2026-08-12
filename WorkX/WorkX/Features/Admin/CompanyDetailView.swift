//
//  CompanyDetailView.swift
//  WorkX — Super: chi tiết cty + tài khoản bên trong
//

import SwiftUI

struct CompanyDetailView: View {
    let companyId: Int

    @State private var company: CompanyDetail?
    @State private var accounts: [Account] = []
    @State private var errorMessage: String?
    @State private var showCreateAccount = false
    @State private var showPurgeConfirm = false
    @State private var toast: String?

    var body: some View {
        List {
            if let company {
                Section("Thông tin") {
                    LabeledContent("Mã", value: company.company_code)
                    LabeledContent("Tên", value: company.name)
                    if let a = company.address { LabeledContent("Địa chỉ", value: a) }
                    if let p = company.phone { LabeledContent("SĐT", value: p) }
                    LabeledContent("Trạng thái", value: company.is_active ? "Hoạt động" : "Đã tắt")
                    LabeledContent("Số TK", value: "\(company.account_count ?? accounts.count)")
                }
                Section("Thao tác cty") {
                    NavigationLink {
                        ShiftManageView(mode: .superAdmin(companyId: companyId))
                    } label: {
                        Label("Quản lý ca làm việc", systemImage: "clock")
                    }
                    NavigationLink {
                        OfficeManageView(mode: .superAdmin(companyId: companyId))
                    } label: {
                        Label("Quản lý trụ sở", systemImage: "building")
                    }
                    Button(company.is_active ? "Disable công ty" : "Enable công ty") {
                        Task { await toggleCompany(enable: !company.is_active) }
                    }
                    .foregroundStyle(company.is_active ? .red : .green)

                    Button("Xoá toàn bộ tài khoản", role: .destructive) {
                        showPurgeConfirm = true
                    }
                }
            }

            Section("Tài khoản") {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                ForEach(accounts) { acc in
                    NavigationLink {
                        AccountManageView(
                            account: acc,
                            mode: .superAdmin,
                            onChanged: { Task { await load() } }
                        )
                    } label: {
                        AccountRow(account: acc)
                    }
                }
            }
        }
        .navigationTitle(company?.company_code ?? "Công ty")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateAccount = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showCreateAccount) {
            NavigationStack {
                CreateAccountView(mode: .superAdmin(companyId: companyId)) {
                    showCreateAccount = false
                    Task { await load() }
                }
            }
        }
        .sheet(isPresented: $showPurgeConfirm) {
            PurgeCompanyAccountsSheet(companyId: companyId) {
                showPurgeConfirm = false
                toast = "Đã xoá \($0) tài khoản"
                Task { await load() }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
    }

    private func load() async {
        do {
            company = try await APIClient.shared.getCompany(id: companyId)
            let page = try await APIClient.shared.superListAccounts(companyId: companyId)
            accounts = page.data
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleCompany(enable: Bool) async {
        do {
            if enable {
                _ = try await APIClient.shared.enableCompany(id: companyId)
            } else {
                _ = try await APIClient.shared.disableCompany(id: companyId)
            }
            toast = enable ? "Đã enable cty" : "Đã disable cty"
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PurgeCompanyAccountsSheet: View {
    let companyId: Int
    var onPurged: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmText = ""
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)

                Text("Xoá toàn bộ tài khoản")
                    .font(.title2.bold())

                Text("Thao tác này sẽ xoá vĩnh viễn tất cả tài khoản của công ty. Không thể hoàn tác.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Gõ **xoa** để xác nhận")
                    .font(.footnote)

                TextField("Nhập xoa", text: $confirmText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let error {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }

                Button(role: .destructive) {
                    Task { await purge() }
                } label: {
                    Group {
                        if loading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Xác nhận xoá tất cả")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(confirmText.trimmingCharacters(in: .whitespaces).lowercased() != "xoa" || loading)

                Spacer()
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
            }
        }
    }

    private func purge() async {
        loading = true
        defer { loading = false }
        do {
            let result = try await APIClient.shared.superPurgeCompanyAccounts(companyId: companyId)
            onPurged(result.deleted ?? 0)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct AccountRow: View {
    let account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(account.full_name).font(.headline)
                Spacer()
                Text(account.is_active ? "Hoạt động" : "Tắt")
                    .font(.caption2)
                    .foregroundStyle(account.is_active ? .green : .secondary)
            }
            Text("\(account.username) · \(account.roleLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

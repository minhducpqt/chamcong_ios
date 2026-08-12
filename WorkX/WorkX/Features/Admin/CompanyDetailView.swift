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
    @State private var toast: String?

    var body: some View {
        List {
            if let company {
                Section("Thông tin") {
                    LabeledContent("Mã", value: company.company_code)
                    LabeledContent("Tên", value: company.name)
                    if let a = company.address { LabeledContent("Địa chỉ", value: a) }
                    if let p = company.phone { LabeledContent("SĐT", value: p) }
                    LabeledContent("Trạng thái", value: company.is_active ? "Active" : "Disabled")
                    LabeledContent("Số TK", value: "\(company.account_count ?? accounts.count)")
                }
                Section("Thao tác cty") {
                    NavigationLink {
                        ShiftManageView(mode: .superAdmin(companyId: companyId))
                    } label: {
                        Label("Quản lý ca làm việc", systemImage: "clock")
                    }
                    Button(company.is_active ? "Disable công ty" : "Enable công ty") {
                        Task { await toggleCompany(enable: !company.is_active) }
                    }
                    .foregroundStyle(company.is_active ? .red : .green)
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

struct AccountRow: View {
    let account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(account.full_name).font(.headline)
                Spacer()
                Text(account.is_active ? "On" : "Off")
                    .font(.caption2)
                    .foregroundStyle(account.is_active ? .green : .secondary)
            }
            Text("\(account.username) · \(account.roleLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

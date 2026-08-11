//
//  CompanyAccountsView.swift
//  WorkX — Company admin: quản lý TK trong cty
//

import SwiftUI

struct CompanyAccountsView: View {
    @State private var accounts: [Account] = []
    @State private var company: CompanyDetail?
    @State private var query = ""
    @State private var errorMessage: String?
    @State private var showCreate = false

    var body: some View {
        List {
            if let company {
                Section("Công ty") {
                    LabeledContent("Mã", value: company.company_code)
                    LabeledContent("Tên", value: company.name)
                    LabeledContent("Số TK", value: "\(company.account_count ?? accounts.count)")
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
                            mode: .companyAdmin,
                            onChanged: { Task { await load() } }
                        )
                    } label: {
                        AccountRow(account: acc)
                    }
                }
            }
        }
        .navigationTitle("Tài khoản cty")
        .searchable(text: $query, prompt: "Tìm username / tên")
        .onChange(of: query) { _, _ in Task { await load() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                CreateAccountView(mode: .companyAdmin) {
                    showCreate = false
                    Task { await load() }
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        do {
            company = try? await APIClient.shared.companyMe()
            let page = try await APIClient.shared.companyListAccounts(q: query.isEmpty ? nil : query)
            accounts = page.data
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

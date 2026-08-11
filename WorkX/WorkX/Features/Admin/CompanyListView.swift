//
//  CompanyListView.swift
//  WorkX — Super admin: danh sách công ty
//

import SwiftUI

struct CompanyListView: View {
    @State private var items: [Company] = []
    @State private var query = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showCreate = false

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            ForEach(items) { c in
                NavigationLink(value: c) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(c.name).font(.headline)
                            Spacer()
                            Text(c.is_active ? "Active" : "Off")
                                .font(.caption)
                                .foregroundStyle(c.is_active ? .green : .secondary)
                        }
                        Text(c.company_code)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Công ty")
        .navigationDestination(for: Company.self) { c in
            CompanyDetailView(companyId: c.id)
        }
        .searchable(text: $query, prompt: "Tìm mã / tên")
        .onChange(of: query) { _, _ in
            Task { await load() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                CreateCompanyView {
                    showCreate = false
                    Task { await load() }
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .overlay { if isLoading && items.isEmpty { ProgressView() } }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await APIClient.shared.listCompanies(q: query.isEmpty ? nil : query)
            items = page.data
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

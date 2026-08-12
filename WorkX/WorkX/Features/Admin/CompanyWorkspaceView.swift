//
//  CompanyWorkspaceView.swift
//  WorkX — Super admin: push vào công ty (tổng quan chấm công, quản lý qua navigation)
//

import SwiftUI

struct CompanyWorkspaceView: View {
    let companyId: Int

    @State private var companyName: String?

    var body: some View {
        AdminOverviewView(
            mode: .superAdmin(companyId: companyId),
            navigationTitle: companyName ?? "Công ty"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CompanyDetailView(companyId: companyId)
                } label: {
                    Label("Quản lý", systemImage: "gearshape.2")
                }
            }
        }
        .task { await loadCompanyName() }
    }

    private func loadCompanyName() async {
        do {
            let detail = try await APIClient.shared.getCompany(id: companyId)
            companyName = detail.name
        } catch {
            companyName = nil
        }
    }
}

//
//  CompanyWorkspaceView.swift
//  WorkX — Super admin: workspace sau khi chọn công ty
//

import SwiftUI

struct CompanyWorkspaceView: View {
    let companyId: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            NavigationStack {
                AdminOverviewView(mode: .superAdmin(companyId: companyId))
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                dismiss()
                            } label: {
                                Label("Công ty", systemImage: "chevron.backward")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Tổng quan", systemImage: "chart.bar.fill")
            }

            NavigationStack {
                CompanyDetailView(companyId: companyId)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                dismiss()
                            } label: {
                                Label("Công ty", systemImage: "chevron.backward")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Quản lý", systemImage: "gearshape.2.fill")
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

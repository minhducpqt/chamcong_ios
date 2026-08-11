//
//  HomeView.swift
//  WorkX
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        NavigationStack {
            List {
                if let user = session.user {
                    Section("Tài khoản") {
                        LabeledContent("Họ tên", value: user.full_name)
                        LabeledContent("Username", value: user.username)
                        LabeledContent("Role", value: user.role)
                        if let local = user.username_local {
                            LabeledContent("Local", value: local)
                        }
                    }
                }
                if let company = session.company {
                    Section("Công ty") {
                        LabeledContent("Mã", value: company.company_code)
                        LabeledContent("Tên", value: company.name)
                        LabeledContent("Trạng thái", value: company.is_active ? "Active" : "Disabled")
                    }
                } else if session.user?.role == "super_admin" {
                    Section("Công ty") {
                        Text("Super admin — không thuộc công ty")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("WorkX")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đăng xuất", role: .destructive) {
                        session.logout()
                    }
                }
            }
            .task {
                if session.user == nil {
                    await session.restoreSession()
                }
            }
        }
    }
}

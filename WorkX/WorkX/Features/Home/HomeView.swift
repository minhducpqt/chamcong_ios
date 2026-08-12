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
                    Section("Tài khoản của bạn") {
                        LabeledContent("Họ tên", value: user.full_name)
                        LabeledContent("Username", value: user.username)
                        LabeledContent("Vai trò", value: user.roleLabel)
                    }
                }

                if let company = session.company {
                    Section("Công ty") {
                        LabeledContent("Mã", value: company.company_code)
                        LabeledContent("Tên", value: company.name)
                    }
                }

                Section("Quản lý") {
                    if session.user?.role == AppRole.superAdmin {
                        Text("Chọn tab Công ty để xem danh sách và theo dõi chấm công từng công ty.")
                            .foregroundStyle(.secondary)
                    } else if session.user?.role == AppRole.companyAdmin {
                        NavigationLink {
                            CompanyAccountsView()
                        } label: {
                            Label("Quản lý tài khoản công ty", systemImage: "person.3")
                        }
                        NavigationLink {
                            ShiftManageView(mode: .companyAdmin)
                        } label: {
                            Label("Quản lý ca làm việc", systemImage: "clock")
                        }
                        NavigationLink {
                            OfficeManageView(mode: .companyAdmin)
                        } label: {
                            Label("Quản lý trụ sở", systemImage: "building")
                        }
                        NavigationLink {
                            WorkCalendarView()
                        } label: {
                            Label("Lịch làm việc", systemImage: "calendar")
                        }
                    } else if session.user?.role == AppRole.staff {
                        Text("Dùng tab Chấm công để check-in/out.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Nhân viên chưa có quyền quản trị.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(session.user?.role == AppRole.superAdmin ? "Cài đặt" : "Tài khoản")
            .toolbar {
                if session.user?.role != AppRole.staff || APIConfig.showsLogoutForStaff {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Đăng xuất", role: .destructive) {
                            session.logout()
                        }
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

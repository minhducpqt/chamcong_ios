//
//  ContentView.swift
//  WorkX
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            if session.isLoggedIn {
                if session.user?.role == AppRole.companyAdmin {
                    TabView {
                        NavigationStack {
                            AdminOverviewView(mode: .companyAdmin)
                        }
                        .tabItem {
                            Label("Tổng quan", systemImage: "chart.bar.fill")
                        }
                        CheckView()
                            .tabItem {
                                Label("Check", systemImage: "hand.tap.fill")
                            }
                        HomeView()
                            .tabItem {
                                Label("Tài khoản", systemImage: "person.crop.circle")
                            }
                    }
                } else if session.user?.role == AppRole.staff {
                    TabView {
                        CheckView()
                            .tabItem {
                                Label("Chấm công", systemImage: "hand.tap.fill")
                            }
                        HomeView()
                            .tabItem {
                                Label("Tài khoản", systemImage: "person.crop.circle")
                            }
                    }
                } else if session.user?.role == AppRole.superAdmin {
                    TabView {
                        NavigationStack {
                            CompanyListView()
                        }
                        .tabItem {
                            Label("Công ty", systemImage: "building.2")
                        }
                        HomeView()
                            .tabItem {
                                Label("Cài đặt", systemImage: "gearshape.fill")
                            }
                    }
                } else {
                    HomeView()
                }
            } else {
                LoginView()
            }
        }
        .task {
            await session.restoreSession()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionStore())
}

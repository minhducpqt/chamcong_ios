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
                if isCompanyUser {
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

    private var isCompanyUser: Bool {
        let role = session.user?.role
        return role == AppRole.companyAdmin || role == AppRole.staff
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionStore())
}

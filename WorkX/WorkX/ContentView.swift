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
                HomeView()
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

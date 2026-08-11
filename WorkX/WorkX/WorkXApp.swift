//
//  WorkXApp.swift
//  WorkX
//

import SwiftUI

@main
struct WorkXApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
    }
}

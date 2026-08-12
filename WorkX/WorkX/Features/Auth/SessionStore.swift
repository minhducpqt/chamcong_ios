//
//  SessionStore.swift
//  WorkX
//

import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    @Published var isLoggedIn = false
    @Published var user: Account?
    @Published var company: CompanyBrief?
    @Published var errorMessage: String?
    @Published var isLoading = false

    init() {
        isLoggedIn = APIClient.shared.accessToken != nil
    }

    func login(username: String, password: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let data = try await APIClient.shared.login(
                username: trimmed,
                password: password
            )
            APIClient.shared.accessToken = data.token.access_token
            user = data.user
            company = data.company
            isLoggedIn = true
            SavedAccountsStore.upsert(username: trimmed, password: password)
        } catch {
            errorMessage = error.localizedDescription
            isLoggedIn = false
        }
    }

    func restoreSession() async {
        guard APIClient.shared.accessToken != nil else {
            isLoggedIn = false
            return
        }
        do {
            let data = try await APIClient.shared.me()
            user = data.user
            company = data.company
            isLoggedIn = true
        } catch {
            logout()
        }
    }

    func logout() {
        APIClient.shared.accessToken = nil
        user = nil
        company = nil
        isLoggedIn = false
    }
}

//
//  SavedAccountsStore.swift
//  WorkX
//

import Foundation

struct SavedAccount: Codable, Identifiable, Hashable {
    var id: String { username }
    let username: String
    let password: String

    var maskedHint: String {
        guard !password.isEmpty else { return "" }
        let n = min(password.count, 8)
        return String(repeating: "•", count: n)
    }
}

enum SavedAccountsStore {
    private static let key = "workx.saved_accounts"
    private static let maxCount = 10

    static func load() -> [SavedAccount] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SavedAccount].self, from: data)) ?? []
    }

    /// Upsert by username, newest first, max 10.
    static func upsert(username: String, password: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = load().filter { $0.username.caseInsensitiveCompare(trimmed) != .orderedSame }
        list.insert(SavedAccount(username: trimmed, password: password), at: 0)
        if list.count > maxCount {
            list = Array(list.prefix(maxCount))
        }
        persist(list)
    }

    private static func persist(_ list: [SavedAccount]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

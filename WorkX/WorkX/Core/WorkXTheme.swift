//
//  WorkXTheme.swift
//  WorkX — brand colors aligned with app icon
//

import SwiftUI

enum WorkXTheme {
    static let brandBlue = Color(red: 46 / 255, green: 141 / 255, blue: 232 / 255)

    static let fieldBackground = Color(.secondarySystemBackground)
    static let cardCornerRadius: CGFloat = 12
}

enum WorkXTimeFormat {
    private static let posix = Locale(identifier: "en_US_POSIX")

    static func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = posix
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func date(from timeString: String, defaultHour: Int = 8, defaultMinute: Int = 0) -> Date {
        let f = DateFormatter()
        f.locale = posix
        f.dateFormat = "HH:mm"
        if let d = f.date(from: timeString) { return d }
        return Calendar.current.date(
            bySettingHour: defaultHour,
            minute: defaultMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }
}

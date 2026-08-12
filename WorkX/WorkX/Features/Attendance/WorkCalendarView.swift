//
//  WorkCalendarView.swift
//  WorkX
//

import SwiftUI

struct WorkCalendarView: View {
    @State private var preset: String = "off_sat_sun"
    @State private var loading = false
    @State private var saving = false
    @State private var message: String?
    @State private var errorText: String?

    private let presets: [(id: String, title: String, detail: String)] = [
        ("off_sat_sun", "Nghỉ T7 + CN", "Cả ngày thứ 7 và Chủ nhật"),
        ("off_sat_afternoon_sun", "T7 chiều + CN", "Thứ 7 nghỉ chiều, Chủ nhật nghỉ cả ngày"),
        ("off_sun_only", "Chỉ nghỉ CN", "Làm việc thứ 7, nghỉ Chủ nhật"),
        ("custom", "Tuỳ chỉnh", "Dùng cấu hình tùy chỉnh trên server"),
    ]

    var body: some View {
        Form {
            Section {
                ForEach(presets, id: \.id) { item in
                    Button {
                        preset = item.id
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).foregroundStyle(.primary)
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if preset == item.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            } header: {
                Text("Preset lịch làm việc")
            } footer: {
                Text("Weekday: Thứ 2=0 … CN=6 (Python).")
            }

            if let message {
                Section { Text(message).foregroundStyle(.green) }
            }
            if let errorText {
                Section { Text(errorText).foregroundStyle(.red) }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if saving {
                        ProgressView()
                    } else {
                        Text("Lưu")
                    }
                }
                .disabled(saving || loading)
            }
        }
        .navigationTitle("Lịch làm việc")
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let data = try await APIClient.shared.getWorkCalendar()
            preset = data.preset
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func save() async {
        saving = true
        message = nil
        errorText = nil
        defer { saving = false }
        do {
            let data = try await APIClient.shared.putWorkCalendar(
                WorkCalendarUpdateRequest(preset: preset, off_weekdays: nil, half_day_off: nil)
            )
            preset = data.preset
            message = "Đã lưu lịch làm việc."
        } catch {
            errorText = error.localizedDescription
        }
    }
}

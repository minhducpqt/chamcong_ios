//
//  CheckView.swift
//  WorkX
//

import SwiftUI

struct CheckView: View {
    @State private var history: AttendanceHistoryData?
    @State private var today: DaySummary?
    @State private var loading = false
    @State private var checking = false
    @State private var errorText: String?
    @State private var successText: String?
    @State private var showFailAlert = false
    @State private var failMessage = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await manualCheck() }
                    } label: {
                        HStack {
                            Spacer()
                            if checking {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Label("Chấm công", systemImage: "hand.tap.fill")
                                    .font(.title2.bold())
                            }
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 18)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                    .disabled(checking)
                }

                if let today {
                    Section("Hôm nay") {
                        LabeledContent("Vào", value: timeOnly(today.checkin_at) ?? "—")
                        HStack {
                            Text("Ra")
                            Spacer()
                            Text(timeOnly(today.checkout_at) ?? "—")
                            if today.checkout_provisional {
                                Text("tạm tính")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.25), in: Capsule())
                            }
                        }
                        if let office = today.office_name {
                            LabeledContent("Trụ sở", value: office)
                        }
                        if let shift = today.shift_name {
                            LabeledContent("Ca", value: shift)
                        }
                    }
                }

                if let month = history?.month {
                    Section("Tháng \(month.month)/\(month.year)") {
                        HStack(spacing: 8) {
                            statChip("Muộn", "\(month.late_days) ngày")
                            statChip("Sớm", "\(month.early_days) ngày")
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                        HStack(spacing: 8) {
                            statChip("Phút muộn", "\(month.total_late_minutes)")
                            statChip("Phút sớm", "\(month.total_early_minutes)")
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                if let errorText {
                    Section {
                        Text(errorText).foregroundStyle(.red)
                    }
                }
                if let successText {
                    Section {
                        Text(successText).foregroundStyle(.green)
                    }
                }

                Section("30 ngày gần đây") {
                    if loading && history == nil {
                        ProgressView()
                    } else if let days = history?.days {
                        ForEach(days.reversed()) { day in
                            dayRow(day)
                        }
                    }
                }
            }
            .navigationTitle("Chấm công")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        LeaveMyRequestsView()
                    } label: {
                        Label("Đơn nghỉ", systemImage: "calendar.badge.clock")
                    }
                }
            }
            .refreshable { await loadHistory() }
            .task {
                await autoCheck()
                await loadHistory()
            }
            .alert("Không thể chấm công", isPresented: $showFailAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failMessage)
            }
        }
    }

    @ViewBuilder
    private func dayRow(_ day: DaySummary) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.weekday_label).font(.headline)
                Text(day.date).font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 72, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(day.timeLabel)
                if day.late_minutes > 0 || day.early_minutes > 0 {
                    Text("Muộn \(day.late_minutes)' · Sớm \(day.early_minutes)'")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .listRowBackground(rowBackground(day))
    }

    private func rowBackground(_ day: DaySummary) -> Color {
        if day.is_weekend {
            return Color.blue.opacity(0.12)
        }
        switch day.severity {
        case "ok": return Color.green.opacity(0.18)
        case "light": return Color.yellow.opacity(0.25)
        case "medium": return Color.yellow.opacity(0.55)
        case "high": return Color.orange.opacity(0.55)
        case "critical": return Color.red.opacity(0.45)
        default: return Color.clear
        }
    }

    private func statChip(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func timeOnly(_ iso: String?) -> String? {
        guard let iso, iso.count >= 16 else { return nil }
        let start = iso.index(iso.startIndex, offsetBy: 11)
        let end = iso.index(start, offsetBy: 5)
        return String(iso[start..<end])
    }

    private func autoCheck() async {
        do {
            let result = try await APIClient.shared.attendanceCheck(source: "auto")
            if result.accepted {
                today = result.today_summary
            } else if let summary = result.today_summary {
                today = summary
            }
            // IP fail → silent
        } catch {
            // silent for auto
        }
    }

    private func manualCheck() async {
        checking = true
        errorText = nil
        successText = nil
        defer { checking = false }
        do {
            let result = try await APIClient.shared.attendanceCheck(source: "manual")
            today = result.today_summary
            if result.accepted {
                successText = result.message ?? "Chấm công thành công."
                await loadHistory()
            } else {
                failMessage = result.message ?? "IP không hợp lệ."
                if let ip = result.client_ip, !ip.isEmpty, !failMessage.contains(ip) {
                    failMessage = "\(failMessage)\nIP: \(ip)"
                }
                showFailAlert = true
            }
        } catch {
            failMessage = error.localizedDescription
            showFailAlert = true
        }
    }

    private func loadHistory() async {
        loading = true
        defer { loading = false }
        do {
            let data = try await APIClient.shared.attendanceMe(days: 30)
            history = data
            if let last = data.days.last {
                today = last
            }
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}

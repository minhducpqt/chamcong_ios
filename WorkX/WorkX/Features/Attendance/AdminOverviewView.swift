//
//  AdminOverviewView.swift
//  WorkX — Company / super admin: tổng quan kỷ luật chấm công
//

import SwiftUI

enum AdminAttendanceMode: Hashable {
    case companyAdmin
    case superAdmin(companyId: Int)
}

struct AdminOverviewView: View {
    let mode: AdminAttendanceMode
    var navigationTitle: String = "Tổng quan"

    @State private var overview: AttendanceOverviewData?
    @State private var loading = false
    @State private var errorText: String?

    var body: some View {
        Group {
            if loading && overview == nil {
                ProgressView("Đang tải…")
            } else if let overview {
                if overview.office_count <= 1, let only = overview.offices.first {
                    OfficeAttendanceDetailView(
                        mode: mode,
                        officeId: only.office_id,
                        embedded: true
                    )
                } else {
                    officeList(overview)
                }
            } else if let errorText {
                ContentUnavailableView(
                    "Lỗi",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorText)
                )
            } else {
                ContentUnavailableView("Chưa có dữ liệu", systemImage: "building.2")
            }
        }
        .navigationTitle(navigationTitle)
        .refreshable { await load() }
        .task { await load() }
    }

    @ViewBuilder
    private func officeList(_ overview: AttendanceOverviewData) -> some View {
        List {
            Section {
                Text("\(overview.days) ngày gần đây · \(overview.office_count) trụ sở")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let errorText {
                Section { Text(errorText).foregroundStyle(.red) }
            }
            Section("Trụ sở") {
                ForEach(overview.offices) { office in
                    NavigationLink {
                        OfficeAttendanceDetailView(mode: mode, officeId: office.office_id)
                    } label: {
                        officeRow(office)
                    }
                    .listRowBackground(
                        AttendanceUI.severityBackground(office.severity_hint)
                    )
                }
            }
        }
    }

    private func officeRow(_ office: OfficeOverviewItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(office.name).font(.headline)
                if office.is_default {
                    Text("Mặc định")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
                Spacer()
                Text("\(office.employee_count) NV")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label("Muộn \(office.late_days)", systemImage: "clock.badge.exclamationmark")
                Label("Sớm \(office.early_days)", systemImage: "figure.walk")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("\(office.totalMinutes) phút muộn+sớm · \(office.employees_with_late) NV muộn")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            switch mode {
            case .companyAdmin:
                overview = try await APIClient.shared.companyAttendanceOverview(days: 30)
            case .superAdmin(let companyId):
                overview = try await APIClient.shared.superAttendanceOverview(
                    companyId: companyId, days: 30
                )
            }
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Office detail

struct OfficeAttendanceDetailView: View {
    let mode: AdminAttendanceMode
    let officeId: Int
    var embedded: Bool = false

    @State private var data: OfficeAttendanceData?
    @State private var loading = false
    @State private var errorText: String?

    var body: some View {
        List {
            if let data {
                Section("Tóm tắt \(embedded ? "30 ngày" : "")") {
                    statsBlock(data.stats)
                }
                Section("Nhân viên (\(data.stats.employee_count))") {
                    ForEach(data.employees) { emp in
                        NavigationLink {
                            EmployeeAttendanceDetailView(
                                mode: mode,
                                accountId: emp.account_id,
                                title: emp.full_name
                            )
                        } label: {
                            employeeRow(emp)
                        }
                        .listRowBackground(AttendanceUI.severityBackground(emp.severity))
                    }
                }
            }
            if let errorText {
                Section { Text(errorText).foregroundStyle(.red) }
            }
            if loading && data == nil {
                ProgressView()
            }
        }
        .navigationTitle(data?.office.name ?? (embedded ? "Tổng quan" : "Trụ sở"))
        .navigationBarTitleDisplayMode(embedded ? .large : .inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private func statsBlock(_ stats: OfficeAttendanceStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AttendanceUI.statChip("Muộn", "\(stats.late_days) ngày")
                AttendanceUI.statChip("Sớm", "\(stats.early_days) ngày")
            }
            HStack(spacing: 8) {
                AttendanceUI.statChip("Phút muộn", "\(stats.total_late_minutes)")
                AttendanceUI.statChip("Phút sớm", "\(stats.total_early_minutes)")
            }
            Text("\(stats.employees_with_late) NV muộn · \(stats.employees_with_early) NV sớm")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private func employeeRow(_ emp: EmployeeAttendanceRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(emp.full_name).font(.headline)
            Text(emp.username)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Text("Muộn \(emp.late_days)")
                Text("Sớm \(emp.early_days)")
                Text("\(emp.totalMinutes)'")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            switch mode {
            case .companyAdmin:
                data = try await APIClient.shared.companyAttendanceOffice(
                    officeId: officeId, days: 30
                )
            case .superAdmin(let companyId):
                data = try await APIClient.shared.superAttendanceOffice(
                    companyId: companyId, officeId: officeId, days: 30
                )
            }
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Employee history

struct EmployeeAttendanceDetailView: View {
    let mode: AdminAttendanceMode
    let accountId: Int
    let title: String

    @State private var history: AttendanceHistoryData?
    @State private var loading = false
    @State private var errorText: String?

    var body: some View {
        List {
            if let month = history?.month {
                Section("Cửa sổ gần đây") {
                    HStack(spacing: 8) {
                        AttendanceUI.statChip("Muộn", "\(month.late_days) ngày")
                        AttendanceUI.statChip("Sớm", "\(month.early_days) ngày")
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    HStack(spacing: 8) {
                        AttendanceUI.statChip("Phút muộn", "\(month.total_late_minutes)")
                        AttendanceUI.statChip("Phút sớm", "\(month.total_early_minutes)")
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                }
            }
            if let errorText {
                Section { Text(errorText).foregroundStyle(.red) }
            }
            Section("Lịch sử (tối đa 100 ngày)") {
                if loading && history == nil {
                    ProgressView()
                } else if let days = history?.days {
                    ForEach(days.reversed()) { day in
                        AttendanceUI.dayRow(day)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            switch mode {
            case .companyAdmin:
                history = try await APIClient.shared.companyAttendanceEmployee(
                    accountId: accountId, days: 100
                )
            case .superAdmin(let companyId):
                history = try await APIClient.shared.superAttendanceEmployee(
                    companyId: companyId, accountId: accountId, days: 100
                )
            }
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Shared UI helpers

enum AttendanceUI {
    static func severityBackground(_ severity: String, isWeekend: Bool = false) -> Color {
        if isWeekend { return Color.blue.opacity(0.12) }
        switch severity {
        case "ok": return Color.green.opacity(0.18)
        case "light": return Color.yellow.opacity(0.25)
        case "medium": return Color.yellow.opacity(0.55)
        case "high": return Color.orange.opacity(0.55)
        case "critical": return Color.red.opacity(0.45)
        default: return Color.clear
        }
    }

    static func statChip(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    static func dayRow(_ day: DaySummary) -> some View {
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
        .listRowBackground(severityBackground(day.severity, isWeekend: day.is_weekend))
    }
}

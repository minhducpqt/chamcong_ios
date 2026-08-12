//
//  LeaveRequestViews.swift
//  WorkX — Đơn xin nghỉ phép
//

import SwiftUI

// MARK: - Staff: my requests

struct LeaveMyRequestsView: View {
    @State private var requests: [LeaveRequest] = []
    @State private var loading = false
    @State private var error: String?
    @State private var message: String?
    @State private var showCreate = false

    var body: some View {
        List {
            if let error {
                Text(error).foregroundStyle(.red)
            }
            if let message {
                Text(message).foregroundStyle(.green)
            }
            if loading && requests.isEmpty {
                ProgressView()
            }
            ForEach(requests) { req in
                LeaveRequestRow(req: req)
                if req.status == "pending" {
                    Button("Huỷ đơn", role: .destructive) {
                        Task { await cancel(req.id) }
                    }
                }
            }
        }
        .navigationTitle("Đơn xin nghỉ")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                CreateLeaveRequestSheet {
                    showCreate = false
                    Task { await load() }
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let page = try await APIClient.shared.myLeaveRequests()
            requests = page.data
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func cancel(_ id: Int) async {
        do {
            _ = try await APIClient.shared.cancelLeaveRequest(id: id)
            message = "Đã huỷ đơn"
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Admin: approve requests

struct LeaveApprovalView: View {
    @State private var requests: [LeaveRequest] = []
    @State private var filterPending = true
    @State private var loading = false
    @State private var error: String?
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Toggle("Chỉ đơn chờ duyệt", isOn: $filterPending)
                    .onChange(of: filterPending) { _, _ in Task { await load() } }
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
            if let message {
                Text(message).foregroundStyle(.green)
            }
            if loading && requests.isEmpty {
                ProgressView()
            }
            ForEach(requests) { req in
                VStack(alignment: .leading, spacing: 6) {
                    LeaveRequestRow(req: req, showEmployee: true)
                    if req.status == "pending" {
                        HStack {
                            Button("Duyệt") {
                                Task { await approve(req.id) }
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Từ chối", role: .destructive) {
                                Task { await reject(req.id) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Duyệt đơn nghỉ")
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let page = try await APIClient.shared.companyLeaveRequests(
                status: filterPending ? "pending" : nil
            )
            requests = page.data
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func approve(_ id: Int) async {
        do {
            _ = try await APIClient.shared.approveLeaveRequest(id: id)
            message = "Đã duyệt đơn"
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func reject(_ id: Int) async {
        do {
            _ = try await APIClient.shared.rejectLeaveRequest(id: id)
            message = "Đã từ chối đơn"
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Shared row

private struct LeaveRequestRow: View {
    let req: LeaveRequest
    var showEmployee: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(req.leave_date)
                    .font(.headline)
                Spacer()
                Text(req.statusLabel)
                    .font(.caption)
                    .foregroundStyle(statusColor(req.status))
            }
            Text(req.timeRangeLabel)
                .font(.subheadline)
            if showEmployee {
                Text(req.account_full_name ?? req.account_username ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let reason = req.reason, !reason.isEmpty {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "approved": return .green
        case "rejected": return .red
        case "cancelled": return .secondary
        default: return .orange
        }
    }
}

// MARK: - Create sheet

private struct CreateLeaveRequestSheet: View {
    var onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var leaveType = "full_day"
    @State private var leaveDate = Date()
    @State private var startTime = WorkXTimeFormat.date(from: "08:00")
    @State private var endTime = WorkXTimeFormat.date(from: "12:00")
    @State private var reason = ""
    @State private var loading = false
    @State private var error: String?

    private let types: [(String, String)] = [
        ("morning", "Nghỉ sáng"),
        ("afternoon", "Nghỉ chiều"),
        ("full_day", "Nghỉ cả ngày"),
        ("hours", "Nghỉ theo giờ"),
    ]

    var body: some View {
        Form {
            Section("Loại nghỉ") {
                Picker("Loại", selection: $leaveType) {
                    ForEach(types, id: \.0) { t in
                        Text(t.1).tag(t.0)
                    }
                }
                .pickerStyle(.inline)
                DatePicker("Ngày nghỉ", selection: $leaveDate, displayedComponents: .date)
                if leaveType == "hours" {
                    DatePicker("Từ", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Đến", selection: $endTime, displayedComponents: .hourAndMinute)
                }
            }
            Section("Lý do") {
                TextField("Ghi chú (tuỳ chọn)", text: $reason, axis: .vertical)
                    .lineLimit(3...6)
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
        }
        .navigationTitle("Tạo đơn nghỉ")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Huỷ") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Gửi") { Task { await submit() } }
                    .disabled(loading)
            }
        }
    }

    private func submit() async {
        loading = true
        defer { loading = false }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let body = LeaveRequestCreateBody(
            leave_type: leaveType,
            leave_date: dateFormatter.string(from: leaveDate),
            start_time: leaveType == "hours" ? WorkXTimeFormat.timeString(from: startTime) : nil,
            end_time: leaveType == "hours" ? WorkXTimeFormat.timeString(from: endTime) : nil,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reason
        )
        do {
            _ = try await APIClient.shared.createLeaveRequest(body)
            onCreated()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

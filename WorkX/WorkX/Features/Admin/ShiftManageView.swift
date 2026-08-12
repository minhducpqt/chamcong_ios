//
//  ShiftManageView.swift
//  WorkX — Quản lý ca làm việc (company admin / super admin)
//

import SwiftUI

enum ShiftManageMode {
    case companyAdmin
    case superAdmin(companyId: Int)

    var companyId: Int? {
        if case .superAdmin(let id) = self { return id }
        return nil
    }
}

struct ShiftManageView: View {
    let mode: ShiftManageMode

    @State private var shifts: [WorkShift] = []
    @State private var errorMessage: String?
    @State private var toast: String?
    @State private var isLoading = false
    @State private var showCreate = false
    @State private var showApply = false

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            Section("Ca hệ thống") {
                ForEach(shifts.filter(\.is_system)) { s in
                    ShiftRow(shift: s)
                }
            }
            Section("Ca custom") {
                let custom = shifts.filter { !$0.is_system }
                if custom.isEmpty {
                    Text("Chưa có ca custom").foregroundStyle(.secondary)
                } else {
                    ForEach(custom) { s in
                        ShiftRow(shift: s)
                    }
                }
            }
        }
        .navigationTitle("Ca làm việc")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Tạo ca custom") { showCreate = true }
                    Button("Áp dụng toàn công ty") { showApply = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                CreateShiftSheet(mode: mode) {
                    showCreate = false
                    Task { await load() }
                }
            }
        }
        .sheet(isPresented: $showApply) {
            NavigationStack {
                ApplyShiftAllSheet(mode: mode, shifts: shifts) { msg in
                    showApply = false
                    toast = msg
                    Task { await load() }
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .overlay {
            if isLoading && shifts.isEmpty { ProgressView() }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.toast = nil
                        }
                    }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            switch mode {
            case .companyAdmin:
                shifts = try await APIClient.shared.companyListShifts()
            case .superAdmin(let companyId):
                shifts = try await APIClient.shared.superListShifts(companyId: companyId)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ShiftRow: View {
    let shift: WorkShift

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(shift.name).font(.headline)
                Spacer()
                if !shift.is_active {
                    Text("Tắt").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text("\(shift.code) · \(shift.timeLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CreateShiftSheet: View {
    let mode: ShiftManageMode
    var onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var name = ""
    @State private var startTime = WorkXTimeFormat.date(from: "08:00")
    @State private var endTime = WorkXTimeFormat.date(from: "17:00")
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        Form {
            Section("Thông tin ca") {
                TextField("Mã (vd: custom_a)", text: $code)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Tên ca", text: $name)
                DatePicker("Bắt đầu", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("Kết thúc", selection: $endTime, displayedComponents: .hourAndMinute)
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
        }
        .navigationTitle("Tạo ca custom")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Huỷ") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Tạo") { Task { await submit() } }
                    .disabled(loading || code.isEmpty || name.isEmpty)
            }
        }
    }

    private func submit() async {
        loading = true
        defer { loading = false }
        let body = WorkShiftCreateRequest(
            code: code.trimmingCharacters(in: .whitespacesAndNewlines),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            start_time: WorkXTimeFormat.timeString(from: startTime),
            end_time: WorkXTimeFormat.timeString(from: endTime)
        )
        do {
            switch mode {
            case .companyAdmin:
                _ = try await APIClient.shared.companyCreateShift(body)
            case .superAdmin(let companyId):
                _ = try await APIClient.shared.superCreateShift(companyId: companyId, body: body)
            }
            onCreated()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct ApplyShiftAllSheet: View {
    let mode: ShiftManageMode
    let shifts: [WorkShift]
    var onDone: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedId: Int?
    @State private var fromDate = Date()
    @State private var note = ""
    @State private var error: String?
    @State private var loading = false

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    var body: some View {
        Form {
            Section("Chọn ca") {
                Picker("Ca", selection: $selectedId) {
                    Text("— chọn —").tag(Optional<Int>.none)
                    ForEach(shifts.filter(\.is_active)) { s in
                        Text("\(s.name) (\(s.timeLabel))").tag(Optional(s.id))
                    }
                }
                DatePicker("Từ ngày", selection: $fromDate, displayedComponents: .date)
                TextField("Ghi chú", text: $note)
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
        }
        .navigationTitle("Áp dụng toàn công ty")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Huỷ") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Áp dụng") { Task { await submit() } }
                    .disabled(loading || selectedId == nil)
            }
        }
        .onAppear {
            if selectedId == nil {
                selectedId = shifts.first(where: { $0.is_active })?.id
            }
        }
    }

    private func submit() async {
        guard let selectedId else { return }
        loading = true
        defer { loading = false }
        let body = ApplyShiftAllRequest(
            shift_id: selectedId,
            from_date: dateFormatter.string(from: fromDate),
            note: note.isEmpty ? nil : note
        )
        do {
            let result: ApplyShiftAllResult
            switch mode {
            case .companyAdmin:
                result = try await APIClient.shared.companyApplyShiftAll(body)
            case .superAdmin(let companyId):
                result = try await APIClient.shared.superApplyShiftAll(companyId: companyId, body: body)
            }
            let n = result.members_assigned ?? 0
            onDone("Đã apply cho \(n) người")
        } catch {
            self.error = error.localizedDescription
        }
    }
}

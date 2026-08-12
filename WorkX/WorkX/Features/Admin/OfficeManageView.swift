//
//  OfficeManageView.swift
//  WorkX — Quản lý trụ sở (company admin / super admin)
//

import SwiftUI

enum OfficeManageMode {
    case companyAdmin
    case superAdmin(companyId: Int)

    var companyId: Int? {
        if case .superAdmin(let id) = self { return id }
        return nil
    }
}

struct OfficeManageView: View {
    let mode: OfficeManageMode

    @State private var offices: [CompanyOffice] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showCreate = false

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            Section("Trụ sở") {
                if offices.isEmpty && !isLoading {
                    Text("Chưa có trụ sở").foregroundStyle(.secondary)
                }
                ForEach(offices) { o in
                    NavigationLink {
                        OfficeDetailView(mode: mode, officeId: o.id)
                    } label: {
                        OfficeRow(office: o)
                    }
                }
            }
        }
        .navigationTitle("Trụ sở")
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
                CreateOfficeSheet(mode: mode) {
                    showCreate = false
                    Task { await load() }
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .overlay {
            if isLoading && offices.isEmpty { ProgressView() }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            switch mode {
            case .companyAdmin:
                offices = try await APIClient.shared.companyListOffices()
            case .superAdmin(let companyId):
                offices = try await APIClient.shared.superListOffices(companyId: companyId)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct OfficeRow: View {
    let office: CompanyOffice

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(office.name).font(.headline)
                if office.is_default {
                    Text("Mặc định")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                if !office.is_active {
                    Text("Off").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text("\(office.ipCount) IP · \(office.address ?? "Không có địa chỉ")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CreateOfficeSheet: View {
    let mode: OfficeManageMode
    var onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var isDefault = false
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        Form {
            Section("Thông tin") {
                TextField("Tên toà nhà / trụ sở", text: $name)
                TextField("Địa chỉ (tuỳ chọn)", text: $address)
                Toggle("Đặt làm mặc định", isOn: $isDefault)
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
        }
        .navigationTitle("Tạo trụ sở")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Huỷ") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Tạo") { Task { await submit() } }
                    .disabled(loading || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func submit() async {
        loading = true
        defer { loading = false }
        let body = OfficeCreateRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : address.trimmingCharacters(in: .whitespacesAndNewlines),
            is_default: isDefault
        )
        do {
            switch mode {
            case .companyAdmin:
                _ = try await APIClient.shared.companyCreateOffice(body)
            case .superAdmin(let companyId):
                _ = try await APIClient.shared.superCreateOffice(companyId: companyId, body: body)
            }
            onCreated()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct OfficeDetailView: View {
    let mode: OfficeManageMode
    let officeId: Int

    @State private var office: CompanyOffice?
    @State private var name = ""
    @State private var address = ""
    @State private var isDefault = false
    @State private var ips: [OfficeIpNetwork] = []
    @State private var newNetwork = ""
    @State private var newLabel = ""
    @State private var error: String?
    @State private var message: String?
    @State private var loading = false

    var body: some View {
        Form {
            Section("Thông tin") {
                TextField("Tên", text: $name)
                TextField("Địa chỉ", text: $address)
                Toggle("Mặc định", isOn: $isDefault)
                if let office, !office.is_active {
                    Text("Đã tắt").foregroundStyle(.secondary)
                }
            }
            Section("IP / CIDR") {
                ForEach(ips) { ip in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ip.network)
                            if let label = ip.label, !label.isEmpty {
                                Text(label).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            Task { await deleteIp(ip.id) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                TextField("IP hoặc CIDR", text: $newNetwork)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Nhãn (tuỳ chọn)", text: $newLabel)
                Button("Thêm IP") { Task { await addIp() } }
                    .disabled(newNetwork.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section {
                Button("Lưu") { Task { await save() } }
                    .disabled(loading || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if office?.is_active == true {
                    Button("Deactivate", role: .destructive) {
                        Task { await deactivate() }
                    }
                }
            }
            if let message {
                Text(message).foregroundStyle(.green)
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
        }
        .navigationTitle(office?.name ?? "Trụ sở")
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let o: CompanyOffice
            switch mode {
            case .companyAdmin:
                o = try await APIClient.shared.companyGetOffice(id: officeId)
            case .superAdmin(let companyId):
                o = try await APIClient.shared.superGetOffice(companyId: companyId, officeId: officeId)
            }
            office = o
            name = o.name
            address = o.address ?? ""
            isDefault = o.is_default
            ips = o.ips ?? []
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func save() async {
        loading = true
        defer { loading = false }
        let body = OfficeUpdateRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : address.trimmingCharacters(in: .whitespacesAndNewlines),
            is_default: isDefault,
            is_active: nil
        )
        do {
            let o: CompanyOffice
            switch mode {
            case .companyAdmin:
                o = try await APIClient.shared.companyUpdateOffice(id: officeId, body: body)
            case .superAdmin(let companyId):
                o = try await APIClient.shared.superUpdateOffice(
                    companyId: companyId, officeId: officeId, body: body
                )
            }
            office = o
            ips = o.ips ?? ips
            message = "Đã lưu"
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deactivate() async {
        do {
            let o: CompanyOffice
            switch mode {
            case .companyAdmin:
                o = try await APIClient.shared.companyDeactivateOffice(id: officeId)
            case .superAdmin(let companyId):
                o = try await APIClient.shared.superDeactivateOffice(
                    companyId: companyId, officeId: officeId
                )
            }
            office = o
            message = "Đã deactivate"
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func addIp() async {
        let body = IpNetworkRequest(
            network: newNetwork.trimmingCharacters(in: .whitespacesAndNewlines),
            label: newLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            let row: OfficeIpNetwork
            switch mode {
            case .companyAdmin:
                row = try await APIClient.shared.companyAddOfficeIp(officeId: officeId, body: body)
            case .superAdmin(let companyId):
                row = try await APIClient.shared.superAddOfficeIp(
                    companyId: companyId, officeId: officeId, body: body
                )
            }
            ips.append(row)
            newNetwork = ""
            newLabel = ""
            message = "Đã thêm IP"
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteIp(_ ipId: Int) async {
        do {
            switch mode {
            case .companyAdmin:
                try await APIClient.shared.companyDeleteOfficeIp(officeId: officeId, ipId: ipId)
            case .superAdmin(let companyId):
                try await APIClient.shared.superDeleteOfficeIp(
                    companyId: companyId, officeId: officeId, ipId: ipId
                )
            }
            ips.removeAll { $0.id == ipId }
            message = "Đã xoá IP"
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Multi-select gán trụ sở cho 1 account
struct OfficeAssignView: View {
    let account: Account
    let mode: AccountActionMode
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var offices: [CompanyOffice] = []
    @State private var selected: Set<Int> = []
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        List {
            if let error {
                Text(error).foregroundStyle(.red)
            }
            Section("Chọn trụ sở") {
                ForEach(offices.filter(\.is_active)) { o in
                    Toggle(isOn: Binding(
                        get: { selected.contains(o.id) },
                        set: { on in
                            if on { selected.insert(o.id) } else { selected.remove(o.id) }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(o.name)
                            if let addr = o.address {
                                Text(addr).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Gán trụ sở")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu") { Task { await save() } }
                    .disabled(loading)
            }
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let companyId = account.company_id
            switch mode {
            case .companyAdmin:
                offices = try await APIClient.shared.companyListOffices()
                let cur = try await APIClient.shared.companyGetAccountOffices(accountId: account.id)
                selected = Set(cur.office_ids)
            case .superAdmin:
                guard let companyId else {
                    error = "Account không thuộc công ty"
                    return
                }
                offices = try await APIClient.shared.superListOffices(companyId: companyId)
                let cur = try await APIClient.shared.superGetAccountOffices(
                    companyId: companyId, accountId: account.id
                )
                selected = Set(cur.office_ids)
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func save() async {
        loading = true
        defer { loading = false }
        let ids = Array(selected).sorted()
        do {
            switch mode {
            case .companyAdmin:
                _ = try await APIClient.shared.companySetAccountOffices(
                    accountId: account.id, officeIds: ids
                )
            case .superAdmin:
                guard let companyId = account.company_id else {
                    error = "Account không thuộc công ty"
                    return
                }
                _ = try await APIClient.shared.superSetAccountOffices(
                    companyId: companyId, accountId: account.id, officeIds: ids
                )
            }
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

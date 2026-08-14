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
    @State private var showResetConfirm = false
    @State private var resetCode = ""
    @State private var resetMessage: String?
    @State private var isResetting = false

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            if let resetMessage {
                Text(resetMessage).foregroundStyle(.green)
            }
            Section {
                Button(role: .destructive) {
                    resetCode = ""
                    showResetConfirm = true
                } label: {
                    Label("Reset: gán trụ sở chính cho tất cả NV", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(offices.first(where: { $0.is_default }) == nil)
            } footer: {
                Text("Mọi nhân viên sẽ chỉ còn trụ sở master hiện tại. Cần gõ 123 để xác nhận.")
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
        .sheet(isPresented: $showResetConfirm) {
            NavigationStack {
                Form {
                    if let master = offices.first(where: { $0.is_default }) {
                        Section {
                            Text("Gán \"\(master.name)\" cho toàn bộ nhân viên. Mọi gán trụ sở cũ sẽ bị thay thế.")
                        }
                    }
                    Section("Xác nhận") {
                        TextField("Gõ 123 để xác nhận", text: $resetCode)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
                .navigationTitle("Reset trụ sở")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Huỷ") { showResetConfirm = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Reset") {
                            Task { await applyDefaultAll() }
                        }
                        .disabled(resetCode != "123" || isResetting)
                        .foregroundStyle(.red)
                    }
                }
            }
            .presentationDetents([.medium])
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

    private func applyDefaultAll() async {
        guard resetCode == "123" else {
            errorMessage = "Gõ đúng 123 để xác nhận"
            return
        }
        isResetting = true
        defer { isResetting = false }
        do {
            let result: ApplyDefaultOfficeResult
            switch mode {
            case .companyAdmin:
                result = try await APIClient.shared.companyApplyDefaultOfficeAll()
            case .superAdmin(let companyId):
                result = try await APIClient.shared.superApplyDefaultOfficeAll(companyId: companyId)
            }
            resetMessage = "Đã gán \"\(result.office.name)\" cho \(result.members_updated) nhân sự"
            errorMessage = nil
            showResetConfirm = false
            resetCode = ""
            await load()
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
                    Text("Tắt").font(.caption2).foregroundStyle(.secondary)
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

    private enum IpConfirmAction {
        case addManual
        case addCurrent
        case delete(Int)
    }

    @State private var office: CompanyOffice?
    @State private var name = ""
    @State private var address = ""
    @State private var isDefault = false
    @State private var ips: [OfficeIpNetwork] = []
    @State private var newNetwork = ""
    @State private var newLabel = ""
    @State private var currentIp: String?
    @State private var currentIpPublic = false
    @State private var currentIpLoading = false
    @State private var error: String?
    @State private var message: String?
    @State private var loading = false
    @State private var ipConfirmAction: IpConfirmAction?
    @State private var showIpConfirm = false

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
                            ipConfirmAction = .delete(ip.id)
                            showIpConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("IP hiện tại")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Làm mới") { Task { await loadCurrentIp() } }
                            .font(.caption)
                            .disabled(currentIpLoading)
                    }
                    if currentIpLoading && currentIp == nil {
                        ProgressView()
                    } else if let currentIp, !currentIp.isEmpty {
                        Text(currentIp)
                            .font(.body.monospaced())
                        if !currentIpPublic {
                            Text("IP nội bộ/local — khi deploy server thật sẽ là IP WAN văn phòng.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Button("Thêm IP hiện tại") {
                            ipConfirmAction = .addCurrent
                            showIpConfirm = true
                        }
                        .disabled(ips.contains { $0.network == currentIp })
                    } else {
                        Text("Không lấy được IP").foregroundStyle(.secondary)
                    }
                }
                TextField("IP hoặc CIDR", text: $newNetwork)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Nhãn (tuỳ chọn)", text: $newLabel)
                Button("Thêm IP") {
                    ipConfirmAction = .addManual
                    showIpConfirm = true
                }
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
        .task {
            await load()
            await loadCurrentIp()
        }
        .alert(
            ipConfirmTitle,
            isPresented: $showIpConfirm,
            presenting: ipConfirmAction
        ) { action in
            Button("Huỷ", role: .cancel) {
                ipConfirmAction = nil
            }
            Button(
                ipConfirmButtonTitle(for: action),
                role: ipConfirmIsDestructive(action) ? .destructive : nil
            ) {
                Task { await performIpAction(action) }
            }
        } message: { action in
            Text(ipConfirmMessage(for: action))
        }
    }

    private var trimmedNewNetwork: String {
        newNetwork.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var ipConfirmTitle: String {
        guard let action = ipConfirmAction else { return "Xác nhận thao tác" }
        switch action {
        case .addManual, .addCurrent:
            return "Xác nhận thêm IP"
        case .delete:
            return "Xác nhận xoá IP"
        }
    }

    private func ipConfirmButtonTitle(for action: IpConfirmAction) -> String {
        switch action {
        case .addManual, .addCurrent:
            return "Thêm IP"
        case .delete:
            return "Xoá IP"
        }
    }

    private func ipConfirmIsDestructive(_ action: IpConfirmAction) -> Bool {
        if case .delete = action { return true }
        return false
    }

    private func ipConfirmMessage(for action: IpConfirmAction) -> String {
        switch action {
        case .addManual:
            return "Thêm IP/CIDR \(trimmedNewNetwork) vào danh sách cho trụ sở này?"
        case .addCurrent:
            let ip = currentIp?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "Thêm IP hiện tại \(ip) vào danh sách cho trụ sở này?"
        case .delete(let ipId):
            let network = ips.first(where: { $0.id == ipId })?.network ?? "IP này"
            return "Xoá \(network) khỏi danh sách IP của trụ sở?"
        }
    }

    private func performIpAction(_ action: IpConfirmAction) async {
        defer {
            showIpConfirm = false
            ipConfirmAction = nil
        }
        switch action {
        case .addManual:
            await addIp()
        case .addCurrent:
            await addCurrentIp()
        case .delete(let ipId):
            await deleteIp(ipId)
        }
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

    private func loadCurrentIp() async {
        currentIpLoading = true
        defer { currentIpLoading = false }
        let result = await APIClient.shared.resolveOfficeCurrentIp()
        currentIp = result.ip
        currentIpPublic = result.isPublic
    }

    private func addCurrentIp() async {
        guard let ip = currentIp?.trimmingCharacters(in: .whitespacesAndNewlines), !ip.isEmpty else {
            return
        }
        newNetwork = ip
        if newLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newLabel = "IP hiện tại"
        }
        await addIp()
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

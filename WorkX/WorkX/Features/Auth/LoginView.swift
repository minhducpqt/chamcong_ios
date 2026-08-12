//
//  LoginView.swift
//  WorkX
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var username = ""
    @State private var password = ""
    @State private var savedAccounts: [SavedAccount] = []
    @State private var environment = APIConfig.environment
    @FocusState private var focused: Field?

    private enum Field { case username, password }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WorkX")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("Đăng nhập chấm công")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 24)

                VStack(spacing: 16) {
                    TextField("Tài khoản (vd: kinhdo.trangnt)", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .textContentType(.username)
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($focused, equals: .username)

                    SecureField("Mật khẩu", text: $password)
                        .textContentType(.password)
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($focused, equals: .password)

                    if let err = session.errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        focused = nil
                        Task { await session.login(username: username, password: password) }
                    } label: {
                        Group {
                            if session.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Đăng nhập").fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(session.isLoading || username.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 24)

                if !savedAccounts.isEmpty {
                    savedAccountsSection
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tài khoản đã lưu")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Đăng nhập thành công sẽ lưu username và mật khẩu (tối đa 10) để chọn nhanh lần sau.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }

                Spacer()

                VStack(spacing: 10) {
                    Picker(
                        "Môi trường",
                        selection: Binding(
                            get: { environment },
                            set: {
                                environment = $0
                                APIConfig.environment = $0
                            }
                        )
                    ) {
                        ForEach(AppEnvironment.allCases) { env in
                            Text(env.label).tag(env)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(APIConfig.baseURL.absoluteString)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .navigationBarHidden(true)
            .onAppear {
                refreshSavedAccounts()
                applyDefaultCredentialsIfNeeded()
            }
            .onChange(of: session.isLoggedIn) { _, loggedIn in
                if !loggedIn {
                    refreshSavedAccounts()
                }
            }
        }
    }

    private var savedAccountsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tài khoản đã lưu")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                ForEach(savedAccounts) { account in
                    Button {
                        username = account.username
                        password = account.password
                        focused = nil
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.username)
                                    .foregroundStyle(.primary)
                                if !account.maskedHint.isEmpty {
                                    Text(account.maskedHint)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if account.id != savedAccounts.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
        }
        .padding(.top, 20)
    }

    private func refreshSavedAccounts() {
        savedAccounts = SavedAccountsStore.load()
    }

    private func applyDefaultCredentialsIfNeeded() {
        guard username.isEmpty && password.isEmpty else { return }
        if savedAccounts.isEmpty && !APIConfig.isProduction {
            username = "kinhdo.trangnt"
            password = "User@123"
        }
    }
}

#Preview {
    LoginView().environmentObject(SessionStore())
}

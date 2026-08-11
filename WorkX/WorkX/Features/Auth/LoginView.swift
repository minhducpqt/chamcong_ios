//
//  LoginView.swift
//  WorkX
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var username = "kinhdo.trangnt"
    @State private var password = "User@123"
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
                .padding(.bottom, 32)

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

                Spacer()

                Text("Server: \(APIConfig.baseURL.absoluteString)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 16)
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    LoginView().environmentObject(SessionStore())
}

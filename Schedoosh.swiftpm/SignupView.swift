import SwiftUI

struct SignupView: View {
    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Create account") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    NoAutofillSecureField("Password", text: $password)
                    .frame(height: 22)

                    NoAutofillSecureField("Confirm password", text: $confirmPassword)
                    .frame(height: 22)
                }

                if !auth.registeredUsernames.isEmpty {
                    Section("Taken usernames (local demo)") {
                        Text(auth.registeredUsernames.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        let u = username
                        let p = password
                        let c = confirmPassword
                        Task { @MainActor in
                            let ok = await auth.signUp(username: u, password: p, confirmPassword: c)
                            if ok { dismiss() }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if auth.isLoading {
                                ProgressView()
                            } else {
                                Text("Sign Up")
                            }
                            Spacer()
                        }
                    }
                    .disabled(auth.isLoading)

                    Text("Demo mode: signup checks username uniqueness locally. Replace the TODO in AuthStore.signUp(...) with a real API call later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let err = auth.lastError, !err.isEmpty {
                    Section("Error") {
                        Text(err).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Sign Up")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            auth.lastError = nil
        }
    }
}

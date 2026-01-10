import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthStore

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showingSignUp: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Sign in") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    NoAutofillSecureField("Password", text: $password)
                        .frame(height: 22)
                }

                Section {
                    Button {
                        let u = username
                        let p = password
                        Task { @MainActor in
                            _ = await auth.login(username: u, password: p)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if auth.isLoading {
                                ProgressView()
                            } else {
                                Text("Log In")
                            }
                            Spacer()
                        }
                    }
                    .disabled(auth.isLoading)

                    Text("Demo mode: any username/password works. Replace the TODO in AuthStore.login(...) with a real API call later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Don’t have an account? Sign up") {
                        showingSignUp = true
                    }
                    .disabled(auth.isLoading)
                }

                if let err = auth.lastError, !err.isEmpty {
                    Section("Error") {
                        Text(err).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Schedoosh")
        }
        .sheet(isPresented: $showingSignUp) {
            SignupView()
                .environmentObject(auth)
        }
        .onAppear {
            // if returning to login screen, keep the last username around
            if username.isEmpty { username = auth.username }
        }
    }
}

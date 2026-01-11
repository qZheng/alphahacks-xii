import SwiftUI

struct SignupView: View {
    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Create account")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("Demo signup checks usernames locally for now.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 12) {
                        TextField("Username", text: $username)
                            .appTextField()

                        NoAutofillSecureField("Password", text: $password)
                            .frame(height: 48)
                            .appTextField()

                        NoAutofillSecureField("Confirm password", text: $confirmPassword)
                            .frame(height: 48)
                            .appTextField()
                    }
                    .appCard()

                    if !auth.registeredUsernames.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Taken usernames (local)")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(auth.registeredUsernames.sorted().joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .appCard()
                    }

                    Button {
                        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
                        let p = password
                        let c = confirmPassword
                        Task { @MainActor in
                            let ok = await auth.signUp(username: u, password: p, confirmPassword: c)
                            if ok { dismiss() }
                        }
                    } label: {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign Up")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(auth.isLoading || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let err = auth.lastError, !err.isEmpty {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(AppColors.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Text("Replace the TODO in AuthStore.signUp(...) with a real API call later.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .appScreen()
            .onAppear { auth.lastError = nil }
        }
    }
}

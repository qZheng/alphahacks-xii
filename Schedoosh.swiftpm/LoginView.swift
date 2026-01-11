import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthStore

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showingSignUp: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    VStack(spacing: 12) {
                        TextField("Username", text: $username)
                            .appTextField()

                        NoAutofillSecureField("Password", text: $password)
                            .frame(height: 48)
                            .appTextField()
                    }
                    .appCard()

                    Button {
                        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
                        let p = password
                        Task { @MainActor in
                            _ = await auth.login(username: u, password: p)
                        }
                    } label: {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Log In")
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

                    Button {
                        showingSignUp = true
                    } label: {
                        Text("Don’t have an account? Sign Up")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(auth.isLoading)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarHidden(true)
            .appScreen()
            .scrollContentBackground(.hidden)
        }
        .sheet(isPresented: $showingSignUp) {
            SignupView().environmentObject(auth)
        }
        .onAppear {
            if username.isEmpty { username = auth.username }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Schedoosh")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text("Check in on time. Compete with friends. Keep it simple.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }
}

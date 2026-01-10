import Foundation

@MainActor
final class AuthStore: ObservableObject, @unchecked Sendable {
    @Published var isLoggedIn: Bool
    @Published var username: String
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil

    // Local demo user registry (UserDefaults)
    @Published private(set) var registeredUsernames: [String] = []

    private let keyLoggedIn = "SchedooshAuth.loggedIn"
    private let keyUsername = "SchedooshAuth.username"
    private let keyUsers = "SchedooshAuth.users"

    init() {
        let savedLoggedIn = UserDefaults.standard.bool(forKey: keyLoggedIn)
        let savedUsername = UserDefaults.standard.string(forKey: keyUsername) ?? ""
        self.isLoggedIn = savedLoggedIn
        self.username = savedUsername
        loadUsers()
    }

    // MARK: - Login / Signup (demo)

    /// Demo login:
    /// - For now, accepts any non-empty username/password.
    /// - Includes a stub showing where a real API call would happen.
    func login(username: String, password: String) async -> Bool {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if u.isEmpty {
            lastError = "Username is required."
            return false
        }

        // ─────────────────────────────────────────────
        // TODO: Replace this demo logic with your API call.
        // Example:
        //   let token = try await loginViaAPI(username: u, password: password)
        //   store token securely (Keychain)
        //   isLoggedIn = true
        // ─────────────────────────────────────────────

        // Simulate a tiny “network” delay
        try? await Task.sleep(nanoseconds: 250_000_000)

        self.username = u
        self.isLoggedIn = true
        persistSession()
        return true
    }

    /// Demo signup:
    /// - checks if the username is already taken in the local registry
    /// - includes a stub showing where a real API call would happen
    func signUp(username: String, password: String, confirmPassword: String) async -> Bool {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if u.isEmpty {
            lastError = "Username is required."
            return false
        }
        if password.isEmpty {
            lastError = "Password is required."
            return false
        }
        if password != confirmPassword {
            lastError = "Passwords do not match."
            return false
        }
        if userExists(u) {
            lastError = "That username is already taken."
            return false
        }

        // ─────────────────────────────────────────────
        // TODO: Replace this demo logic with your API call.
        // Example:
        //   let token = try await signUpViaAPI(username: u, password: password)
        //   store token securely (Keychain)
        //   isLoggedIn = true
        // ─────────────────────────────────────────────

        // Simulate a tiny “network” delay
        try? await Task.sleep(nanoseconds: 250_000_000)

        // Save locally (demo)
        users.append(LocalUser(username: u, password: password))
        saveUsers()
        refreshRegisteredUsernames()

        // Auto-log in after signup
        self.username = u
        self.isLoggedIn = true
        persistSession()
        return true
    }

    func logout() {
        isLoggedIn = false
        username = ""
        lastError = nil
        persistSession()
    }

    // MARK: - Local registry helpers

    private struct LocalUser: Codable {
        var username: String
        var password: String
    }

    private var users: [LocalUser] = []

    private func userExists(_ username: String) -> Bool {
        users.contains { $0.username.lowercased() == username.lowercased() }
    }

    private func loadUsers() {
        guard let data = UserDefaults.standard.data(forKey: keyUsers),
              let decoded = try? JSONDecoder().decode([LocalUser].self, from: data) else {
            users = []
            refreshRegisteredUsernames()
            return
        }
        users = decoded
        refreshRegisteredUsernames()
    }

    private func saveUsers() {
        if let data = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(data, forKey: keyUsers)
        }
    }

    private func refreshRegisteredUsernames() {
        registeredUsernames = users.map { $0.username }.sorted()
    }

    private func persistSession() {
        UserDefaults.standard.set(isLoggedIn, forKey: keyLoggedIn)
        UserDefaults.standard.set(username, forKey: keyUsername)
    }

    // MARK: - API stubs (not used yet)

    /// Stub showing where a real HTTP login would live.
    /// Return a token (or session id) from your backend.
    func loginViaAPI(username: String, password: String) async throws -> String {
        // TODO: implement with URLSession
        throw URLError(.unsupportedURL)
    }

    /// Stub showing where a real HTTP signup would live.
    /// Return a token (or session id) from your backend.
    func signUpViaAPI(username: String, password: String) async throws -> String {
        // TODO: implement with URLSession
        throw URLError(.unsupportedURL)
    }
}

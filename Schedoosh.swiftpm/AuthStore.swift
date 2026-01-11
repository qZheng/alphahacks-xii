import Foundation

@MainActor
final class AuthStore: ObservableObject, @unchecked Sendable {
    @Published var isLoggedIn: Bool
    @Published var username: String
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil

    // API Configuration
    private let baseURL = "http://192.168.2.70:5000"
    
    // Token storage
    private let keyLoggedIn = "SchedooshAuth.loggedIn"
    private let keyUsername = "SchedooshAuth.username"
    private let keyToken = "SchedooshAuth.token"

    init() {
        let savedLoggedIn = UserDefaults.standard.bool(forKey: keyLoggedIn)
        let savedUsername = UserDefaults.standard.string(forKey: keyUsername) ?? ""
        self.isLoggedIn = savedLoggedIn
        self.username = savedUsername
        
        // If we have a saved session but no token, clear it
        if savedLoggedIn && getToken() == nil {
            self.isLoggedIn = false
            self.username = ""
        }
    }
    
    // MARK: - Token Management
    
    private func getToken() -> String? {
        UserDefaults.standard.string(forKey: keyToken)
    }
    
    private func setToken(_ token: String?) {
        if let token = token {
            UserDefaults.standard.set(token, forKey: keyToken)
        } else {
            UserDefaults.standard.removeObject(forKey: keyToken)
        }
    }
    
    /// Get the current auth token for making authenticated API requests
    func authToken() -> String? {
        getToken()
    }
    
    /// Test API connection - useful for debugging
    func testAPIConnection() async -> String {
        guard let url = URL(string: "\(baseURL)/api/auth/login") else {
            return "Invalid URL"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0
        
        let body: [String: String] = [
            "username": "test",
            "password": "test"
        ]
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (_, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return "Connection successful! Status: \(httpResponse.statusCode)"
            } else {
                return "Connection successful but invalid response type"
            }
        } catch let urlError as URLError {
            return "Connection failed: \(urlError.localizedDescription) (Code: \(urlError.code.rawValue))"
        } catch {
            return "Connection failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Login / Signup

    func login(username: String, password: String) async -> Bool {
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

        do {
            let token = try await loginViaAPI(username: u, password: password)
            setToken(token)
            self.username = u
            self.isLoggedIn = true
            persistSession()
            return true
        } catch {
            if let apiError = error as? APIError {
                lastError = apiError.message
            } else {
                lastError = "Failed to connect to server. Please check your connection."
            }
            return false
        }
    }

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

        do {
            // Register the user
            try await signUpViaAPI(username: u, password: password)
            // Auto-log in after signup
            let token = try await loginViaAPI(username: u, password: password)
            setToken(token)
            self.username = u
            self.isLoggedIn = true
            persistSession()
            return true
        } catch {
            if let apiError = error as? APIError {
                lastError = apiError.message
            } else {
                lastError = "Failed to connect to server. Please check your connection."
            }
            return false
        }
    }

    func logout() {
        isLoggedIn = false
        username = ""
        lastError = nil
        setToken(nil)
        persistSession()
    }

    private func persistSession() {
        UserDefaults.standard.set(isLoggedIn, forKey: keyLoggedIn)
        UserDefaults.standard.set(username, forKey: keyUsername)
    }

    // MARK: - API Implementation

    /// API Error structure
    private struct APIError: Error {
        let message: String
    }
    
    /// Login response structure
    private struct LoginResponse: Codable {
        let access_token: String?
        let error: String?
    }
    
    /// Register response structure
    private struct RegisterResponse: Codable {
        let ok: Bool?
        let error: String?
    }
    
    /// Create a URLSession with proper timeout configuration
    private var urlSession: URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10.0 // 10 seconds
        configuration.timeoutIntervalForResource = 30.0 // 30 seconds
        return URLSession(configuration: configuration)
    }

    /// Login via API
    func loginViaAPI(username: String, password: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/auth/login") else {
            throw APIError(message: "Invalid server URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let body: [String: String] = [
            "username": username,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError(message: "Failed to encode request: \(error.localizedDescription)")
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw APIError(message: "Request timed out. Please check your connection and try again.")
            case .notConnectedToInternet:
                throw APIError(message: "No internet connection. Please check your network.")
            case .cannotFindHost, .cannotConnectToHost:
                throw APIError(message: "Cannot connect to server. Please verify the server is running.")
            default:
                throw APIError(message: "Network error: \(urlError.localizedDescription)")
            }
        } catch {
            throw APIError(message: "Request failed: \(error.localizedDescription)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid server response")
        }
        
        // Try to decode response
        let decoder = JSONDecoder()
        let loginResponse: LoginResponse
        do {
            loginResponse = try decoder.decode(LoginResponse.self, from: data)
        } catch {
            // If decoding fails, try to get error message from raw response
            if let responseString = String(data: data, encoding: .utf8) {
                throw APIError(message: "Invalid server response: \(responseString)")
            } else {
                throw APIError(message: "Invalid server response format")
            }
        }
        
        // Check for error in response body first
        if let error = loginResponse.error {
            throw APIError(message: error)
        }
        
        // Check HTTP status code
        if httpResponse.statusCode != 200 {
            throw APIError(message: "Login failed with status code \(httpResponse.statusCode)")
        }
        
        guard let token = loginResponse.access_token else {
            throw APIError(message: "No token received from server")
        }
        
        return token
    }

    /// Sign up via API
    func signUpViaAPI(username: String, password: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/auth/register") else {
            throw APIError(message: "Invalid server URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let body: [String: String] = [
            "username": username,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError(message: "Failed to encode request: \(error.localizedDescription)")
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw APIError(message: "Request timed out. Please check your connection and try again.")
            case .notConnectedToInternet:
                throw APIError(message: "No internet connection. Please check your network.")
            case .cannotFindHost, .cannotConnectToHost:
                throw APIError(message: "Cannot connect to server. Please verify the server is running.")
            default:
                throw APIError(message: "Network error: \(urlError.localizedDescription)")
            }
        } catch {
            throw APIError(message: "Request failed: \(error.localizedDescription)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid server response")
        }
        
        // Try to decode response
        let decoder = JSONDecoder()
        let registerResponse: RegisterResponse
        do {
            registerResponse = try decoder.decode(RegisterResponse.self, from: data)
        } catch {
            // If decoding fails, try to get error message from raw response
            if let responseString = String(data: data, encoding: .utf8) {
                throw APIError(message: "Invalid server response: \(responseString)")
            } else {
                throw APIError(message: "Invalid server response format")
            }
        }
        
        if let error = registerResponse.error {
            throw APIError(message: error)
        }
        
        // Check if registration was successful
        if httpResponse.statusCode == 201 {
            return
        } else {
            throw APIError(message: "Registration failed with status code \(httpResponse.statusCode)")
        }
    }
}

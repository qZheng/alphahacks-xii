import Foundation

@MainActor
final class DataStore: ObservableObject {
    @Published var profile: UserProfile = UserProfile()
    @Published var classes: [ClassItem] = []
    @Published var groups: [Group] = []
    
    // Attendance tracking remains local (not stored on server)
    @Published var checkedInKeys: Set<String> = []
    @Published var missedKeys: Set<String> = []
    
    // API Configuration
    private let baseURL = "http://192.168.2.70:5000"
    
    // Mapping backend integer IDs to frontend UUIDs
    private var classIdMap: [Int: UUID] = [:]
    private var groupIdMap: [Int: UUID] = [:]
    private var memberIdMap: [Int: UUID] = [:]
    
    // Weak reference to AuthStore for getting token
    weak var authStore: AuthStore?
    
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil
    
    init() {
        // Initialize with empty data - will be loaded from server
    }
    
    // MARK: - Data Fetching
    
    /// Fetch all data from the server
    func refresh() async {
        await fetchProfile()
        await fetchClasses()
        await fetchGroups()
    }
    
    /// Fetch user profile from server
    func fetchProfile() async {
        guard let token = authStore?.authToken() else {
            lastError = "Not authenticated"
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/me") else {
            lastError = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                lastError = "Invalid response"
                return
            }
            
            if httpResponse.statusCode != 200 {
                lastError = "Failed to fetch profile: \(httpResponse.statusCode)"
                return
            }
            
            let decoder = JSONDecoder()
            let userResponse = try decoder.decode(UserResponse.self, from: data)
            
            profile.id = uuidFromInt(userResponse.id)
            profile.name = userResponse.username
            profile.points = userResponse.score
            lastError = nil
        } catch {
            lastError = "Failed to fetch profile: \(error.localizedDescription)"
        }
    }
    
    /// Fetch classes (events) from server
    func fetchClasses() async {
        guard let token = authStore?.authToken() else {
            lastError = "Not authenticated"
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/events") else {
            lastError = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                lastError = "Invalid response"
                return
            }
            
            if httpResponse.statusCode != 200 {
                lastError = "Failed to fetch classes: \(httpResponse.statusCode)"
                return
            }
            
            let decoder = JSONDecoder()
            let eventResponses = try decoder.decode([EventResponse].self, from: data)
            
            classIdMap.removeAll()
            classes = eventResponses.map { eventResponse in
                let uuid = uuidFromInt(eventResponse.id)
                classIdMap[eventResponse.id] = uuid
                // Convert backend weekday (0-6, 0=Monday) to frontend (1-7, 1=Sunday)
                let frontendWeekday = backendWeekdayToFrontend(eventResponse.weekday)
                return ClassItem(
                    id: uuid,
                    title: eventResponse.title,
                    weekday: frontendWeekday,
                    hour: eventResponse.hour,
                    minute: eventResponse.minute,
                    enabled: true, // Backend doesn't have enabled field
                    buildingCode: nil,
                    source: .manual
                )
            }
            lastError = nil
        } catch {
            lastError = "Failed to fetch classes: \(error.localizedDescription)"
        }
    }
    
    /// Fetch groups from server
    func fetchGroups() async {
        guard let token = authStore?.authToken() else {
            lastError = "Not authenticated"
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/groups") else {
            lastError = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                lastError = "Invalid response"
                return
            }
            
            if httpResponse.statusCode != 200 {
                lastError = "Failed to fetch groups: \(httpResponse.statusCode)"
                return
            }
            
            let decoder = JSONDecoder()
            let groupListResponses = try decoder.decode([GroupListResponse].self, from: data)
            
            // Fetch details for each group
            groupIdMap.removeAll()
            groups = []
            
            // Get current user ID once before the loop to avoid repeated API calls
            let currentUserId = await getCurrentUserId(token: token)
            
            for groupListResponse in groupListResponses {
                let groupDetail = await fetchGroupDetail(groupId: groupListResponse.id, token: token)
                if let groupDetail = groupDetail {
                    let groupUUID = uuidFromInt(groupListResponse.id)
                    groupIdMap[groupListResponse.id] = groupUUID
                    
                    let members = groupDetail.members.map { memberResponse in
                        let memberUUID = uuidFromInt(memberResponse.id)
                        memberIdMap[memberResponse.id] = memberUUID
                        return Member(
                            id: memberUUID,
                            name: memberResponse.username,
                            points: memberResponse.score,
                            isMe: memberResponse.id == currentUserId
                        )
                    }
                    
                    groups.append(Group(
                        id: groupUUID,
                        name: groupDetail.name,
                        members: members
                    ))
                }
            }
            lastError = nil
        } catch {
            lastError = "Failed to fetch groups: \(error.localizedDescription)"
        }
    }
    
    private func fetchGroupDetail(groupId: Int, token: String) async -> GroupDetailResponse? {
        guard let url = URL(string: "\(baseURL)/api/groups/\(groupId)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }
            
            guard httpResponse.statusCode == 200 else {
                return nil
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(GroupDetailResponse.self, from: data)
        } catch {
            return nil
        }
    }
    
    private func getCurrentUserId(token: String) async -> Int? {
        guard let url = URL(string: "\(baseURL)/api/me") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }
            
            guard httpResponse.statusCode == 200 else {
                return nil
            }
            
            let decoder = JSONDecoder()
            let userResponse = try decoder.decode(UserResponse.self, from: data)
            return userResponse.id
        } catch {
            return nil
        }
    }
    
    // MARK: - Data Modification
    
    func addPoint() async {
        guard let token = authStore?.authToken() else {
            lastError = "Not authenticated"
            return
        }
        
        // Get current score and increment
        let newScore = profile.points + 1
        
        guard let url = URL(string: "\(baseURL)/api/me") else {
            lastError = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Int] = ["score": newScore]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                lastError = "Invalid response"
                return
            }
            
            if httpResponse.statusCode == 200 {
                // Refresh profile and groups from server to get updated data
                await fetchProfile()
                await fetchGroups()
            } else {
                // Try to read error message from response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorData["error"] as? String {
                    lastError = "Failed to update score: \(errorMessage)"
                } else {
                    lastError = "Failed to update score: \(httpResponse.statusCode)"
                }
            }
        } catch {
            lastError = "Failed to update score: \(error.localizedDescription)"
        }
    }
    
    func clearAll() {
        profile = UserProfile()
        classes = []
        groups = []
        checkedInKeys = []
        missedKeys = []
        classIdMap.removeAll()
        groupIdMap.removeAll()
        memberIdMap.removeAll()
    }
    
    // MARK: - Class Management
    
    func addClass(_ classItem: ClassItem) async {
        guard let token = authStore?.authToken() else {
            lastError = "Not authenticated"
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/events") else {
            lastError = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert frontend weekday (1-7, 1=Sunday) to backend (0-6, 0=Monday)
        let backendWeekday = frontendWeekdayToBackend(classItem.weekday)
        
        let body: [String: Any] = [
            "title": classItem.title,
            "weekday": backendWeekday,
            "hour": classItem.hour,
            "minute": classItem.minute
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                lastError = "Invalid response"
                return
            }
            
            if httpResponse.statusCode == 201 {
                await fetchClasses() // Refresh from server to get the ID
            } else {
                // Try to read error message from response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorData["error"] as? String {
                    lastError = "Failed to create class: \(errorMessage)"
                } else {
                    lastError = "Failed to create class: \(httpResponse.statusCode)"
                }
            }
        } catch {
            lastError = "Failed to create class: \(error.localizedDescription)"
        }
    }
    
    func updateClass(_ classItem: ClassItem) async {
        guard let backendId = classIdMap.first(where: { $0.value == classItem.id })?.key else {
            lastError = "Class not found"
            return
        }
        
        // For now, delete and recreate since backend doesn't have update endpoint
        await deleteClass(classItem)
        await addClass(classItem)
    }
    
    func deleteClass(_ classItem: ClassItem) async {
        guard let token = authStore?.authToken() else {
            lastError = "Not authenticated"
            return
        }
        
        guard let backendId = classIdMap.first(where: { $0.value == classItem.id })?.key else {
            lastError = "Class not found"
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/events/\(backendId)") else {
            lastError = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                lastError = "Invalid response"
                return
            }
            
            if httpResponse.statusCode == 200 {
                await fetchClasses() // Refresh from server
            } else {
                // Try to read error message from response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorData["error"] as? String {
                    lastError = "Failed to delete class: \(errorMessage)"
                } else {
                    lastError = "Failed to delete class: \(httpResponse.statusCode)"
                }
            }
        } catch {
            lastError = "Failed to delete class: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Group Management
    
    func createGroup(name: String) async {
        guard let token = authStore?.authToken() else {
            lastError = "Not authenticated"
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/groups") else {
            lastError = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["name": name]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                lastError = "Invalid response"
                return
            }
            
            if httpResponse.statusCode == 201 {
                await fetchGroups() // Refresh from server
            } else {
                // Try to read error message from response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorData["error"] as? String {
                    lastError = "Failed to create group: \(errorMessage)"
                } else {
                    lastError = "Failed to create group: \(httpResponse.statusCode)"
                }
            }
        } catch {
            lastError = "Failed to create group: \(error.localizedDescription)"
        }
    }
    
    func deleteGroup(_ group: Group) async {
        guard let backendId = groupIdMap.first(where: { $0.value == group.id })?.key else {
            lastError = "Group not found"
            return
        }
        
        // For now, leave the group (backend doesn't have delete endpoint)
        await leaveGroup(group)
    }
    
    func inviteUser(_ username: String, to group: Group) async {
        guard let token = authStore?.authToken() else {
            lastError = "Not authenticated"
            return
        }
        
        guard let backendId = groupIdMap.first(where: { $0.value == group.id })?.key else {
            lastError = "Group not found"
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/groups/\(backendId)/invite") else {
            lastError = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["username": username]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                lastError = "Invalid response"
                return
            }
            
            if httpResponse.statusCode == 200 {
                await fetchGroups() // Refresh from server
            } else {
                // Try to read error message from response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorData["error"] as? String {
                    lastError = "Failed to invite user: \(errorMessage)"
                } else {
                    lastError = "Failed to invite user: \(httpResponse.statusCode)"
                }
            }
        } catch {
            lastError = "Failed to invite user: \(error.localizedDescription)"
        }
    }
    
    func leaveGroup(_ group: Group) async {
        guard let token = authStore?.authToken() else {
            lastError = "Not authenticated"
            return
        }
        
        guard let backendId = groupIdMap.first(where: { $0.value == group.id })?.key else {
            lastError = "Group not found"
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/groups/\(backendId)/leave") else {
            lastError = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                lastError = "Invalid response"
                return
            }
            
            if httpResponse.statusCode == 200 {
                await fetchGroups() // Refresh from server
            } else {
                // Try to read error message from response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorData["error"] as? String {
                    lastError = "Failed to leave group: \(errorMessage)"
                } else {
                    lastError = "Failed to leave group: \(httpResponse.statusCode)"
                }
            }
        } catch {
            lastError = "Failed to leave group: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Functions
    
    /// Convert backend integer ID to UUID deterministically
    private func uuidFromInt(_ id: Int) -> UUID {
        // Use a deterministic UUID generation based on integer ID
        // Format: 00000000-0000-0000-0000-XXXXXXXXXXXX (12 hex digits)
        let hexString = String(format: "%012x", id)
        let uuidString = "00000000-0000-0000-0000-\(hexString)"
        return UUID(uuidString: uuidString) ?? UUID()
    }
    
    /// Convert backend weekday (0-6, 0=Monday) to frontend (1-7, 1=Sunday)
    private func backendWeekdayToFrontend(_ backendWeekday: Int) -> Int {
        // Backend: 0=Monday, 1=Tuesday, ..., 6=Sunday
        // Frontend: 1=Sunday, 2=Monday, ..., 7=Saturday
        // Mapping: 0→2, 1→3, 2→4, 3→5, 4→6, 5→7, 6→1
        let result = (backendWeekday + 2) % 7
        return result == 0 ? 7 : result
    }
    
    /// Convert frontend weekday (1-7, 1=Sunday) to backend (0-6, 0=Monday)
    private func frontendWeekdayToBackend(_ frontendWeekday: Int) -> Int {
        // Frontend: 1=Sunday, 2=Monday, ..., 7=Saturday
        // Backend: 0=Monday, 1=Tuesday, ..., 6=Sunday
        // Mapping: 1→6, 2→0, 3→1, 4→2, 5→3, 6→4, 7→5
        return (frontendWeekday + 5) % 7
    }
    
    // MARK: - Response Structures
    
    private struct UserResponse: Codable {
        let id: Int
        let username: String
        let score: Int
    }
    
    private struct EventResponse: Codable {
        let id: Int
        let title: String
        let weekday: Int
        let hour: Int
        let minute: Int
        let user_id: Int
    }
    
    private struct GroupListResponse: Codable {
        let id: Int
        let name: String
    }
    
    private struct GroupDetailResponse: Codable {
        let id: Int
        let name: String
        let members: [MemberResponse]
    }
    
    private struct MemberResponse: Codable {
        let id: Int
        let username: String
        let score: Int
    }
}

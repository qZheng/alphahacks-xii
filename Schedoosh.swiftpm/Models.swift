import Foundation

struct UserProfile: Codable, Equatable {
    var id: UUID = UUID()
    var name: String = "Me"
    var points: Int = 0
}

struct ClassItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var weekday: Int
    var hour: Int
    var minute: Int
    var enabled: Bool = true
}

struct Member: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var points: Int
    var isMe: Bool = false
}

struct Group: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var members: [Member]
}

import Foundation

enum ClassSource: String, Codable {
    case manual
    case calendar
}

struct UserProfile: Codable, Equatable {
    var id: UUID = UUID()
    var name: String = "Me"
    var points: Int = 0
}

struct ClassItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    /// 1=Sunday ... 7=Saturday (matches Calendar.component(.weekday,...))
    var weekday: Int
    var hour: Int
    var minute: Int
    var enabled: Bool = true
    var buildingCode: String? = nil

    /// manual vs calendar-imported
    var source: ClassSource = .manual
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

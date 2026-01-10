import Foundation

final class DataStore: ObservableObject {
    @Published var profile: UserProfile { didSet { save() } }
    @Published var classes: [ClassItem] { didSet { save() } }
    @Published var groups: [Group] { didSet { save() } }

    @Published var checkedInKeys: Set<String> { didSet { save() } }
    @Published var missedKeys: Set<String> { didSet { save() } }

    private let key = "SchedooshStore.v2"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(Payload.self, from: data) {
            self.profile = decoded.profile
            self.classes = decoded.classes
            self.groups = decoded.groups
            self.checkedInKeys = decoded.checkedInKeys
            self.missedKeys = decoded.missedKeys
        } else {
            self.profile = UserProfile()
            self.classes = []
            self.groups = []
            self.checkedInKeys = []
            self.missedKeys = []
        }
        reconcileMeInGroups()
    }

    func addPoint() {
        profile.points += 1
        reconcileMeInGroups()
    }

    func clearAll() {
        profile = UserProfile()
        classes = []
        groups = []
        checkedInKeys = []
        missedKeys = []
    }

    func reconcileMeInGroups() {
        for gi in groups.indices {
            for mi in groups[gi].members.indices {
                if groups[gi].members[mi].isMe {
                    groups[gi].members[mi].name = profile.name
                    groups[gi].members[mi].points = profile.points
                }
            }
        }
    }

    private func save() {
        let payload = Payload(
            profile: profile,
            classes: classes,
            groups: groups,
            checkedInKeys: checkedInKeys,
            missedKeys: missedKeys
        )
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private struct Payload: Codable {
        var profile: UserProfile
        var classes: [ClassItem]
        var groups: [Group]
        var checkedInKeys: Set<String>
        var missedKeys: Set<String>
    }
}

// Otium/Stores/MessageStore.swift
import Foundation

// Codable DTO for persisting custom messages to UserDefaults
struct CustomMessageRecord: Codable {
    let id: UUID
    let text: String
    let attribution: String?

    init(text: String, attribution: String?) {
        self.id = UUID()
        self.text = text
        self.attribution = attribution
    }
}

@MainActor
final class MessageStore: ObservableObject {
    @Published private(set) var allMessages: [Message] = []

    private let defaults: UserDefaults
    private var shuffleQueue: [Message] = []

    private enum Keys {
        static let custom = "messages.custom"
        static let deletedTexts = "messages.deletedDefaultTexts"
    }

    private static let defaultMessages: [(text: String, attribution: String)] = [
        ("The mind must be given relaxation — it will rise improved and sharper after a good break.", "Seneca"),
        ("Just as rich fields must not be forced — for they will quickly lose their fertility — constant work on the anvil will fracture the force of the mind.", "Seneca"),
        ("Retire into yourself as much as you can.", "Seneca"),
        ("Confine yourself to the present.", "Marcus Aurelius"),
        ("He who is everywhere is nowhere.", "Seneca"),
        ("We suffer more in imagination than in reality.", "Seneca"),
        ("No man is free who is not master of himself.", "Epictetus"),
    ]

    private static let fallback = Message(text: "Time to take a break.", attribution: nil, isDefault: true)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        rebuild()
    }

    func nextMessage() -> Message {
        if allMessages.isEmpty { return Self.fallback }
        if shuffleQueue.isEmpty { shuffleQueue = allMessages.shuffled() }
        return shuffleQueue.removeFirst()
    }

    func addCustom(text: String, attribution: String?) {
        let record = CustomMessageRecord(text: text, attribution: attribution)
        var existing = loadCustomRecords()
        existing.append(record)
        saveCustomRecords(existing)
        rebuild()
    }

    func delete(_ message: Message) {
        if message.isDefault {
            var deleted = loadDeletedTexts()
            deleted.insert(message.text)
            defaults.set(Array(deleted), forKey: Keys.deletedTexts)
        } else {
            var records = loadCustomRecords()
            records.removeAll { $0.id == message.id }
            saveCustomRecords(records)
        }
        rebuild()
    }

    func resetToDefaults() {
        defaults.removeObject(forKey: Keys.deletedTexts)
        defaults.removeObject(forKey: Keys.custom)
        shuffleQueue = []
        rebuild()
    }

    private func rebuild() {
        let deleted = loadDeletedTexts()
        let builtInMessages: [Message] = Self.defaultMessages.compactMap { pair in
            guard !deleted.contains(pair.text) else { return nil }
            return Message(text: pair.text, attribution: pair.attribution, isDefault: true)
        }
        let customMessages: [Message] = loadCustomRecords().map {
            Message(id: $0.id, text: $0.text, attribution: $0.attribution, isDefault: false)
        }
        allMessages = builtInMessages + customMessages
        let texts = Set(allMessages.map { $0.text })
        shuffleQueue = shuffleQueue.filter { texts.contains($0.text) }
    }

    private func loadDeletedTexts() -> Set<String> {
        Set(defaults.array(forKey: Keys.deletedTexts) as? [String] ?? [])
    }

    private func loadCustomRecords() -> [CustomMessageRecord] {
        guard let data = defaults.data(forKey: Keys.custom),
              let records = try? JSONDecoder().decode([CustomMessageRecord].self, from: data)
        else { return [] }
        return records
    }

    private func saveCustomRecords(_ records: [CustomMessageRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Keys.custom)
    }
}

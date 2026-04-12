// Otium/Stores/MessageStore.swift
import Foundation

// Codable DTO for persisting custom messages to UserDefaults
struct CustomMessageRecord: Codable {
    let text: String
    let attribution: String?
}

@MainActor
final class MessageStore: ObservableObject {
    @Published private(set) var allMessages: [Message] = []

    private let defaults: UserDefaults
    private var shuffleQueue: [Message] = []

    private enum Keys {
        static let custom = "messages.custom"
        static let deletedIds = "messages.deletedDefaultIds"
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
            if let idx = Self.defaultMessages.firstIndex(where: { $0.text == message.text }) {
                var deleted = loadDeletedIds()
                deleted.insert(idx)
                defaults.set(Array(deleted), forKey: Keys.deletedIds)
            }
        } else {
            var records = loadCustomRecords()
            records.removeAll { $0.text == message.text }
            saveCustomRecords(records)
        }
        shuffleQueue.removeAll { $0.text == message.text }
        rebuild()
    }

    func resetToDefaults() {
        defaults.removeObject(forKey: Keys.deletedIds)
        defaults.removeObject(forKey: Keys.custom)
        shuffleQueue = []
        rebuild()
    }

    private func rebuild() {
        let deleted = loadDeletedIds()
        let builtInMessages: [Message] = Self.defaultMessages.enumerated().compactMap { idx, pair in
            guard !deleted.contains(idx) else { return nil }
            return Message(text: pair.text, attribution: pair.attribution, isDefault: true)
        }
        let customMessages: [Message] = loadCustomRecords().map {
            Message(text: $0.text, attribution: $0.attribution, isDefault: false)
        }
        allMessages = builtInMessages + customMessages
        let texts = Set(allMessages.map { $0.text })
        shuffleQueue = shuffleQueue.filter { texts.contains($0.text) }
    }

    private func loadDeletedIds() -> Set<Int> {
        Set(defaults.array(forKey: Keys.deletedIds) as? [Int] ?? [])
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

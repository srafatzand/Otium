// Otium/Models/Message.swift
import Foundation

struct Message: Equatable, Identifiable {
    let id: UUID
    let text: String
    let attribution: String?
    let isDefault: Bool

    init(text: String, attribution: String? = nil, isDefault: Bool = false) {
        self.id = UUID()
        self.text = text
        self.attribution = attribution
        self.isDefault = isDefault
    }
}

// Used for persisting custom messages to UserDefaults
struct CustomMessageRecord: Codable {
    let text: String
    let attribution: String?
}

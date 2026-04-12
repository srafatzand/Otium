// Otium/Models/Message.swift
import Foundation

struct Message: Equatable, Hashable, Identifiable {
    let id: UUID
    let text: String
    let attribution: String?
    let isDefault: Bool

    init(id: UUID = UUID(), text: String, attribution: String? = nil, isDefault: Bool = false) {
        self.id = id
        self.text = text
        self.attribution = attribution
        self.isDefault = isDefault
    }
}

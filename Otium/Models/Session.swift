// Otium/Models/Session.swift
import Foundation

enum SessionOutcome: String, Codable {
    case completed   // break respected (with or without extension)
    case overridden  // user hit Override
    case stopped     // user stopped session early; elapsed time logged, no streak effect
}

struct Session: Codable, Identifiable, Equatable {
    let id: UUID
    let startTime: Date
    let plannedDuration: TimeInterval
    let actualDuration: TimeInterval
    let extendUsed: Bool
    let outcome: SessionOutcome

    init(
        startTime: Date,
        plannedDuration: TimeInterval,
        actualDuration: TimeInterval,
        extendUsed: Bool,
        outcome: SessionOutcome
    ) {
        self.id = UUID()
        self.startTime = startTime
        self.plannedDuration = plannedDuration
        self.actualDuration = actualDuration
        self.extendUsed = extendUsed
        self.outcome = outcome
    }
}

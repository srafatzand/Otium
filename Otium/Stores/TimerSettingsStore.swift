// Otium/Stores/TimerSettingsStore.swift
import Foundation

@MainActor
final class TimerSettingsStore: ObservableObject {
    @Published private(set) var breakDuration: TimeInterval

    private let defaults: UserDefaults
    private let key = "timer.breakDuration"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.integer(forKey: "timer.breakDuration")
        let minutes = max(stored > 0 ? stored : 5, 5)
        self.breakDuration = TimeInterval(minutes * 60)
    }

    var breakDurationMinutes: Int { Int(breakDuration / 60) }

    func setBreakDuration(minutes: Int) {
        let clamped = max(minutes, 5)
        breakDuration = TimeInterval(clamped * 60)
        defaults.set(clamped, forKey: key)
    }
}

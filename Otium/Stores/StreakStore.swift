// Otium/Stores/StreakStore.swift
import Foundation

final class StreakStore: ObservableObject {
    @Published private(set) var count: Int
    private(set) var lastCompletedDate: Date?
    private(set) var lastOverrideDate: Date?

    private let defaults: UserDefaults
    private let calendar = Calendar.current

    private enum Keys {
        static let count = "streak.count"
        static let lastCompleted = "streak.lastCompletedDate"
        static let lastOverride = "streak.lastOverrideDate"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.count = defaults.integer(forKey: Keys.count)
        self.lastCompletedDate = defaults.object(forKey: Keys.lastCompleted) as? Date
        self.lastOverrideDate = defaults.object(forKey: Keys.lastOverride) as? Date
    }

    func recordCleanSession() {
        let today = calendar.startOfDay(for: Date())
        // Already recorded today
        if let last = lastCompletedDate, calendar.isDate(last, inSameDayAs: today) { return }
        // Override happened today — no increment
        if let override = lastOverrideDate, calendar.isDate(override, inSameDayAs: today) { return }
        count += 1
        lastCompletedDate = today
        persist()
    }

    func recordOverride() {
        count = 0
        lastOverrideDate = calendar.startOfDay(for: Date())
        persist()
    }

    // Internal setter for testing — allows injecting past dates
    func _setCount(_ value: Int, lastCompletedDate: Date?) {
        count = value
        self.lastCompletedDate = lastCompletedDate
        persist()
    }

    private func persist() {
        defaults.set(count, forKey: Keys.count)
        defaults.set(lastCompletedDate, forKey: Keys.lastCompleted)
        defaults.set(lastOverrideDate, forKey: Keys.lastOverride)
    }
}

// Otium/Stores/SessionStore.swift
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []

    private let defaults: UserDefaults
    private let retentionDays = 90
    private let key = "sessions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        pruneOldSessions()
    }

    func add(_ session: Session) {
        sessions.append(session)
        save()
    }

    var todaysSessions: [Session] {
        let cal = Calendar.current
        return sessions.filter { cal.isDateInToday($0.startTime) }
    }

    var todaysFocusTime: TimeInterval {
        todaysSessions.reduce(0) { $0 + $1.actualDuration }
    }

    var yesterdaysSessions: [Session] {
        sessions.filter { Calendar.current.isDateInYesterday($0.startTime) }
    }

    var yesterdaysFocusTime: TimeInterval {
        yesterdaysSessions.reduce(0) { $0 + $1.actualDuration }
    }

    var weeklyTotalFocusTime: TimeInterval {
        let weekStart = currentWeekStart()
        return sessions
            .filter { $0.startTime >= weekStart }
            .reduce(0) { $0 + $1.actualDuration }
    }

    var weeklyActiveDays: Int {
        let weekStart = currentWeekStart()
        let cal = Calendar.current
        let daysWithSessions = sessions
            .filter { $0.startTime >= weekStart }
            .map { cal.startOfDay(for: $0.startTime) }
        return Set(daysWithSessions).count
    }

    var dailyAverageFocusTime: TimeInterval {
        let active = weeklyActiveDays
        return active > 0 ? weeklyTotalFocusTime / Double(active) : 0
    }

    /// Returns weekday (1=Sun … 7=Sat) → total focus minutes for the current week.
    func weeklyMinutes() -> [Int: Double] {
        let cal = Calendar.current
        let weekStart = currentWeekStart()
        var result = [Int: Double]()
        for session in sessions where session.startTime >= weekStart {
            let weekday = cal.component(.weekday, from: session.startTime)
            result[weekday, default: 0] += session.actualDuration / 60
        }
        return result
    }

    private func currentWeekStart() -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return cal.date(from: comps) ?? cal.startOfDay(for: Date())
    }

    private func pruneOldSessions() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else { return }
        let before = sessions.count
        sessions = sessions.filter { $0.startTime >= cutoff }
        if sessions.count != before { save() }
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Session].self, from: data)
        else { return }
        sessions = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: key)
    }
}

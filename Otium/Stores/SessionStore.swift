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

    /// Returns weekday (1=Sun … 7=Sat) → total focus minutes for the current week.
    func weeklyMinutes() -> [Int: Double] {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        var result = [Int: Double]()
        for session in sessions where session.startTime >= weekStart {
            let weekday = cal.component(.weekday, from: session.startTime)
            result[weekday, default: 0] += session.actualDuration / 60
        }
        return result
    }

    private func pruneOldSessions() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else { return }
        let before = sessions.count
        sessions = sessions.filter { $0.startTime > cutoff }
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

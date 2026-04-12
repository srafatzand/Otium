// OtiumTests/SessionStoreTests.swift
import XCTest
@testable import Otium

@MainActor
final class SessionStoreTests: XCTestCase {
    var store: SessionStore!
    let suiteName = "test.sessions.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(suiteName: suiteName)!
        store = SessionStore(defaults: defaults)
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func makeSession(
        startTime: Date = Date(),
        duration: TimeInterval = 25 * 60,
        extendUsed: Bool = false,
        outcome: SessionOutcome = .completed
    ) -> Session {
        Session(startTime: startTime, plannedDuration: duration, actualDuration: duration, extendUsed: extendUsed, outcome: outcome)
    }

    func testAddSession_appearsInHistory() {
        let s = makeSession()
        store.add(s)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.id, s.id)
    }

    func testTodaysSessions_excludesYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        store.add(makeSession(startTime: yesterday))
        store.add(makeSession(startTime: Date()))
        XCTAssertEqual(store.todaysSessions.count, 1)
    }

    func testTodaysFocusTime_sumsActualDurations() {
        store.add(makeSession(duration: 25 * 60))
        store.add(makeSession(duration: 45 * 60))
        XCTAssertEqual(store.todaysFocusTime, 70 * 60, accuracy: 1)
    }

    func testPruneOldSessions_removesSessionsOlderThan90Days() {
        let old = Calendar.current.date(byAdding: .day, value: -91, to: Date())!
        store.add(makeSession(startTime: old))
        store.add(makeSession(startTime: Date()))
        // Re-init triggers pruning
        let defaults = UserDefaults(suiteName: suiteName)!
        let store2 = SessionStore(defaults: defaults)
        XCTAssertEqual(store2.sessions.count, 1)
    }

    func testWeeklyMinutes_sumsCorrectlyForToday() {
        store.add(makeSession(duration: 25 * 60))  // 25 min today
        let weekday = Calendar.current.component(.weekday, from: Date())
        let result = store.weeklyMinutes()
        XCTAssertEqual(result[weekday] ?? 0, 25, accuracy: 0.1)
    }

    func testSessionsPersistAcrossInstances() {
        store.add(makeSession())
        let defaults = UserDefaults(suiteName: suiteName)!
        let store2 = SessionStore(defaults: defaults)
        XCTAssertEqual(store2.sessions.count, 1)
    }
}

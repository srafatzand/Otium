// OtiumTests/StreakStoreTests.swift
import XCTest
@testable import Otium

@MainActor
final class StreakStoreTests: XCTestCase {
    var store: StreakStore!
    let suiteName = "test.streak.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(suiteName: suiteName)!
        store = StreakStore(defaults: defaults)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testInitialStreakIsZero() {
        XCTAssertEqual(store.count, 0)
    }

    func testRecordCleanSession_incrementsStreak() {
        store.recordCleanSession()
        XCTAssertEqual(store.count, 1)
    }

    func testRecordCleanSession_onlyIncrementsOncePerDay() {
        store.recordCleanSession()
        store.recordCleanSession()
        XCTAssertEqual(store.count, 1)
    }

    func testRecordOverride_resetsStreakToZero() {
        store.recordCleanSession()
        XCTAssertEqual(store.count, 1)
        store.recordOverride()
        XCTAssertEqual(store.count, 0)
    }

    func testGapInUsage_doesNotBreakStreak() {
        // Simulate 5-day streak from 3 days ago
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        store._setCount(5, lastCompletedDate: threeDaysAgo)
        // Record session today — should increment to 6, not reset
        store.recordCleanSession()
        XCTAssertEqual(store.count, 6)
    }

    func testOverrideToday_preventsStreakIncrementToday() {
        store.recordOverride()
        store.recordCleanSession()
        XCTAssertEqual(store.count, 0)
    }

    func testStreakPersistsAcrossInstances() {
        let defaults = UserDefaults(suiteName: suiteName)!
        store.recordCleanSession()
        let store2 = StreakStore(defaults: defaults)
        XCTAssertEqual(store2.count, 1)
    }

    func testSetCount_clearsOverrideDateSoIncrementIsPossible() {
        // Override today, then reset state to a past date — increment should work
        store.recordOverride()
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        store._setCount(5, lastCompletedDate: threeDaysAgo, lastOverrideDate: nil)
        store.recordCleanSession()
        XCTAssertEqual(store.count, 6)
    }
}

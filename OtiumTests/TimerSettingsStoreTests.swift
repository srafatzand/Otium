// OtiumTests/TimerSettingsStoreTests.swift
import XCTest
@testable import Otium

@MainActor
final class TimerSettingsStoreTests: XCTestCase {
    var store: TimerSettingsStore!
    let suiteName = "test.timersettings.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(suiteName: suiteName)!
        store = TimerSettingsStore(defaults: defaults)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultBreakDurationIsFiveMinutes() {
        XCTAssertEqual(store.breakDuration, 5 * 60)
        XCTAssertEqual(store.breakDurationMinutes, 5)
    }

    func testSetBreakDuration_updatesValue() {
        store.setBreakDuration(minutes: 10)
        XCTAssertEqual(store.breakDuration, 10 * 60)
        XCTAssertEqual(store.breakDurationMinutes, 10)
    }

    func testSetBreakDuration_clampsToMinimumFive() {
        store.setBreakDuration(minutes: 2)
        XCTAssertEqual(store.breakDuration, 5 * 60)
    }

    func testSetBreakDuration_clampsZeroToFive() {
        store.setBreakDuration(minutes: 0)
        XCTAssertEqual(store.breakDuration, 5 * 60)
    }

    func testPersistsAcrossInstances() {
        let defaults = UserDefaults(suiteName: suiteName)!
        store.setBreakDuration(minutes: 15)
        let store2 = TimerSettingsStore(defaults: defaults)
        XCTAssertEqual(store2.breakDuration, 15 * 60)
    }

    func testCorruptedDefaultsClampsToFive() {
        // Simulate a stored value below minimum (e.g. from a previous version)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(1, forKey: "timer.breakDuration")
        let store2 = TimerSettingsStore(defaults: defaults)
        XCTAssertEqual(store2.breakDuration, 5 * 60)
    }
}

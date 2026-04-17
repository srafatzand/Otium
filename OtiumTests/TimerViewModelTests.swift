// OtiumTests/TimerViewModelTests.swift
import XCTest
@testable import Otium

@MainActor
final class TimerViewModelTests: XCTestCase {
    var vm: TimerViewModel!
    var streakStore: StreakStore!
    var sessionStore: SessionStore!
    var settingsStore: TimerSettingsStore!
    let suiteName = "test.vm.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(suiteName: suiteName)!
        streakStore = StreakStore(defaults: defaults)
        sessionStore = SessionStore(defaults: defaults)
        settingsStore = TimerSettingsStore(defaults: defaults)
        vm = TimerViewModel(streakStore: streakStore, sessionStore: sessionStore, settingsStore: settingsStore)
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testInitialStateIsIdle() {
        XCTAssertEqual(vm.state, .idle)
    }

    func testStartSession_setsStateToRunning() {
        vm.startSession(duration: 25 * 60)
        XCTAssertEqual(vm.state, .running)
    }

    func testStartSession_resetsExtendUsed() {
        vm.startSession(duration: 10)
        vm._simulateTick(count: 10)
        vm._forceBreakActive()
        vm.useExtension()
        vm.stopSession()
        vm.startSession(duration: 25 * 60)
        XCTAssertFalse(vm.extendUsed)
    }

    func testStopSession_returnsToIdle() {
        vm.startSession(duration: 25 * 60)
        vm.stopSession()
        XCTAssertEqual(vm.state, .idle)
    }

    func testStopSession_doesNotLogSession() {
        vm.startSession(duration: 25 * 60)
        vm.stopSession()
        XCTAssertEqual(sessionStore.sessions.count, 0)
    }

    func testCountdownTick_decrementsTimeRemaining() {
        vm.startSession(duration: 60)
        vm._simulateTick(count: 1)
        XCTAssertEqual(vm.timeRemaining, 59, accuracy: 1)
    }

    func testSessionExpiry_transitionsToBreakPending() {
        vm.startSession(duration: 2)
        vm._simulateTick(count: 2)
        XCTAssertEqual(vm.state, .breakPending)
    }

    func testUseExtension_marksExtendUsedAndStartsExtension() {
        vm.startSession(duration: 2)
        vm._simulateTick(count: 2)
        vm._forceBreakActive()
        vm.useExtension()
        XCTAssertTrue(vm.extendUsed)
        XCTAssertEqual(vm.state, .extended)
    }

    func testUseExtension_canOnlyBeUsedOnce() {
        vm.startSession(duration: 2)
        vm._simulateTick(count: 2)
        vm._forceBreakActive()
        vm.useExtension()
        let stateAfterFirst = vm.state
        vm.useExtension()
        XCTAssertEqual(vm.state, stateAfterFirst)
    }

    func testOverride_resetsStreakAndLogsSession() {
        streakStore.recordCleanSession()
        XCTAssertEqual(streakStore.count, 1)
        vm.startSession(duration: 2)
        vm._simulateTick(count: 2)
        vm._forceBreakActive()
        vm.triggerOverride()
        XCTAssertEqual(streakStore.count, 0)
        XCTAssertEqual(sessionStore.sessions.first?.outcome, .overridden)
    }

    func testBreakCompletion_logsCompletedSessionAndIncrementsStreak() {
        vm.startSession(duration: 2)
        vm._simulateTick(count: 2)
        vm._forceBreakActive()
        vm._simulateBreakTick(count: 5 * 60)
        XCTAssertEqual(sessionStore.sessions.first?.outcome, .completed)
        XCTAssertEqual(streakStore.count, 1)
    }

    func testElapsedFraction_calculatesCorrectly() {
        vm.startSession(duration: 100)
        vm._simulateTick(count: 25)
        XCTAssertEqual(vm.elapsedFraction, 0.25, accuracy: 0.01)
    }

    func testRepeatSession_setsRepeatState() {
        vm.startSession(duration: 2, repeatCount: 3)
        XCTAssertEqual(vm.repeatTotal, 3)
        XCTAssertEqual(vm.repeatCurrent, 1)
    }

    func testRepeatSession_autoStartsNextAfterBreak() {
        vm.startSession(duration: 2, repeatCount: 2)
        vm._simulateTick(count: 2)       // session 1 expires → breakPending
        vm._forceBreakActive()            // → breakActive
        vm._simulateBreakTick(count: 300) // break ends → session 2 auto-starts
        XCTAssertEqual(vm.state, .running)
        XCTAssertEqual(vm.repeatCurrent, 2)
    }

    func testRepeatSession_isLastRepeatTrueOnFinalSession() {
        vm.startSession(duration: 2, repeatCount: 2)
        vm._simulateTick(count: 2)
        vm._forceBreakActive()
        vm._simulateBreakTick(count: 300) // session 2 starts
        vm._simulateTick(count: 2)        // session 2 expires
        XCTAssertTrue(vm.isLastRepeat)
        XCTAssertEqual(vm.state, .breakPending)
    }

    func testRepeatSession_stopResetsRepeatState() {
        vm.startSession(duration: 60, repeatCount: 3)
        vm.stopSession()
        XCTAssertEqual(vm.repeatTotal, 1)
        XCTAssertEqual(vm.repeatCurrent, 1)
    }

    func testCompleteBlock_logsSessionAndGoesIdle() {
        vm.startSession(duration: 2, repeatCount: 2)
        vm._simulateTick(count: 2)
        vm._forceBreakActive()
        vm._simulateBreakTick(count: 300) // session 2 starts
        vm._simulateTick(count: 2)        // session 2 expires (isLastRepeat = true)
        vm.completeBlock()
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.repeatTotal, 1)
        XCTAssertEqual(sessionStore.sessions.last?.outcome, .completed)
        XCTAssertEqual(streakStore.count, 1)
    }

    func testExtensionExpiry_completesSessionWithoutReshowingOverlay() {
        // Full extension cycle: session → expiry → break active → 5 more mins → extension expires
        vm.startSession(duration: 2)
        vm._simulateTick(count: 2)                // → breakPending
        vm._forceBreakActive()                    // → breakActive
        vm.useExtension()                         // → extended, timeRemaining = 5*60
        vm._simulateTick(count: 5 * 60)           // extension expires → completeBreak()
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(sessionStore.sessions.first?.outcome, .completed)
        XCTAssertEqual(sessionStore.sessions.first?.extendUsed, true)
        XCTAssertEqual(streakStore.count, 1)
    }
}

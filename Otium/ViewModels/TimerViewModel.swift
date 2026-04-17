// Otium/ViewModels/TimerViewModel.swift
import Foundation
import Combine

@MainActor
final class TimerViewModel: ObservableObject {
    @Published private(set) var state: TimerState = .idle
    @Published private(set) var timeRemaining: TimeInterval = 0
    @Published private(set) var breakTimeRemaining: TimeInterval
    @Published private(set) var extendUsed: Bool = false
    @Published private(set) var sessionDuration: TimeInterval = 25 * 60

    // Called by OverlayWindowController
    var onBreakStart: (() -> Void)?
    var onBreakEnd: (() -> Void)?

    private var timer: Timer?
    private var timerGeneration: Int = 0
    private var sessionStartTime: Date?
    private var sleepStartTime: Date?

    private let streakStore: StreakStore
    private let sessionStore: SessionStore
    private let settingsStore: TimerSettingsStore

    var breakDuration: TimeInterval { settingsStore.breakDuration }

    init(streakStore: StreakStore, sessionStore: SessionStore, settingsStore: TimerSettingsStore) {
        self.streakStore = streakStore
        self.sessionStore = sessionStore
        self.settingsStore = settingsStore
        self.breakTimeRemaining = settingsStore.breakDuration
    }

    // MARK: - Public API

    func startSession(duration: TimeInterval) {
        stopTimer()
        state = .running
        sessionDuration = duration
        timeRemaining = duration
        extendUsed = false
        sessionStartTime = Date()
        startTimer()
    }

    func stopSession() {
        stopTimer()
        if let start = sessionStartTime {
            let elapsed = Date().timeIntervalSince(start)
            if elapsed / sessionDuration >= 0.5 {
                sessionStore.add(Session(
                    startTime: start,
                    plannedDuration: sessionDuration,
                    actualDuration: elapsed,
                    extendUsed: extendUsed,
                    outcome: .stopped
                ))
            }
        }
        state = .idle
        sessionStartTime = nil
    }

    func useExtension() {
        guard state == .breakActive, !extendUsed else { return }
        stopTimer()
        extendUsed = true
        state = .extended
        timeRemaining = 5 * 60
        onBreakEnd?()
        startTimer()
    }

    func triggerOverride() {
        stopTimer()
        let elapsed = sessionStartTime.map { Date().timeIntervalSince($0) } ?? sessionDuration
        sessionStore.add(Session(
            startTime: sessionStartTime ?? Date(),
            plannedDuration: sessionDuration,
            actualDuration: elapsed,
            extendUsed: extendUsed,
            outcome: .overridden
        ))
        streakStore.recordOverride()
        state = .idle
        sessionStartTime = nil
        if extendUsed || state != .running {
            onBreakEnd?()
        }
    }

    var elapsedFraction: Double {
        guard sessionDuration > 0 else { return 0 }
        let elapsed = sessionDuration - timeRemaining
        return min(max(elapsed / sessionDuration, 0), 1)
    }

    // MARK: - Sleep / Wake

    func handleSystemWillSleep() {
        sleepStartTime = Date()
    }

    func handleSystemDidWake() {
        guard let slept = sleepStartTime else { return }
        let sleptFor = Date().timeIntervalSince(slept)
        sleepStartTime = nil
        guard state == .running || state == .extended else { return }
        timeRemaining = max(timeRemaining - sleptFor, 0)
        if timeRemaining == 0 {
            if state == .extended { completeBreak() } else { sessionExpired() }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timerGeneration += 1
        let gen = timerGeneration
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.timerGeneration == gen else { return }
                self.tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerGeneration += 1
    }

    // MARK: - Test helpers

    func _simulateTick(count: Int) {
        for _ in 0..<count { tick() }
    }

    func _simulateBreakTick(count: Int) {
        for _ in 0..<count { breakTick() }
    }

    func _forceBreakActive() {
        state = .breakActive
        breakTimeRemaining = settingsStore.breakDuration
        startTimer()
    }

    // MARK: - Private

    private func tick() {
        switch state {
        case .running, .extended:
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                timeRemaining = 0
                sessionExpired()
            }
        case .breakActive:
            breakTick()
        default:
            break
        }
    }

    private func breakTick() {
        if breakTimeRemaining > 1 {
            breakTimeRemaining -= 1
        } else {
            breakTimeRemaining = 0
            completeBreak()
        }
    }

    private func sessionExpired() {
        stopTimer()
        breakTimeRemaining = settingsStore.breakDuration
        state = .breakPending
        onBreakStart?()
    }

    private func completeBreak() {
        stopTimer()
        let totalDuration = sessionDuration + (extendUsed ? 5 * 60 : 0)
        sessionStore.add(Session(
            startTime: sessionStartTime ?? Date(),
            plannedDuration: sessionDuration,
            actualDuration: totalDuration,
            extendUsed: extendUsed,
            outcome: .completed
        ))
        streakStore.recordCleanSession()
        state = .idle
        sessionStartTime = nil
        onBreakEnd?()
    }
}

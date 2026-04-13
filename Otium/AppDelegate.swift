// Otium/AppDelegate.swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var streakStore: StreakStore!
    private var sessionStore: SessionStore!
    private var messageStore: MessageStore!
    private var viewModel: TimerViewModel!
    private var statusBarController: StatusBarController!
    private var overlayController: OverlayWindowController!
    private var midnightTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Stores
        streakStore = StreakStore()
        sessionStore = SessionStore()
        messageStore = MessageStore()

        // ViewModel
        viewModel = TimerViewModel(
            streakStore: streakStore,
            sessionStore: sessionStore
        )

        // Overlay controller
        overlayController = OverlayWindowController()

        // Wire break lifecycle
        viewModel.onBreakStart = { [weak self] in
            guard let self else { return }
            let message = self.messageStore.nextMessage()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.overlayController.show(
                    viewModel: self.viewModel,
                    streakStore: self.streakStore,
                    message: message
                )
                // Transition VM to breakActive after overlay fade-in animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.viewModel._forceBreakActive()
                }
            }
        }

        viewModel.onBreakEnd = { [weak self] in
            self?.overlayController.hide()
        }

        // Status bar
        statusBarController = StatusBarController(
            viewModel: viewModel,
            streakStore: streakStore,
            sessionStore: sessionStore,
            messageStore: messageStore
        )

        // Sleep / wake
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        scheduleMidnightRefresh()
    }

    private func scheduleMidnightRefresh() {
        let nextMidnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        let interval = nextMidnight.timeIntervalSinceNow
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.sessionStore.objectWillChange.send()
            self?.streakStore.objectWillChange.send()
            self?.scheduleMidnightRefresh()
        }
    }

    @objc private func systemWillSleep(_ note: Notification) {
        viewModel.handleSystemWillSleep()
    }

    @objc private func systemDidWake(_ note: Notification) {
        viewModel.handleSystemDidWake()
    }
}

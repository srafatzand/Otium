// Otium/Overlay/OverlayWindowController.swift
import AppKit
import SwiftUI

final class OverlayWindowController {
    private var windows: [NSWindow] = []

    func show(
        viewModel: TimerViewModel,
        streakStore: StreakStore,
        message: Message
    ) {
        guard windows.isEmpty else { return }

        for screen in NSScreen.screens {
            let window = makeWindow(for: screen, viewModel: viewModel, streakStore: streakStore, message: message)
            windows.append(window)
            window.orderFront(nil)
        }

        // Fade in
        windows.forEach { $0.alphaValue = 0 }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            windows.forEach { $0.animator().alphaValue = 1 }
        }

        // Listen for screen configuration changes while overlay is up
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func hide(completion: (() -> Void)? = nil) {
        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            windows.forEach { $0.animator().alphaValue = 0 }
        } completionHandler: { [weak self] in
            self?.windows.forEach { $0.orderOut(nil) }
            self?.windows.removeAll()
            completion?()
        }
    }

    @objc private func screensChanged() {
        // Remove windows for disconnected screens
        windows = windows.filter { $0.screen != nil }
    }

    private func makeWindow(
        for screen: NSScreen,
        viewModel: TimerViewModel,
        streakStore: StreakStore,
        message: Message
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false

        let overlay = BreakOverlayView(
            viewModel: viewModel,
            streakStore: streakStore,
            currentMessage: message
        )
        window.contentView = NSHostingView(rootView: overlay)
        return window
    }
}

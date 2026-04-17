// Otium/MenuBar/StatusBarController.swift
import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    init(
        viewModel: TimerViewModel,
        streakStore: StreakStore,
        sessionStore: SessionStore,
        messageStore: MessageStore,
        settingsStore: TimerSettingsStore
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient

        let root = PopoverView(
            viewModel: viewModel,
            streakStore: streakStore,
            sessionStore: sessionStore,
            messageStore: messageStore,
            settingsStore: settingsStore
        )
        popover.contentViewController = NSHostingController(rootView: root)
        popover.contentSize = NSSize(width: 250, height: 480)

        statusItem.button?.action = #selector(togglePopover(_:))
        statusItem.button?.target = self
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Observe state for icon updates
        viewModel.$state
            .combineLatest(viewModel.$timeRemaining, viewModel.$sessionDuration)
            .receive(on: RunLoop.main)
            .sink { [weak self, weak viewModel] _ in
                guard let vm = viewModel else { return }
                self?.updateButton(viewModel: vm)
            }
            .store(in: &cancellables)

        updateButton(viewModel: viewModel)
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            closePopover()
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func updateButton(viewModel: TimerViewModel) {
        guard let button = statusItem.button else { return }
        button.image = makeRingIcon(fraction: viewModel.elapsedFraction, state: viewModel.state)
        button.imagePosition = .imageLeft

        switch viewModel.state {
        case .running, .extended:
            let m = Int(viewModel.timeRemaining) / 60
            let s = Int(viewModel.timeRemaining) % 60
            button.title = String(format: " %d:%02d", m, s)
        case .breakActive, .breakPending:
            button.title = " Break"
        default:
            button.title = " Focus"
        }
    }

    private func makeRingIcon(fraction: Double, state: TimerState) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 5.5
            let lineWidth: CGFloat = 1.8

            // Background ring
            let bg = NSBezierPath()
            bg.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            bg.lineWidth = lineWidth
            NSColor(red: 0x37/255, green: 0x41/255, blue: 0x51/255, alpha: 1).setStroke()
            bg.stroke()

            // Progress arc
            if state == .running || state == .extended, fraction > 0 {
                let arc = NSBezierPath()
                let endAngle = CGFloat(90 - (360 * fraction))
                arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: endAngle, clockwise: true)
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                NSColor(red: 0xa7/255, green: 0x8b/255, blue: 0xfa/255, alpha: 1).setStroke()
                arc.stroke()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}

// Otium/Views/TimerControlView.swift
import SwiftUI

struct TimerControlView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var sessionStore: SessionStore
    @State private var selectedPreset: Int? = 25
    @State private var customText: String = ""
    @State private var repeatExpanded: Bool = false
    @State private var repeatCount: Int = 2

    private let presets = [25, 45, 60, 90]

    private var activeDuration: TimeInterval {
        if let custom = Int(customText), (1...180).contains(custom) {
            return TimeInterval(custom * 60)
        }
        return TimeInterval((selectedPreset ?? 25) * 60)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Ring + clock
                ZStack {
                    // Track
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 2)

                    // Progress arc (only while running)
                    if viewModel.state == .running || viewModel.state == .extended {
                        Circle()
                            .trim(from: 0, to: CGFloat(viewModel.elapsedFraction))
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "7c3aed"), Color(hex: "a78bfa")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }

                    // Soft glow
                    RadialGradient(
                        colors: [Color(hex: "7c3aed").opacity(0.12), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                    .clipShape(Circle())

                    // Clock
                    VStack(spacing: 4) {
                        Text(formattedTime)
                            .font(.system(size: 36, weight: .ultraLight, design: .monospaced))
                            .foregroundColor(Color(hex: "c4b5fd"))
                        Text(viewModel.state == .running || viewModel.state == .extended ? "FOCUSING" : "READY TO START")
                            .font(.system(size: 10))
                            .tracking(2)
                            .foregroundColor(viewModel.state == .running ? Color(hex: "7c3aed").opacity(0.8) : Color(hex: "4b5563"))
                    }
                }
                .frame(width: 148, height: 148)
                .padding(.top, 16)
                .padding(.bottom, 14)

                // Session dots — only during repeat blocks
                if viewModel.repeatTotal > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<viewModel.repeatTotal, id: \.self) { i in
                            let done = i < viewModel.repeatCurrent - 1
                            let current = i == viewModel.repeatCurrent - 1
                            ZStack {
                                if current {
                                    Circle()
                                        .fill(Color(hex: "a78bfa").opacity(0.25))
                                        .frame(width: 15, height: 15)
                                }
                                Circle()
                                    .fill(done || current ? Color(hex: "a78bfa") : Color.white.opacity(0.1))
                                    .frame(width: current ? 9 : 7, height: current ? 9 : 7)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }

                // Preset chips
                HStack(spacing: 5) {
                    ForEach(presets, id: \.self) { preset in
                        presetChip(preset)
                    }
                }
                .disabled(viewModel.state != .idle)
                .padding(.bottom, 6)

                // Custom input
                HStack(spacing: 4) {
                    TextField("custom", text: $customText)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 11))
                        .foregroundColor(!customText.isEmpty ? Color(hex: "a78bfa") : Color(hex: "4b5563"))
                        .frame(width: 54)
                        .onChange(of: customText) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue { customText = filtered }
                            if !filtered.isEmpty { selectedPreset = nil }
                        }
                        .onSubmit { validateCustom() }
                    Text("min")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "374151"))
                }
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(
                    !customText.isEmpty
                        ? Color(hex: "6366f1").opacity(0.1)
                        : Color.white.opacity(0.03)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            !customText.isEmpty ? Color(hex: "6366f1").opacity(0.4) : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .cornerRadius(6)
                .disabled(viewModel.state != .idle)
                .padding(.bottom, 14)

                // Repeat disclosure (idle only)
                if viewModel.state == .idle {
                    Button(action: toggleRepeat) {
                        HStack(spacing: 4) {
                            Text("Repeat")
                                .font(.system(size: 9, weight: .medium))
                                .tracking(1)
                                .foregroundColor(repeatExpanded ? Color(hex: "6366f1") : Color(hex: "374151"))
                            Image(systemName: repeatExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(repeatExpanded ? Color(hex: "6366f1") : Color(hex: "374151"))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 4)
                }

                if repeatExpanded && viewModel.state == .idle {
                    HStack {
                        Text("REPEAT")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.5)
                            .foregroundColor(Color(hex: "4b5563"))
                        Spacer()
                        HStack(spacing: 0) {
                            Button(action: { if repeatCount > 2 { repeatCount -= 1 } }) {
                                Text("−")
                                    .font(.system(size: 16, weight: .light))
                                    .frame(width: 34, height: 28)
                                    .foregroundColor(repeatCount <= 2 ? Color(hex: "374151") : Color(hex: "a78bfa"))
                            }
                            .buttonStyle(.plain)
                            .disabled(repeatCount <= 2)
                            Divider().frame(height: 14)
                            Text("× \(repeatCount)")
                                .font(.system(size: 12, weight: .light, design: .monospaced))
                                .foregroundColor(Color(hex: "c4b5fd"))
                                .frame(width: 36)
                            Divider().frame(height: 14)
                            Button(action: { repeatCount += 1 }) {
                                Text("+")
                                    .font(.system(size: 16, weight: .light))
                                    .frame(width: 34, height: 28)
                                    .foregroundColor(Color(hex: "a78bfa"))
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.white.opacity(0.03))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .cornerRadius(7)
                    }
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Start / Stop button
                Button(action: toggleSession) {
                    Group {
                        if viewModel.state != .idle {
                            Text("Stop Session")
                        } else if repeatExpanded {
                            Text("Start \(repeatCount) × \(Int(activeDuration / 60))m")
                        } else {
                            Text("Start Session")
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        viewModel.state == .idle
                            ? LinearGradient(colors: [Color(hex: "7c3aed"), Color(hex: "6366f1")], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.white.opacity(0.04), Color.white.opacity(0.04)], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(viewModel.state == .idle ? .white : Color(hex: "64748b"))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)

                // Today's sessions
                if !sessionStore.todaysSessions.isEmpty {
                    Divider().background(Color.white.opacity(0.06))

                    HStack {
                        Text("TODAY")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.5)
                            .foregroundColor(Color(hex: "4b5563"))
                        Spacer()
                        Text(formatFocusTime(sessionStore.todaysFocusTime))
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "6366f1"))
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    VStack(spacing: 2) {
                        ForEach(sessionStore.todaysSessions) { session in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(dotColor(for: session))
                                    .frame(width: 7, height: 7)
                                Text(formatTime(session.startTime))
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "94a3b8"))
                                Spacer()
                                Text(formatDuration(session.actualDuration))
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "64748b"))
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Helpers

    private var formattedTime: String {
        let t = viewModel.state == .idle ? activeDuration : viewModel.timeRemaining
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func presetChip(_ minutes: Int) -> some View {
        let selected = selectedPreset == minutes && customText.isEmpty
        return Button(action: {
            selectedPreset = minutes
            customText = ""
        }) {
            Text("\(minutes)m")
                .font(.system(size: 11))
                .foregroundColor(selected ? Color(hex: "a78bfa") : Color(hex: "4b5563"))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(selected ? Color(hex: "a78bfa").opacity(0.2) : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selected ? Color(hex: "a78bfa").opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                )
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func toggleRepeat() {
        withAnimation(.easeInOut(duration: 0.15)) {
            if repeatExpanded { repeatCount = 2 }
            repeatExpanded.toggle()
        }
    }

    private func toggleSession() {
        if viewModel.state == .idle {
            viewModel.startSession(duration: activeDuration, repeatCount: repeatExpanded ? repeatCount : 1)
            withAnimation { repeatExpanded = false }
        } else {
            viewModel.stopSession()
        }
    }

    private func validateCustom() {
        guard let val = Int(customText) else { customText = ""; return }
        if !(1...180).contains(val) { customText = String(min(max(val, 1), 180)) }
    }

    private func dotColor(for session: Session) -> Color {
        switch session.outcome {
        case .completed: return session.extendUsed ? Color(hex: "fbbf24") : Color(hex: "34d399")
        case .overridden: return Color(hex: "ef4444")
        case .stopped: return Color(hex: "60a5fa")
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let m = Int(interval / 60)
        return m < 60 ? "\(m) min" : "\(m / 60)h \(m % 60)m"
    }

    private func formatFocusTime(_ interval: TimeInterval) -> String {
        let m = Int(interval / 60)
        return m < 60 ? "\(m)m focused" : "\(m / 60)h \(m % 60)m focused"
    }
}

// Otium/Views/TimerControlView.swift
import SwiftUI

struct TimerControlView: View {
    @ObservedObject var viewModel: TimerViewModel
    @State private var selectedPreset: Int? = 25
    @State private var customText: String = ""

    private let presets = [25, 45, 60, 90]

    private var activeDuration: TimeInterval {
        if let custom = Int(customText), (1...180).contains(custom) {
            return TimeInterval(custom * 60)
        }
        return TimeInterval((selectedPreset ?? 25) * 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Large time display
            VStack(spacing: 4) {
                Text(formattedTime)
                    .font(.system(size: 44, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(Color(hex: "c4b5fd"))
                Text(viewModel.state == .running ? "FOCUSING" : "READY TO START")
                    .font(.system(size: 11))
                    .tracking(2)
                    .foregroundColor(viewModel.state == .running ? Color(hex: "7c3aed").opacity(0.6) : Color(hex: "4b5563"))
            }
            .padding(.vertical, 12)

            // Progress bar (running only)
            if viewModel.state == .running || viewModel.state == .extended {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 3)
                        LinearGradient(colors: [Color(hex: "7c3aed"), Color(hex: "a78bfa")], startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * viewModel.elapsedFraction, height: 3)
                    }
                }
                .frame(height: 3)
                .cornerRadius(2)
                .padding(.bottom, 16)
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

            // Start / Stop button
            Button(action: toggleSession) {
                Text(viewModel.state == .idle ? "Start Session" : "Stop Session")
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
        }
    }

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

    private func toggleSession() {
        if viewModel.state == .idle {
            viewModel.startSession(duration: activeDuration)
        } else {
            viewModel.stopSession()
        }
    }

    private func validateCustom() {
        guard let val = Int(customText) else { customText = ""; return }
        if !(1...180).contains(val) { customText = String(min(max(val, 1), 180)) }
    }
}

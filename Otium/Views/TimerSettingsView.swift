// Otium/Views/TimerSettingsView.swift
import SwiftUI

struct TimerSettingsView: View {
    @ObservedObject var settingsStore: TimerSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BREAK DURATION")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(Color(hex: "4b5563"))

            HStack(spacing: 0) {
                Button(action: decrement) {
                    Text("−")
                        .font(.system(size: 20, weight: .light))
                        .frame(width: 40, height: 34)
                        .foregroundColor(atMinimum ? Color(hex: "374151") : Color(hex: "a78bfa"))
                }
                .buttonStyle(.plain)
                .disabled(atMinimum)

                Divider().frame(height: 18)

                HStack(spacing: 3) {
                    Text("\(settingsStore.breakDurationMinutes)")
                        .font(.system(size: 14, weight: .light, design: .monospaced))
                        .foregroundColor(Color(hex: "c4b5fd"))
                    Text("min")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "4b5563"))
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 18)

                Button(action: increment) {
                    Text("+")
                        .font(.system(size: 20, weight: .light))
                        .frame(width: 40, height: 34)
                        .foregroundColor(Color(hex: "a78bfa"))
                }
                .buttonStyle(.plain)
            }
            .background(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .cornerRadius(8)

            Text("Minimum 5 minutes")
                .font(.system(size: 9))
                .foregroundColor(Color(hex: "374151"))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
    }

    private var atMinimum: Bool { settingsStore.breakDurationMinutes <= 5 }
    private func decrement() { settingsStore.setBreakDuration(minutes: settingsStore.breakDurationMinutes - 1) }
    private func increment() { settingsStore.setBreakDuration(minutes: settingsStore.breakDurationMinutes + 1) }
}

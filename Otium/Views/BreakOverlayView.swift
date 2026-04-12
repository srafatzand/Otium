// Otium/Views/BreakOverlayView.swift
import SwiftUI

struct BreakOverlayView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var streakStore: StreakStore
    let currentMessage: Message

    private var breakMinutes: Int { Int(viewModel.breakTimeRemaining) / 60 }
    private var breakSeconds: Int { Int(viewModel.breakTimeRemaining) % 60 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background
            LinearGradient(
                colors: [Color(hex: "1a1025"), Color(hex: "0f1a2e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Streak badge
            streakBadge
                .padding(20)

            // Centered content
            VStack(spacing: 16) {
                divider

                // Fixed headline
                Text("It's time to take a break.")
                    .font(.system(size: 26, weight: .regular, design: .default))
                    .foregroundColor(Color(hex: "e2e8f0"))

                // Rotating stoic quote card
                quoteCard

                divider

                // Break countdown
                Text("5 MINUTE BREAK")
                    .font(.system(size: 11, weight: .regular))
                    .tracking(3)
                    .foregroundColor(Color(hex: "6d5a8a"))

                Text(String(format: "%d:%02d", breakMinutes, breakSeconds))
                    .font(.system(size: 38, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(Color(hex: "a78bfa"))

                // Buttons
                HStack(spacing: 10) {
                    if !viewModel.extendUsed {
                        pillButton(label: "5 More Minutes", primary: true) {
                            viewModel.useExtension()
                        }
                    }
                    pillButton(label: "Override", primary: false) {
                        viewModel.triggerOverride()
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 4) {
            Text("🔥")
                .font(.system(size: 12))
            Text("\(streakStore.count) day streak")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "a78bfa"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(hex: "a78bfa").opacity(0.1))
        .overlay(
            Capsule().stroke(Color(hex: "a78bfa").opacity(0.2), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private var quoteCard: some View {
        VStack(spacing: 8) {
            Text("\u{201C}\(currentMessage.text)\u{201D}")
                .font(.system(size: 13))
                .italic()
                .foregroundColor(Color(hex: "7c6fa0"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 340)

            if let attribution = currentMessage.attribution {
                Text("— \(attribution)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "3d3550"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private var divider: some View {
        LinearGradient(
            colors: [.clear, Color(hex: "a78bfa"), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 40, height: 1)
    }

    private func pillButton(label: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(primary ? Color(hex: "a78bfa") : Color(hex: "374151"))
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(primary ? Color(hex: "a78bfa").opacity(0.12) : Color.white.opacity(0.03))
                .overlay(
                    Capsule().stroke(
                        primary ? Color(hex: "a78bfa").opacity(0.25) : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color hex helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

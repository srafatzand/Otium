// Otium/Views/SettingsHomeView.swift
import SwiftUI

enum SettingsDetail {
    case timer
    case messages
}

struct SettingsHomeView: View {
    @Binding var detail: SettingsDetail?

    var body: some View {
        VStack(spacing: 6) {
            navCard(icon: "⏱", title: "Timer", destination: .timer)
            navCard(icon: "💬", title: "Break Messages", destination: .messages)
            navCard(icon: "🔁", title: "Repeat Sessions", destination: nil, disabled: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func navCard(icon: String, title: String, destination: SettingsDetail?, disabled: Bool = false) -> some View {
        Button(action: {
            if let dest = destination { detail = dest }
        }) {
            HStack {
                HStack(spacing: 8) {
                    Text(icon)
                        .font(.system(size: 12))
                        .opacity(0.8)
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(disabled ? Color(hex: "374151") : Color(hex: "94a3b8"))
                }
                Spacer()
                Text("›")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(disabled ? Color(hex: "2d3748") : Color(hex: "4b5563"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.07), lineWidth: 1))
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

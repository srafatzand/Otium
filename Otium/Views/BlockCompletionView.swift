// Otium/Views/BlockCompletionView.swift
import SwiftUI

struct BlockCompletionView: View {
    let repeatTotal: Int
    let currentMessage: Message
    @ObservedObject var streakStore: StreakStore
    let onDismiss: () -> Void

    @State private var canDismiss = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [Color(hex: "1a1025"), Color(hex: "0f1a2e")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Streak badge
            HStack(spacing: 4) {
                Text("🔥").font(.system(size: 12))
                Text("\(streakStore.count) day streak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "a78bfa"))
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color(hex: "a78bfa").opacity(0.1))
            .overlay(Capsule().stroke(Color(hex: "a78bfa").opacity(0.2), lineWidth: 1))
            .clipShape(Capsule())
            .padding(20)

            VStack(spacing: 16) {
                LinearGradient(colors: [.clear, Color(hex: "a78bfa"), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 40, height: 1)

                Text("\(repeatTotal) of \(repeatTotal) complete.")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundColor(Color(hex: "e2e8f0"))

                VStack(spacing: 8) {
                    Text("\u{201C}\(currentMessage.text)\u{201D}")
                        .font(.system(size: 13)).italic()
                        .foregroundColor(Color(hex: "7c6fa0"))
                        .multilineTextAlignment(.center).lineSpacing(4)
                        .frame(maxWidth: 340)
                    if let attr = currentMessage.attribution {
                        Text("— \(attr)").font(.system(size: 11)).foregroundColor(Color(hex: "3d3550"))
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.07), lineWidth: 1))
                .cornerRadius(10)

                LinearGradient(colors: [.clear, Color(hex: "a78bfa"), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 40, height: 1)

                if canDismiss {
                    Text("click anywhere to continue")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "374151"))
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture { if canDismiss { onDismiss() } }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { canDismiss = true }
            }
        }
    }
}

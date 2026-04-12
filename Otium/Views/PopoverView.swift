// Otium/Views/PopoverView.swift
import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var streakStore: StreakStore
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var messageStore: MessageStore
    @State private var showMessages = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.state == .running ? Color(hex: "a78bfa") : Color(hex: "374151"))
                        .frame(width: 8, height: 8)
                        .overlay(
                            viewModel.state == .running
                                ? Circle().fill(Color(hex: "a78bfa").opacity(0.3)).frame(width: 14, height: 14) : nil
                        )
                    Text("OTIUM")
                        .font(.system(size: 12))
                        .tracking(1)
                        .foregroundColor(Color(hex: "94a3b8"))
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 12))
                    Text("\(streakStore.count) day streak")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "a78bfa"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: "a78bfa").opacity(0.1))
                .overlay(Capsule().stroke(Color(hex: "a78bfa").opacity(0.2), lineWidth: 1))
                .clipShape(Capsule())

                Button(action: { showMessages.toggle() }) {
                    Image(systemName: showMessages ? "xmark.circle" : "gearshape")
                        .foregroundColor(Color(hex: "374151"))
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.06))

            if showMessages {
                MessagesSettingsView(messageStore: messageStore)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        TimerControlView(viewModel: viewModel)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.vertical, 12)

                        SessionHistoryView(sessionStore: sessionStore)
                            .padding(.horizontal, 20)
                    }
                }
            }

            Divider().background(Color.white.opacity(0.05))
            HStack {
                Text("\(sessionStore.todaysSessions.count) sessions today")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "374151"))
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "374151"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "1a1025"), Color(hex: "0f1a2e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .preferredColorScheme(.dark)
    }
}

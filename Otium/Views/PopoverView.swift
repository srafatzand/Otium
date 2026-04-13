// Otium/Views/PopoverView.swift
import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var streakStore: StreakStore
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var messageStore: MessageStore

    private enum ActiveTab { case focus, dashboard, settings }
    @State private var activeTab: ActiveTab = .focus

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
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.06))

            // Tab bar
            HStack(spacing: 0) {
                tabButton("Focus", tab: .focus)
                tabButton("Dashboard", tab: .dashboard)
                tabButton("Settings", tab: .settings)
            }
            .background(Color.white.opacity(0.03))

            Divider().background(Color.white.opacity(0.06))

            // Main content
            Group {
                switch activeTab {
                case .focus:
                    TimerControlView(viewModel: viewModel, sessionStore: sessionStore)
                case .dashboard:
                    DashboardView(sessionStore: sessionStore, streakStore: streakStore)
                case .settings:
                    MessagesSettingsView(messageStore: messageStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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

    private func tabButton(_ label: String, tab: ActiveTab) -> some View {
        Button(action: { activeTab = tab }) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundColor(activeTab == tab ? Color(hex: "a78bfa") : Color(hex: "4b5563"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) {
                    if activeTab == tab {
                        Rectangle()
                            .fill(Color(hex: "7c4dff"))
                            .frame(height: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

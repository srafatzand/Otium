// Otium/Views/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var streakStore: StreakStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {

                // MARK: – Stat boxes
                HStack(spacing: 8) {
                    statBox(
                        value: formatDuration(sessionStore.weeklyTotalFocusTime),
                        label: "WEEK TOTAL"
                    )
                    statBox(
                        value: formatDuration(sessionStore.dailyAverageFocusTime),
                        label: "DAILY AVG"
                    )
                    statBox(
                        value: "🔥 \(streakStore.count)",
                        label: "STREAK"
                    )
                }

                Divider().background(Color.white.opacity(0.06)).padding(.vertical, 4)

                // MARK: – Weekly bar chart
                Text("THIS WEEK")
                    .font(.system(size: 11))
                    .tracking(2)
                    .foregroundColor(Color(hex: "4b5563"))

                weeklyChart

                Divider().background(Color.white.opacity(0.06)).padding(.vertical, 4)

                // MARK: – Today section
                HStack {
                    Text("TODAY")
                        .font(.system(size: 11))
                        .tracking(2)
                        .foregroundColor(Color(hex: "4b5563"))
                    Spacer()
                    Text(focusTimeSummary(sessionStore.todaysFocusTime))
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "6366f1"))
                }

                if sessionStore.todaysSessions.isEmpty {
                    Text("No sessions yet")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "374151"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                } else {
                    VStack(spacing: 5) {
                        ForEach(sessionStore.todaysSessions) { session in
                            sessionRow(session)
                        }
                    }
                }

                // MARK: – Yesterday section (conditional)
                if !sessionStore.yesterdaysSessions.isEmpty {
                    Divider().background(Color.white.opacity(0.06)).padding(.vertical, 4)

                    HStack {
                        Text("YESTERDAY")
                            .font(.system(size: 11))
                            .tracking(2)
                            .foregroundColor(Color(hex: "4b5563"))
                        Spacer()
                        Text(focusTimeSummary(sessionStore.yesterdaysFocusTime))
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "6366f1"))
                    }

                    VStack(spacing: 5) {
                        ForEach(sessionStore.yesterdaysSessions) { session in
                            sessionRow(session)
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: – Stat box helper
    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: "e2e8f0"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .tracking(1)
                .foregroundColor(Color(hex: "4b5563"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
        .cornerRadius(8)
    }

    // MARK: – Weekly bar chart (copied from SessionHistoryView)
    private var weeklyChart: some View {
        let data = sessionStore.weeklyMinutes()
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let weekdays = [2, 3, 4, 5, 6, 7, 1]
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        let maxVal = weekdays.map { data[$0] ?? 0 }.max() ?? 1

        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(zip(weekdays, labels)), id: \.0) { weekday, label in
                let minutes = data[weekday] ?? 0
                let fraction = maxVal > 0 ? minutes / maxVal : 0
                let isToday = weekday == todayWeekday

                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            isToday
                                ? Color(hex: "6366f1").opacity(0.6)
                                : Color(hex: "a78bfa").opacity(0.3)
                        )
                        .frame(height: max(CGFloat(fraction) * 32, 3))
                        .overlay(
                            isToday ? RoundedRectangle(cornerRadius: 3).stroke(Color(hex: "a78bfa").opacity(0.4), lineWidth: 1) : nil
                        )
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundColor(isToday ? Color(hex: "a78bfa") : Color(hex: "374151"))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 48)
    }

    // MARK: – Session row
    private func sessionRow(_ session: Session) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor(for: session))
                .frame(width: 7, height: 7)
            Text(formatTime(session.startTime))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "94a3b8"))
            Text(formatDuration(session.actualDuration))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "64748b"))
            Spacer()
            Text(outcomeLabel(for: session))
                .font(.system(size: 11))
                .foregroundColor(outcomeColor(for: session))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
    }

    // MARK: – Helpers

    private func dotColor(for session: Session) -> Color {
        switch session.outcome {
        case .completed: return session.extendUsed ? Color(hex: "fbbf24") : Color(hex: "34d399")
        case .overridden: return Color(hex: "ef4444")
        case .stopped: return Color(hex: "60a5fa")
        }
    }

    private func outcomeLabel(for session: Session) -> String {
        switch session.outcome {
        case .completed: return session.extendUsed ? "+5m ext" : "completed"
        case .overridden: return "overridden"
        case .stopped: return "stopped early"
        }
    }

    private func outcomeColor(for session: Session) -> Color {
        switch session.outcome {
        case .completed: return session.extendUsed ? Color(hex: "fbbf24") : Color(hex: "34d399")
        case .overridden: return Color(hex: "ef4444")
        case .stopped: return Color(hex: "60a5fa")
        }
    }

    private func focusTimeSummary(_ interval: TimeInterval) -> String {
        let totalMin = Int(interval / 60)
        if totalMin < 60 { return "\(totalMin)m focused" }
        return "\(totalMin / 60)h \(totalMin % 60)m focused"
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalMin = Int(interval / 60)
        if totalMin < 60 { return "\(totalMin)m" }
        return "\(totalMin / 60)h \(totalMin % 60)m"
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

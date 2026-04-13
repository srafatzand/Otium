// Otium/Views/SessionHistoryView.swift
import SwiftUI

struct SessionHistoryView: View {
    @ObservedObject var sessionStore: SessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Today header
            HStack {
                Text("TODAY")
                    .font(.system(size: 11))
                    .tracking(2)
                    .foregroundColor(Color(hex: "4b5563"))
                Spacer()
                Text(formattedFocusTime)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "6366f1"))
            }

            // Session list
            VStack(spacing: 5) {
                ForEach(sessionStore.todaysSessions.suffix(10)) { session in
                    sessionRow(session)
                }
            }

            // Weekly chart
            Divider().background(Color.white.opacity(0.06)).padding(.vertical, 4)

            Text("THIS WEEK")
                .font(.system(size: 11))
                .tracking(2)
                .foregroundColor(Color(hex: "4b5563"))

            weeklyChart
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        HStack {
            Circle()
                .fill(dotColor(for: session))
                .frame(width: 6, height: 6)
            Text(formattedTime(session.startTime))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "94a3b8"))
            Spacer()
            Text(formattedDuration(session.actualDuration))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "64748b"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
    }

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

    private var formattedFocusTime: String {
        let totalMinutes = Int(sessionStore.todaysFocusTime / 60)
        if totalMinutes < 60 { return "\(totalMinutes)m focused" }
        return "\(totalMinutes / 60)h \(totalMinutes % 60)m focused"
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: date)
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        "\(Int(interval / 60)) min"
    }

    private func dotColor(for session: Session) -> Color {
        switch session.outcome {
        case .completed: return session.extendUsed ? Color(hex: "fbbf24") : Color(hex: "34d399")
        case .overridden: return Color(hex: "ef4444")
        case .stopped: return Color(hex: "60a5fa")
        }
    }
}

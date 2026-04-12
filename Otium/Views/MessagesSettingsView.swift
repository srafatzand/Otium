// Otium/Views/MessagesSettingsView.swift
import SwiftUI

struct MessagesSettingsView: View {
    @ObservedObject var messageStore: MessageStore
    @State private var newText: String = ""
    @State private var newAttribution: String = ""
    @State private var showResetConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BREAK MESSAGES")
                .font(.system(size: 11))
                .tracking(2)
                .foregroundColor(Color(hex: "4b5563"))

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(messageStore.allMessages) { message in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(message.text)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "94a3b8"))
                                    .lineLimit(2)
                                if let attr = message.attribution {
                                    Text("— \(attr)")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "4b5563"))
                                }
                            }
                            Spacer()
                            Button(action: { messageStore.delete(message) }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(Color(hex: "374151"))
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(6)
                    }
                }
            }
            .frame(maxHeight: 160)

            Divider().background(Color.white.opacity(0.06))

            VStack(spacing: 6) {
                TextField("New message…", text: $newText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "94a3b8"))
                    .padding(8)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(6)

                HStack {
                    TextField("Attribution (optional)", text: $newAttribution)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "64748b"))
                        .padding(8)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(6)

                    Button("Add") {
                        guard !newText.isEmpty else { return }
                        messageStore.addCustom(text: newText, attribution: newAttribution.isEmpty ? nil : newAttribution)
                        newText = ""
                        newAttribution = ""
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "a78bfa"))
                    .disabled(newText.isEmpty)
                }
            }

            Button("Reset to defaults") { showResetConfirm = true }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "374151"))
                .confirmationDialog("Reset all messages to defaults?", isPresented: $showResetConfirm) {
                    Button("Reset", role: .destructive) { messageStore.resetToDefaults() }
                }
        }
        .padding()
    }
}

//
//  SettingsView.swift
//  LinkedByte
//
//  Edited by Yohannes Haile on 6/11/25.
//

import SwiftUI
import UserNotifications

/// App-wide settings stored in UserDefaults
enum AppSettings {
    @AppStorage("useStreaming") static var useStreaming: Bool = true
    @AppStorage("temperature") static var temperature: Double = 0.7
    @AppStorage("systemInstructions") static var systemInstructions: String = ByteLines.shared.lines


    @AppStorage("personalContext") static var personalContext: String = "I am a programmer."
    @AppStorage("brainstormingTime") static var brainstormingTime: Double = Date().timeIntervalSince1970
}

/// Settings screen for configuring AI behavior
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var onDismiss: (() -> Void)?
    
    @AppStorage("useStreaming") private var useStreaming = AppSettings.useStreaming
    @AppStorage("temperature") private var temperature = AppSettings.temperature
    @AppStorage("systemInstructions") private var systemInstructions = AppSettings.systemInstructions
    @AppStorage("personalContext") private var personalContext = AppSettings.personalContext
    @AppStorage("brainstormingTime") private var brainstormingTime = AppSettings.brainstormingTime
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Generation") {
                    Toggle("Stream Responses", isOn: $useStreaming)
                    VStack(alignment: .leading) {
                        Text("Temperature: \(temperature, specifier: "%.2f")")
                        Slider(value: $temperature, in: 0.0...2.0, step: 0.1)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Awareness") {
                    TextEditor(text: $personalContext)
                        .frame(minHeight: 120)
                        .font(.body)
                }
                
                Section("Daily LinkedIn Post Reminder") {
                    DatePicker(
                        "Reminder Time",
                        selection: Binding(
                            get: { Date(timeIntervalSince1970: brainstormingTime) },
                            set: { brainstormingTime = $0.timeIntervalSince1970 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    Text("You'll get your daily post idea at this time.")
                }
                .onChange(of: brainstormingTime) {
                    scheduleNotificationForBrainstormingTime()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onDisappear { onDismiss?() }
    }
    
    private func scheduleNotificationForBrainstormingTime() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted, error == nil else { return }
            center.removePendingNotificationRequests(withIdentifiers: ["dailyLinkedInPost"]) // Remove old
            let content = UNMutableNotificationContent()
            content.title = "Daily Dose of LinkedIn post is here"
            content.body = "Tap to view your LinkedIn post suggestion!"
            content.sound = .default
            content.categoryIdentifier = "DAILY_POST"
            var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: Date(timeIntervalSince1970: brainstormingTime))
            dateComponents.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "dailyLinkedInPost", content: content, trigger: trigger)
            center.add(request)
            // NOTE: See App/SceneDelegate for notification tap handling to route to chat with suggestion.
        }
    }
}


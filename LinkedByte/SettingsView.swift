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
    @AppStorage("systemInstructions") static var systemInstructions: String = """
    🔧 System Instruction for LinkedByte
    Identity & Role: You are LinkedByte, a context-aware assistant that serves as a career coach, strategic mentor, and LinkedIn post collaborator for users.

    🎯 Primary Objectives:
    1. Career Development Advisor Support users in navigating their career paths by offering personalized, thoughtful guidance. Help them reflect on goals, develop new skills, and strategically position themselves for opportunities.
    2. LinkedIn Content Partner Collaborate with users to craft original, authentic, and relevant LinkedIn posts that reflect their professional identity, values, and current focus. Each post should help the user educate, inspire, connect, or reflect.
    3. Context-Aware Strategist Use the user-provided context (from the app’s Awareness field) to tailor all feedback and content. This includes their industry, role, technical stack, goals, tone preferences, and personal constraints.

    🧠 Adapt to Context Dynamically:
    Always rely on the Awareness field in the app to understand the user’s current reality. Tailor your tone, content style, and recommendations accordingly. When context is unclear or insufficient, ask follow-up questions before proceeding.

    📣 When Crafting LinkedIn Posts:
    Your responsibility is to help users create authentic, high-quality posts. Ensure that each post:
    1. Reflects the User’s Voice Prioritize originality and personality. Avoid formulaic or “AI-sounding” language.
    2. Delivers Value Help the user teach, reflect, or provoke thought through storytelling, frameworks, or personal insights.
    3. Aligns with Career Positioning Support the user in establishing thought leadership, credibility, and community engagement.
    4. Is Emotionally Honest (When Appropriate) Empower users to integrate real experiences—technical, emotional, or philosophical—when relevant.
    5. Encourages Engagement Suggest ways to invite dialogue (e.g., thought-provoking questions, call-to-actions) without being clickbaity.

    ✍️ Examples of Post Themes to Support:
    * Technical deep dives or implementation learnings
    * Product or team reflections
    * Mentorship and career growth stories
    * Lessons from failure or recovery
    * Insights from conferences, books, or code reviews
    * Thoughtful hot takes on trends or shifts in their field

    🧭 Career Coaching Guidelines:
    * Reflective First: Help the user clarify their thoughts before giving direction.
    * Empowerment-Oriented: Encourage ownership of one’s story, choices, and pace.
    * Tailored Suggestions: Base your feedback on the context available in the Awareness field. Avoid one-size-fits-all answers.
    * Strategic Guidance: Offer advice that aligns short-term steps with long-term vision and professional identity.
    * Balanced Encouragement: Provide motivation without pressure. Help users pursue progress without burnout.

    🔒 Guardrails:
    * No Misrepresentation: Do not fabricate credentials, inflate skills, or promote dishonest narratives.
    * No Generic Filler: Avoid shallow motivational quotes or platitudes.
    * No Overexertion Advice: Respect the user’s bandwidth and stated constraints (e.g., energy limits, time availability, mental health).
    * Context First: Always defer to the Awareness field when determining tone, direction, or content priority.

    ✅ LinkedIn Post Tone Checklist:
    Each post should aim to be:
    *  Honest & personal
    *  Insightful or story-driven
    *  Technically or professionally relevant
    *  Clear and accessible
    *  Strategically aligned with the user’s brand
    *  Grounded in reality (not hype or exaggeration)

    🔁 Continuous Improvement:
    You may ask the user clarifying questions when needed. You are allowed to prompt reflection and gently challenge assumptions in order to support thoughtful decisions.
    Your role is to help the user write, grow, and position themselves intentionally — balancing ambition with authenticity.
    """


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


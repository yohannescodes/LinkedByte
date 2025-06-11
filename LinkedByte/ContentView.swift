//
//  ContentView.swift
//  LinkedByte
//
//  Edited by Yohannes Haile on 6/11/25.
//

import SwiftUI
import Combine
import FoundationModels

/// Main chat interface view
struct ContentView: View {
    // MARK: - Environment
    
    @EnvironmentObject var appRouter: AppLaunchRouter
    
    // MARK: - State Properties
    
    // UI State
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isResponding = false
    @State private var showSettings = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showDailySuggestion: Bool = false
    @State private var hasShownSuggestionForThisLaunch = false
    
    // Model State
    @State private var session: LanguageModelSession?
    @State private var streamingTask: Task<Void, Never>?
    @State private var model = SystemLanguageModel.default
    
    // Settings
    @AppStorage("useStreaming") private var useStreaming = AppSettings.useStreaming
    @AppStorage("temperature") private var temperature = AppSettings.temperature
    @AppStorage("systemInstructions") private var systemInstructions = AppSettings.systemInstructions
    @AppStorage("personalContext") private var personalContext = AppSettings.personalContext
    
    // Haptics
    private let hapticButtonGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let hapticStreamGenerator = UISelectionFeedbackGenerator()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Chat Messages ScrollView
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack {
                            ForEach(messages) { message in
                                MessageView(message: message, isResponding: isResponding)
                                    .id(message.id)
                                    .background(
                                        // Highlight daily suggestion message
                                        (showDailySuggestion && message == messages.last && message.role == .assistant)
                                        ? Color.yellow.opacity(0.3)
                                        : Color.clear
                                    )
                                    .cornerRadius(10)
                                    .overlay(
                                        (showDailySuggestion && message == messages.last && message.role == .assistant)
                                        ? RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.orange, lineWidth: 2)
                                        : nil
                                    )
                                    .padding(.vertical, 2)
                            }
                        }
                        .padding()
                        .padding(.bottom, 90) // Space for floating input field
                    }
                    .onChange(of: messages.last?.text) { oldValue, newValue in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: showDailySuggestion) { newValue in
                        if newValue, let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        // Observe appRouter.showDailySuggestion changes
                        if !hasShownSuggestionForThisLaunch && appRouter.showDailySuggestion {
                            showSuggestion()
                        }
                    }
                    .task {
                        if !hasShownSuggestionForThisLaunch && appRouter.showDailySuggestion {
                            showSuggestion()
                        }
                    }
                    .onReceive(appRouter.$showDailySuggestion) { newValue in
                        if newValue && !hasShownSuggestionForThisLaunch {
                            showSuggestion()
                        }
                    }
                }
                
                // Floating Input Field
                VStack {
                    Spacer()
                    inputField
                        .padding(20)
                }
            }
            .navigationTitle("LinkedByte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showSettings) {
                SettingsView {
                    session = nil // Reset session on settings change
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Suggestion Handling
    
    private func showSuggestion() {
        hasShownSuggestionForThisLaunch = true
        showDailySuggestion = true
        let suggestionPrompt = "Give me a LinkedIn post suggestion for today."
        messages.append(ChatMessage(role: .user, text: suggestionPrompt))
        messages.append(ChatMessage(role: .assistant, text: ""))
        
        isResponding = true
        streamingTask = Task {
            do {
                if session == nil { session = createSession() }
                guard let currentSession = session else {
                    showError(message: "Session could not be created.")
                    isResponding = false
                    return
                }
                let options = GenerationOptions(temperature: temperature)
                if useStreaming {
                    let stream = currentSession.streamResponse(to: suggestionPrompt, options: options)
                    for try await partialResponse in stream {
                        hapticStreamGenerator.selectionChanged()
                        updateLastMessage(with: partialResponse)
                    }
                } else {
                    let response = try await currentSession.respond(to: suggestionPrompt, options: options)
                    updateLastMessage(with: response.content)
                }
            } catch is CancellationError {
                // User cancelled generation
            } catch {
                showError(message: "An error occurred: \(error.localizedDescription)")
            }
            isResponding = false
            streamingTask = nil
        }
    }
    
    // MARK: - Subviews
    
    /// Floating input field with send/stop button
    private var inputField: some View {
        ZStack {
            TextField("Ask anything", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .frame(minHeight: 22)
                .disabled(isResponding)
                .onSubmit {
                    if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        handleSendOrStop()
                    }
                }
                .padding(16)
            
            HStack {
                Spacer()
                Button(action: handleSendOrStop) {
                    Image(systemName: isResponding ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(isSendButtonDisabled ? Color.gray.opacity(0.6) : .primary)
                }
                .disabled(isSendButtonDisabled)
                .animation(.easeInOut(duration: 0.2), value: isResponding)
                .animation(.easeInOut(duration: 0.2), value: isSendButtonDisabled)
                .glassEffect(.regular.interactive())
                .padding(.trailing, 8)
            }
        }
        .glassEffect(.regular.interactive())
    }
    
    private var isSendButtonDisabled: Bool {
        return inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isResponding
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: resetConversation) { Label("New Chat", systemImage: "square.and.pencil") }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showSettings = true }) { Label("Settings", systemImage: "gearshape") }
        }
    }
    
    // MARK: - Model Interaction
    
    private func handleSendOrStop() {
        hapticButtonGenerator.impactOccurred()
        
        if isResponding {
            stopStreaming()
        } else {
            guard model.isAvailable else {
                showError(message: "The language model is not available. Reason: \(availabilityDescription(for: model.availability))")
                return
            }
            sendMessage()
        }
    }
    
    private func sendMessage() {
        isResponding = true
        let userMessage = ChatMessage(role: .user, text: inputText)
        messages.append(userMessage)
        let prompt = inputText
        inputText = ""
        
        // Add empty assistant message for streaming
        messages.append(ChatMessage(role: .assistant, text: ""))
        
        hapticStreamGenerator.prepare()
        
        streamingTask = Task {
            do {
                if session == nil { session = createSession() }
                
                guard let currentSession = session else {
                    showError(message: "Session could not be created.")
                    isResponding = false
                    return
                }
                
                let options = GenerationOptions(temperature: temperature)
                
                if useStreaming {
                    let stream = currentSession.streamResponse(to: prompt, options: options)
                    for try await partialResponse in stream {
                        hapticStreamGenerator.selectionChanged()
                        updateLastMessage(with: partialResponse)
                    }
                } else {
                    let response = try await currentSession.respond(to: prompt, options: options)
                    updateLastMessage(with: response.content)
                }
            } catch is CancellationError {
                // User cancelled generation
            } catch {
                showError(message: "An error occurred: \(error.localizedDescription)")
            }
            
            isResponding = false
            streamingTask = nil
        }
    }
    
    private func stopStreaming() {
        streamingTask?.cancel()
    }
    
    @MainActor
    private func updateLastMessage(with text: String) {
        messages[messages.count - 1].text = text
    }
    
    // MARK: - Session & Helpers
    
    private func createSession() -> LanguageModelSession {
        let basics = systemInstructions + " " + personalContext
        return LanguageModelSession(instructions: basics)
    }
    
    private func resetConversation() {
        hapticButtonGenerator.impactOccurred()
        stopStreaming()
        messages.removeAll()
        session = nil
    }
    
    private func availabilityDescription(for availability: SystemLanguageModel.Availability) -> String {
        switch availability {
            case .available:
                return "Available"
            case .unavailable(let reason):
                switch reason {
                    case .deviceNotEligible:
                        return "Device not eligible"
                    case .appleIntelligenceNotEnabled:
                        return "Apple Intelligence not enabled in Settings"
                    case .modelNotReady:
                        return "Model assets not downloaded"
                    @unknown default:
                        return "Unknown reason"
                }
            @unknown default:
                return "Unknown availability"
        }
    }
    
    @MainActor
    private func showError(message: String) {
        self.errorMessage = message
        self.showErrorAlert = true
        self.isResponding = false
    }
}

#Preview {
    ContentView()
}

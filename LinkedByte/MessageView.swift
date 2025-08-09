//
//  MessageView.swift
//  LinkedByte
//
//  Edited by Yohannes Haile on 6/11/25.
//

import SwiftUI

/// Represents the role of a chat participant
enum ChatRole {
    case user
    case assistant
}

/// Represents a single message in the chat conversation
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    var role: ChatRole
    var text: String
}


/// View for displaying a single chat message
struct MessageView: View {
    let message: ChatMessage
    let isResponding: Bool
    
    @State private var copied = false
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                Text(message.text)
                    .padding(12)
                    .foregroundColor(.white)
                    .background(.blue)
                    .clipShape(.rect(cornerRadius: 18))
                    .glassEffect(in: .rect(cornerRadius: 18))
                
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if message.text.isEmpty && isResponding {
                        PulsingDotView()
                            .frame(width: 60, height: 25)
                    } else {
                        Text(message.text)
                            .textSelection(.enabled)
                        Button(action: {
                            UIPasteboard.general.string = message.text
                            withAnimation { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { copied = false }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                            }
                            .font(.caption)
                            .padding(6)
                            .background(Color.gray.opacity(0.10))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        if copied {
                            Text("Copied!")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .transition(.opacity)
                        }
                    }
                }
                .padding(.vertical, 8)
                Spacer()
            }
        }
        .padding(.vertical, 6)
    }
}

/// Animated loading indicator shown while AI is generating a response
struct PulsingDotView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(.primary.opacity(0.5))
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}

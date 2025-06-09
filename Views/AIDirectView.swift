//
//  AIDirectView.swift
//  DaVinci Resolve Transcript Processor
//
//  Created for markobosko-git on 2025-06-09
//  Current UTC: 2025-06-09 22:48:36
//

import SwiftUI

struct AIDirectView: View {
    @ObservedObject var apiManager: APIManager
    @State private var selectedAI: AIModel = .claude
    @State private var messageText = ""
    @State private var isSending = false
    @State private var chatMessages: [ChatMessage] = []
    
    enum AIModel: String, CaseIterable {
        case claude = "Claude"
        case deepseek = "DeepSeek"
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Panel - AI Selection
            VStack(spacing: 20) {
                SectionHeader(icon: "bubble.left.and.text.bubble.right", title: "Direct AI Chat")
                
                VStack(spacing: 12) {
                    Text("Select AI Model")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(AIModel.allCases, id: \.self) { model in
                        AIModelButton(
                            model: model,
                            isSelected: selectedAI == model,
                            onSelect: {
                                selectedAI = model
                            }
                        )
                    }
                }
                .padding()
                .background(Color(hex: "252525"))
                .cornerRadius(12)
                
                // API Status Section
                VStack(spacing: 12) {
                    Text("API Status")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Image(systemName: apiManager.getClaudeKey().isEmpty ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(apiManager.getClaudeKey().isEmpty ? .red : .green)
                        
                        Text("Claude API")
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(apiManager.getClaudeKey().isEmpty ? "Not Set" : "Configured")
                            .font(.caption)
                            .foregroundColor(apiManager.getClaudeKey().isEmpty ? .red : .green)
                    }
                    .padding(12)
                    .background(Color(hex: "2d2d2d"))
                    .cornerRadius(8)
                    
                    HStack {
                        Image(systemName: apiManager.getDeepSeekKey().isEmpty ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(apiManager.getDeepSeekKey().isEmpty ? .red : .green)
                        
                        Text("DeepSeek API")
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(apiManager.getDeepSeekKey().isEmpty ? "Not Set" : "Configured")
                            .font(.caption)
                            .foregroundColor(apiManager.getDeepSeekKey().isEmpty ? .red : .green)
                    }
                    .padding(12)
                    .background(Color(hex: "2d2d2d"))
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(hex: "252525"))
                .cornerRadius(12)
                
                Spacer()
            }
            .frame(width: 280)
            .padding(20)
            .background(Color(hex: "1a1a1a"))
            
            // Right Panel - Chat Interface
            VStack(spacing: 0) {
                // Chat Header
                HStack {
                    Image(systemName: selectedAI == .claude ? "cpu" : "brain.head.profile")
                        .foregroundColor(Color(hex: "4a9eff"))
                        .font(.title2)
                    
                    Text("Chat with \(selectedAI.rawValue)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        chatMessages = []
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Chat")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding()
                .background(Color(hex: "252525"))
                
                // Chat Messages
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(chatMessages) { message in
                            ChatMessageView(message: message)
                        }
                        
                        // Auto-scroll to bottom with dummy view
                        if !chatMessages.isEmpty {
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                    }
                    .padding()
                }
                .background(Color(hex: "1a1a1a"))
                
                // Message Input
                HStack(spacing: 12) {
                    TextField("Type your message...", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isSending)
                    
                    Button(action: sendMessage) {
                        HStack {
                            if isSending {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Sending...")
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Send")
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
                .padding()
                .background(Color(hex: "252525"))
            }
            .background(Color(hex: "1a1a1a"))
        }
        .onChange(of: chatMessages) { _ in
            scrollToBottom()
        }
    }
    
    private func scrollToBottom() {
        if !chatMessages.isEmpty {
            // Slight delay to ensure ScrollView is updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    ScrollViewReader { scrollView in
                        scrollView.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(
            id: UUID(),
            text: messageText,
            isUser: true,
            timestamp: Date()
        )
        
        chatMessages.append(userMessage)
        let userPrompt = messageText
        messageText = ""
        isSending = true
        
        Task {
            do {
                let response = try await selectedAI == .claude ? 
                    sendToClaudeDirectly(prompt: userPrompt) : 
                    sendToDeepSeekDirectly(prompt: userPrompt)
                
                await MainActor.run {
                    let aiMessage = ChatMessage(
                        id: UUID(),
                        text: response,
                        isUser: false,
                        timestamp: Date()
                    )
                    chatMessages.append(aiMessage)
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(
                        id: UUID(),
                        text: "Error: \(error.localizedDescription)",
                        isUser: false,
                        timestamp: Date(),
                        isError: true
                    )
                    chatMessages.append(errorMessage)
                    isSending = false
                }
            }
        }
    }
    
    private func sendToClaudeDirectly(prompt: String) async throws -> String {
        let apiKey = apiManager.getClaudeKey()
        guard !apiKey.isEmpty else {
            throw AIDirectError.missingAPIKey("Claude API key is not configured. Please add it in the API Keys tab.")
        }
        
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 4000,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw APIError.apiError(message)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw APIError.invalidResponse
        }
        
        return text
    }
    
    private func sendToDeepSeekDirectly(prompt: String) async throws -> String {
        let apiKey = apiManager.getDeepSeekKey()
        guard !apiKey.isEmpty else {
            throw AIDirectError.missingAPIKey("DeepSeek API key is not configured. Please add it in the API Keys tab.")
        }
        
        let url = URL(string: "https://api.deepseek.com/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 4000,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw APIError.apiError(message)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw APIError.invalidResponse
        }
        
        return apiManager.cleanMarkdownSymbols(content)
    }
}

struct AIModelButton: View {
    let model: AIDirectView.AIModel
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: model == .claude ? "cpu" : "brain.head.profile")
                    .foregroundColor(isSelected ? .white : .secondary)
                
                Text(model.rawValue)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .secondary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "4a9eff"))
                }
            }
            .padding()
            .background(isSelected ? Color(hex: "4a9eff").opacity(0.3) : Color(hex: "2d2d2d"))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    var isError: Bool = false
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top) {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(12)
                    .background(
                        message.isError ? Color.red.opacity(0.3) :
                            message.isUser ? Color(hex: "4a9eff") : Color(hex: "2d2d2d")
                    )
                    .foregroundColor(message.isUser ? .white : .white)
                    .cornerRadius(12)
                
                Text(message.formattedTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

enum AIDirectError: LocalizedError {
    case missingAPIKey(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let message):
            return message
        }
    }
}
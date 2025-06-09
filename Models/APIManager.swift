//
//  APIManager.swift
//  DaVinci Resolve Transcript Processor
//
//  Created for markobosko-git on 2025-06-09
//  Current UTC: 2025-06-09 22:48:36
//

import Foundation
import Combine

class APIManager: ObservableObject {
    @Published var claudeOutput = ""
    @Published var deepseekOutput = ""
    @Published var isClaudeProcessing = false
    @Published var isDeepseekProcessing = false
    @Published var isTestingClaude = false
    @Published var isTestingDeepSeek = false
    @Published var claudeTestResult = ""
    @Published var deepseekTestResult = ""
    @Published var claudeTestSuccess = false
    @Published var deepseekTestSuccess = false
    
    // Callback closures for processing completion events
    var onClaudeProcessingCompleted: (() -> Void)?
    var onDeepSeekProcessingCompleted: (() -> Void)?
    
    private let userDefaults = UserDefaults.standard
    private let claudeKeyIdentifier = "com.markobosko-git.davinci.claude-api-key"
    private let deepseekKeyIdentifier = "com.markobosko-git.davinci.deepseek-api-key"
    
    // MARK: - API Key Management (Simple UserDefaults Storage)
    func setClaudeKey(_ key: String) {
        userDefaults.set(key, forKey: claudeKeyIdentifier)
    }
    
    func setDeepSeekKey(_ key: String) {
        userDefaults.set(key, forKey: deepseekKeyIdentifier)
    }
    
    func getClaudeKey() -> String {
        return userDefaults.string(forKey: claudeKeyIdentifier) ?? ""
    }
    
    func getDeepSeekKey() -> String {
        return userDefaults.string(forKey: deepseekKeyIdentifier) ?? ""
    }
    
    // MARK: - Claude API Integration
    func processWithClaude(prompt: String, content: String) {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NotificationManager.shared.showError("Please enter a prompt first")
            return
        }
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NotificationManager.shared.showError("No transcript content to process")
            return
        }
        
        let apiKey = getClaudeKey()
        guard !apiKey.isEmpty else {
            NotificationManager.shared.showError("Please enter your Claude API key in the API Keys tab")
            return
        }
        
        isClaudeProcessing = true
        claudeOutput = ""
        
        Task {
            do {
                let result = try await callClaudeAPI(apiKey: apiKey, prompt: prompt, content: content)
                await MainActor.run {
                    self.claudeOutput = result
                    self.isClaudeProcessing = false
                    NotificationManager.shared.showSuccess("Claude processing completed!")
                    self.onClaudeProcessingCompleted?()
                }
            } catch {
                await MainActor.run {
                    self.claudeOutput = "Error: \(error.localizedDescription)"
                    self.isClaudeProcessing = false
                    NotificationManager.shared.showError("Claude error: \(error.localizedDescription)")
                    self.onClaudeProcessingCompleted?()
                }
            }
        }
    }
    
    private func callClaudeAPI(apiKey: String, prompt: String, content: String) async throws -> String {
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
                    "content": "\(prompt)\n\nTranscript content:\n\n\(content)"
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
    
    // MARK: - DeepSeek API Integration
    func processWithDeepSeek(prompt: String, content: String) {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NotificationManager.shared.showError("Please enter a prompt first")
            return
        }
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NotificationManager.shared.showError("No transcript content to process")
            return
        }
        
        let apiKey = getDeepSeekKey()
        guard !apiKey.isEmpty else {
            NotificationManager.shared.showError("Please enter your DeepSeek API key in the API Keys tab")
            return
        }
        
        isDeepseekProcessing = true
        deepseekOutput = ""
        
        Task {
            do {
                let result = try await callDeepSeekAPI(apiKey: apiKey, prompt: prompt, content: content)
                await MainActor.run {
                    // Clean markdown symbols from DeepSeek output
                    self.deepseekOutput = self.cleanMarkdownSymbols(result)
                    self.isDeepseekProcessing = false
                    NotificationManager.shared.showSuccess("DeepSeek processing completed!")
                    self.onDeepSeekProcessingCompleted?()
                }
            } catch {
                await MainActor.run {
                    self.deepseekOutput = "Error: \(error.localizedDescription)"
                    self.isDeepseekProcessing = false
                    NotificationManager.shared.showError("DeepSeek error: \(error.localizedDescription)")
                    self.onDeepSeekProcessingCompleted?()
                }
            }
        }
    }
    
    private func callDeepSeekAPI(apiKey: String, prompt: String, content: String) async throws -> String {
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
                    "content": "\(prompt)\n\nTranscript content:\n\n\(content)"
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
        
        return content
    }
    
    // Make this public so it can be used from AIDirectView
    func cleanMarkdownSymbols(_ text: String) -> String {
        var cleaned = text
        
        // Remove markdown headers (# ## ###)
        cleaned = cleaned.replacingOccurrences(of: #"^#{1,6}\s*"#, with: "", options: .regularExpression)
        
        // Remove bold (**text** or __text__)
        cleaned = cleaned.replacingOccurrences(of: #"\*\*(.*?)\*\*"#, with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"__(.*?)__"#, with: "$1", options: .regularExpression)
        
        // Remove italic (*text* or _text_)
        cleaned = cleaned.replacingOccurrences(of: #"\*(.*?)\*"#, with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"_(.*?)_"#, with: "$1", options: .regularExpression)
        
        // Remove code blocks (```code```)
        cleaned = cleaned.replacingOccurrences(of: #"```[\s\S]*?```"#, with: "", options: .regularExpression)
        
        // Remove inline code (`code`)
        cleaned = cleaned.replacingOccurrences(of: #"`(.*?)`"#, with: "$1", options: .regularExpression)
        
        // Remove links [text](url)
        cleaned = cleaned.replacingOccurrences(of: #"\[([^\]]*)\]\([^\)]*\)"#, with: "$1", options: .regularExpression)
        
        // Remove horizontal rules (---)
        cleaned = cleaned.replacingOccurrences(of: #"^---+$"#, with: "", options: [.regularExpression, .caseInsensitive])
        
        // Remove bullet points (- or *)
        cleaned = cleaned.replacingOccurrences(of: #"^[\s]*[-\*]\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
        
        // Clean up extra whitespace
        cleaned = cleaned.replacingOccurrences(of: #"\n\s*\n"#, with: "\n\n", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    // MARK: - API Testing
    func testClaudeAPI() {
        let apiKey = getClaudeKey()
        guard !apiKey.isEmpty else {
            claudeTestResult = "Please enter your Claude API key first"
            claudeTestSuccess = false
            return
        }
        
        isTestingClaude = true
        claudeTestResult = ""
        claudeTestSuccess = false
        
        Task {
            do {
                let result = try await testClaudeConnection(apiKey: apiKey)
                await MainActor.run {
                    self.claudeTestResult = result
                    self.claudeTestSuccess = true
                    self.isTestingClaude = false
                }
            } catch {
                await MainActor.run {
                    self.claudeTestResult = "Test failed: \(error.localizedDescription)"
                    self.claudeTestSuccess = false
                    self.isTestingClaude = false
                }
            }
        }
    }
    
    private func testClaudeConnection(apiKey: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 20,
            "messages": [
                [
                    "role": "user",
                    "content": "Hello, please respond with \"API test successful\""
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
        
        return "✅ Claude API connection successful! Ready to process transcripts."
    }
    
    func testDeepSeekAPI() {
        let apiKey = getDeepSeekKey()
        guard !apiKey.isEmpty else {
            deepseekTestResult = "Please enter your DeepSeek API key first"
            deepseekTestSuccess = false
            return
        }
        
        isTestingDeepSeek = true
        deepseekTestResult = ""
        deepseekTestSuccess = false
        
        Task {
            do {
                let result = try await testDeepSeekConnection(apiKey: apiKey)
                await MainActor.run {
                    self.deepseekTestResult = result
                    self.deepseekTestSuccess = true
                    self.isTestingDeepSeek = false
                }
            } catch {
                await MainActor.run {
                    self.deepseekTestResult = "Test failed: \(error.localizedDescription)"
                    self.deepseekTestSuccess = false
                    self.isTestingDeepSeek = false
                }
            }
        }
    }
    
    private func testDeepSeekConnection(apiKey: String) async throws -> String {
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
                    "content": "Hello, please respond with \"API test successful\""
                ]
            ],
            "max_tokens": 20,
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
        
        return "✅ DeepSeek API connection successful! Ready to process transcripts."
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return message
        }
    }
}
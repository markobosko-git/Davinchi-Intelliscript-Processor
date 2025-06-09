//
//  TranscriptManager.swift
//  DaVinci Resolve Transcript Processor
//
//  Created for markobosko-git on 2025-06-09
//  Current UTC: 2025-06-09 22:48:36
//

import Foundation
import AppKit
import SwiftUI

class TranscriptManager: ObservableObject {
    @Published var transcriptContent: String = ""
    @Published var speakers: Set<String> = []
    @Published var activeSpeakers: Set<String> = []
    @Published var segments: [TranscriptSegment] = []
    @Published var characterCount: Int = 0
    @Published var wordCount: Int = 0
    @Published var timeRange: String = "00:00:00 - 00:00:00"
    @Published var isContentFiltered: Bool = false
    
    struct TranscriptSegment: Identifiable {
        let id = UUID()
        let speaker: String
        let text: String
        let startTime: String
        let endTime: String
    }
    
    // MARK: - Initialization
    
    init() {
        // Set up the manager
    }
    
    // MARK: - Content Management
    
    func loadTranscript(from url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            DispatchQueue.main.async {
                self.transcriptContent = content
                self.parseTranscript(content)
                
                NotificationManager.shared.showSuccess("Transcript loaded successfully")
            }
        } catch {
            DispatchQueue.main.async {
                NotificationManager.shared.showError("Failed to load transcript: \(error.localizedDescription)")
            }
        }
    }
    
    func parseTranscript(_ content: String) {
        // Reset state
        segments = []
        speakers = []
        characterCount = content.count
        wordCount = content.split(separator: " ").count
        
        // Simple parsing logic (would be more complex for real SRT/VTT)
        let lines = content.components(separatedBy: .newlines)
        var currentSpeaker = ""
        var startTime = "00:00:00"
        var endTime = "00:00:00"
        
        for line in lines {
            // Example format: [10:30:15] SPEAKER: Text content
            if let speakerRange = line.range(of: #"^\[(.*?)\]\s+([^:]+):(.*)$"#, options: .regularExpression) {
                let fullMatch = line[speakerRange]
                
                if let timeRange = line.range(of: #"^\[(.*?)\]"#, options: .regularExpression),
                   let speakerNameRange = line.range(of: #"]\s+([^:]+):"#, options: .regularExpression),
                   let contentRange = line.range(of: #":[^:]*$"#, options: .regularExpression) {
                    
                    let timeString = String(line[timeRange]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    startTime = timeString
                    
                    // Estimate end time (simple implementation)
                    let components = timeString.components(separatedBy: ":")
                    if components.count == 3, 
                       let hours = Int(components[0]),
                       let minutes = Int(components[1]),
                       let seconds = Int(components[2]) {
                        
                        // Add 5 seconds for end time (simplified)
                        var newSeconds = seconds + 5
                        var newMinutes = minutes
                        var newHours = hours
                        
                        if newSeconds >= 60 {
                            newSeconds -= 60
                            newMinutes += 1
                        }
                        
                        if newMinutes >= 60 {
                            newMinutes -= 60
                            newHours += 1
                        }
                        
                        endTime = String(format: "%02d:%02d:%02d", newHours, newMinutes, newSeconds)
                    }
                    
                    let speakerText = line[speakerNameRange]
                    let speakerStartIndex = speakerText.index(speakerText.startIndex, offsetBy: 2)
                    let speakerEndIndex = speakerText.index(speakerText.endIndex, offsetBy: -1)
                    let speaker = String(speakerText[speakerStartIndex..<speakerEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    currentSpeaker = speaker
                    
                    speakers.insert(speaker)
                    activeSpeakers.insert(speaker)
                    
                    let contentText = String(line[contentRange]).dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let segment = TranscriptSegment(
                        speaker: speaker,
                        text: contentText,
                        startTime: startTime,
                        endTime: endTime
                    )
                    
                    segments.append(segment)
                }
            }
        }
        
        // Calculate time range
        if let firstSegment = segments.first, let lastSegment = segments.last {
            timeRange = "\(firstSegment.startTime) - \(lastSegment.endTime)"
        }
    }
    
    func clearTranscript() {
        transcriptContent = ""
        speakers = []
        activeSpeakers = []
        segments = []
        characterCount = 0
        wordCount = 0
        timeRange = "00:00:00 - 00:00:00"
        
        NotificationManager.shared.showInfo("Transcript cleared")
    }
    
    func exportTranscript() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        panel.nameFieldStringValue = "processed_transcript_\(timestamp).txt"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                do {
                    try transcriptContent.write(to: url, atomically: true, encoding: .utf8)
                    NotificationManager.shared.showSuccess("Transcript saved successfully")
                } catch {
                    NotificationManager.shared.showError("Failed to save transcript: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Speaker Filtering
    
    func toggleSpeaker(_ speaker: String) {
        if activeSpeakers.contains(speaker) {
            activeSpeakers.remove(speaker)
        } else {
            activeSpeakers.insert(speaker)
        }
        
        isContentFiltered = activeSpeakers.count != speakers.count
    }
    
    func clearAllFilters() {
        activeSpeakers = []
        isContentFiltered = true
        NotificationManager.shared.showInfo("All speaker filters cleared")
    }
    
    func getSegmentCount(for speaker: String) -> Int {
        return segments.filter { $0.speaker == speaker }.count
    }
    
    func getFilteredContent() -> String {
        if activeSpeakers.isEmpty {
            // No speakers selected, return empty content
            return ""
        }
        
        if activeSpeakers.count == speakers.count {
            // All speakers selected, return full content
            return transcriptContent
        }
        
        // Filter segments by active speakers
        let filteredSegments = segments.filter { activeSpeakers.contains($0.speaker) }
        
        // Reconstruct transcript with only active speakers
        var filteredContent = ""
        for segment in filteredSegments {
            filteredContent += "[\(segment.startTime)] \(segment.speaker): \(segment.text)\n"
        }
        
        return filteredContent
    }
}
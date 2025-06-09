//
//  TranscriptSegment.swift
//  DaVinci Resolve Transcript Processor
//
//  Created for markobosko-git on 2025-06-08
//  Current UTC: 2025-06-09 22:48:36
//

import Foundation
import AppKit
import UniformTypeIdentifiers

struct TranscriptSegment: Identifiable, Codable {
    var id = UUID()
    let timecode: String
    let startTime: String
    let endTime: String
    let speaker: String
    let text: String
    let originalLines: [String]
    
    init(timecode: String, startTime: String, endTime: String, speaker: String, text: String, originalLines: [String]) {
        self.timecode = timecode
        self.startTime = startTime
        self.endTime = endTime
        self.speaker = speaker
        self.text = text
        self.originalLines = originalLines
    }
}

// MARK: - Transcript Manager
class TranscriptManager: ObservableObject {
    @Published var transcriptContent = ""
    @Published var segments: [TranscriptSegment] = []
    @Published var speakers: Set<String> = []
    @Published var activeSpeakers: Set<String> = []
    @Published var characterCount = 0
    @Published var wordCount = 0
    @Published var timeRange = "--:--:-- - --:--:--"
    
    private var originalContent = ""
    
    func loadTranscript(from url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            handleTranscriptContent(content)
            NotificationManager.shared.showSuccess("File loaded successfully!")
        } catch {
            NotificationManager.shared.showError("Failed to load file: \(error.localizedDescription)")
        }
    }
    
    func handleTranscriptContent(_ content: String) {
        originalContent = content
        transcriptContent = content
        processTranscript(content)
        updateStats()
    }
    
    private func processTranscript(_ content: String) {
        segments = []
        speakers = []
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            activeSpeakers = []
            return
        }
        
        let parsedSegments = parseDaVinciFormat(content)
        
        guard !parsedSegments.isEmpty else {
            activeSpeakers = []
            return
        }
        
        segments = parsedSegments
        
        for segment in segments {
            if !segment.speaker.isEmpty {
                speakers.insert(segment.speaker)
            }
        }
        
        activeSpeakers = speakers
        applyFilter()
    }
    
    private func parseDaVinciFormat(_ content: String) -> [TranscriptSegment] {
        var segments: [TranscriptSegment] = []
        let lines = content.components(separatedBy: .newlines)
        var currentSegment: (timecode: String, startTime: String, endTime: String, speaker: String, text: String, originalLines: [String])? = nil
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check for timecode pattern [HH:MM:SS:FF - HH:MM:SS:FF]
            let timecodePattern = #"^\[(\d{2}:\d{2}:\d{2}:\d{2})\s*-\s*(\d{2}:\d{2}:\d{2}:\d{2})\]$"#
            
            if let regex = try? NSRegularExpression(pattern: timecodePattern),
               let match = regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) {
                
                // Save previous segment if it exists
                if let current = currentSegment, !current.speaker.isEmpty, !current.text.isEmpty {
                    segments.append(TranscriptSegment(
                        timecode: current.timecode,
                        startTime: current.startTime,
                        endTime: current.endTime,
                        speaker: current.speaker,
                        text: current.text,
                        originalLines: current.originalLines
                    ))
                }
                
                // Extract times
                let startTime = String(trimmedLine[Range(match.range(at: 1), in: trimmedLine)!])
                let endTime = String(trimmedLine[Range(match.range(at: 2), in: trimmedLine)!])
                
                // Start new segment
                currentSegment = (
                    timecode: trimmedLine,
                    startTime: startTime,
                    endTime: endTime,
                    speaker: "",
                    text: "",
                    originalLines: [trimmedLine]
                )
                
            } else if var current = currentSegment {
                current.originalLines.append(line)
                
                if !trimmedLine.isEmpty {
                    if current.speaker.isEmpty {
                        current.speaker = trimmedLine
                    } else {
                        if !current.text.isEmpty {
                            current.text += " " + trimmedLine
                        } else {
                            current.text = trimmedLine
                        }
                    }
                }
                
                currentSegment = current
            }
        }
        
        // Save final segment
        if let current = currentSegment, !current.speaker.isEmpty, !current.text.isEmpty {
            segments.append(TranscriptSegment(
                timecode: current.timecode,
                startTime: current.startTime,
                endTime: current.endTime,
                speaker: current.speaker,
                text: current.text,
                originalLines: current.originalLines
            ))
        }
        
        return segments
    }
    
    func toggleSpeaker(_ speaker: String) {
        if activeSpeakers.contains(speaker) {
            activeSpeakers.remove(speaker)
        } else {
            activeSpeakers.insert(speaker)
        }
        applyFilter()
    }
    
    func clearAllFilters() {
        activeSpeakers = speakers
        applyFilter()
    }
    
    private func applyFilter() {
        if activeSpeakers.isEmpty {
            transcriptContent = ""
        } else if activeSpeakers.count == speakers.count {
            transcriptContent = originalContent
        } else {
            let filteredSegments = segments.filter { activeSpeakers.contains($0.speaker) }
            transcriptContent = filteredSegments.map { $0.originalLines.joined(separator: "\n") }.joined(separator: "\n\n")
        }
        updateStats()
    }
    
    private func updateStats() {
        characterCount = transcriptContent.count
        wordCount = transcriptContent.isEmpty ? 0 : transcriptContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        
        if let firstSegment = segments.first, let lastSegment = segments.last {
            timeRange = "\(firstSegment.startTime) - \(lastSegment.endTime)"
        } else {
            timeRange = "--:--:-- - --:--:--"
        }
    }
    
    func getSegmentCount(for speaker: String) -> Int {
        return segments.filter { $0.speaker == speaker }.count
    }
    
    func getFilteredContent() -> String {
        return transcriptContent
    }
    
    func clearTranscript() {
        transcriptContent = ""
        originalContent = ""
        segments = []
        speakers = []
        activeSpeakers = []
        updateStats()
    }
    
    func exportTranscript() {
        guard !transcriptContent.isEmpty else {
            NotificationManager.shared.showError("No transcript content to export")
            return
        }
        
        let panel = NSSavePanel()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let filterInfo = activeSpeakers.count < speakers.count ? "_filtered_\(activeSpeakers.count)speakers" : "_full"
        panel.nameFieldStringValue = "davinci_transcript_\(timestamp)\(filterInfo).txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                do {
                    try transcriptContent.write(to: url, atomically: true, encoding: .utf8)
                    NotificationManager.shared.showSuccess("Transcript exported successfully!")
                } catch {
                    NotificationManager.shared.showError("Failed to export: \(error.localizedDescription)")
                }
            }
        }
    }
}
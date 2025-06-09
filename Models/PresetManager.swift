//
//  PresetManager.swift
//  DaVinci Resolve Transcript Processor
//
//  Created for markobosko-git on 2025-06-09
//  Current UTC: 2025-06-09 22:48:36
//

import Foundation
import Combine

class PresetManager: ObservableObject {
    @Published var presets: [PresetButton] = []
    @Published var selectedPreset: PresetButton?
    
    private let userDefaults = UserDefaults.standard
    private let presetsKey = "com.markobosko-git.davinci.saved-presets"
    
    init() {
        loadPresets()
    }
    
    private func loadPresets() {
        if let savedData = userDefaults.data(forKey: presetsKey),
           let decodedPresets = try? JSONDecoder().decode([PresetButton].self, from: savedData) {
            self.presets = decodedPresets
        } else {
            // Create default presets if none exist
            self.presets = [
                PresetButton(title: "Summary", prompt: "Summarize this transcript in bullet points."),
                PresetButton(title: "Key Points", prompt: "Extract the key points from this transcript."),
                PresetButton(title: "Action Items", prompt: "List all action items mentioned in this transcript.")
            ]
            savePresets()
        }
    }
    
    func savePresets() {
        if let encodedData = try? JSONEncoder().encode(presets) {
            userDefaults.set(encodedData, forKey: presetsKey)
        }
    }
    
    func addPreset(title: String, prompt: String) {
        let newPreset = PresetButton(title: title, prompt: prompt)
        presets.append(newPreset)
        savePresets()
    }
    
    func updatePreset(id: UUID, title: String, prompt: String) {
        if let index = presets.firstIndex(where: { $0.id == id }) {
            presets[index].title = title
            presets[index].prompt = prompt
            savePresets()
        }
    }
    
    func deletePreset(at indexSet: IndexSet) {
        presets.remove(atOffsets: indexSet)
        savePresets()
    }
    
    func movePreset(from source: IndexSet, to destination: Int) {
        presets.move(fromOffsets: source, toOffset: destination)
        savePresets()
    }
}

struct PresetButton: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var prompt: String
    
    static func == (lhs: PresetButton, rhs: PresetButton) -> Bool {
        return lhs.id == rhs.id
    }
}

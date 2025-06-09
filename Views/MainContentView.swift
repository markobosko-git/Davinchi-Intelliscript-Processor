//
//  ContentView.swift
//  DaVinci Resolve Transcript Processor
//
//  Created for markobosko-git on 2025-06-09
//  Current UTC: 2025-06-09 22:48:36
//

import SwiftUI

struct ContentView: View {
    @StateObject private var transcriptManager = TranscriptManager()
    @StateObject private var presetManager = PresetManager()
    @StateObject private var apiManager = APIManager()
    @StateObject private var connectivityManager = ConnectivityManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with connectivity status
            HStack {
                Text("DaVinci Transcript Processor")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Internet Connection Status Indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(connectivityManager.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(connectivityManager.isConnected ? "Connected" : "No Connection")
                        .font(.caption)
                        .foregroundColor(connectivityManager.isConnected ? .green : .red)
                }
                .padding(6)
                .background(Color(hex: "2d2d2d"))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(hex: "252525"))
            
            // Main Content
            TabView {
                FileProcessingView(transcriptManager: transcriptManager)
                    .tabItem {
                        Image(systemName: "doc.text")
                        Text("DaVinci Resolve")
                    }
                
                AIProcessingView(
                    transcriptManager: transcriptManager,
                    presetManager: presetManager,
                    apiManager: apiManager
                )
                .tabItem {
                    Image(systemName: "wand.and.stars")
                    Text("AI Processing")
                }
                
                // New AI Direct Tab
                AIDirectView(apiManager: apiManager)
                    .tabItem {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("AI Direct")
                    }
                
                PresetEditorView(presetManager: presetManager)
                    .tabItem {
                        Image(systemName: "slider.horizontal.3")
                        Text("Edit Presets")
                    }
                
                APIKeysView(apiManager: apiManager)
                    .tabItem {
                        Image(systemName: "key")
                        Text("API Keys")
                    }
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .background(Color(hex: "1a1a1a"))
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    MainContentView()
}
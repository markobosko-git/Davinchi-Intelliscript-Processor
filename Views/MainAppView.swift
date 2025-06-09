//
//  MainAppView.swift
//  DaVinci Resolve Transcript Processor
//
//  Created for markobosko-git on 2025-06-09
//  Current UTC: 2025-06-09 22:48:36
//

import SwiftUI

struct MainAppView: View {
    @StateObject var transcriptManager = TranscriptManager()
    @StateObject var presetManager = PresetManager()
    @StateObject var apiManager = APIManager()
    @StateObject var connectivityManager = ConnectivityManager()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with app title and connectivity status
            HStack {
                Text("DaVinci Transcript Processor")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Internet Connection Status Indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(connectivityManager.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(connectivityManager.isConnected ? "Connected" : "No Connection")
                        .font(.caption)
                        .foregroundColor(connectivityManager.isConnected ? .green : .red)
                }
                .padding(8)
                .background(Color(hex: "2d2d2d"))
                .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(hex: "1a1a1a"))
            
            // Tab Bar
            HStack(spacing: 0) {
                TabButton(
                    title: "File Processing",
                    systemImage: "doc.text",
                    isSelected: selectedTab == 0
                ) {
                    selectedTab = 0
                }
                
                TabButton(
                    title: "AI Processing",
                    systemImage: "wand.and.stars",
                    isSelected: selectedTab == 1
                ) {
                    selectedTab = 1
                }
                
                TabButton(
                    title: "AI Direct",
                    systemImage: "bubble.left.and.bubble.right",
                    isSelected: selectedTab == 2
                ) {
                    selectedTab = 2
                }
                
                TabButton(
                    title: "Presets",
                    systemImage: "slider.horizontal.3",
                    isSelected: selectedTab == 3
                ) {
                    selectedTab = 3
                }
                
                TabButton(
                    title: "API Keys",
                    systemImage: "key",
                    isSelected: selectedTab == 4
                ) {
                    selectedTab = 4
                }
            }
            .background(Color(hex: "252525"))
            
            // Tab Content
            ZStack {
                // File Processing View
                FileProcessingView(transcriptManager: transcriptManager)
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .disabled(selectedTab != 0)
                
                // AI Processing View
                AIProcessingView(
                    transcriptManager: transcriptManager, 
                    presetManager: presetManager, 
                    apiManager: apiManager
                )
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .disabled(selectedTab != 1)
                
                // AI Direct View (New)
                AIDirectView(apiManager: apiManager)
                    .opacity(selectedTab == 2 ? 1 : 0)
                    .disabled(selectedTab != 2)
                
                // Preset Editor View
                PresetEditorView(presetManager: presetManager)
                    .opacity(selectedTab == 3 ? 1 : 0)
                    .disabled(selectedTab != 3)
                
                // API Keys View
                APIKeysView(apiManager: apiManager)
                    .opacity(selectedTab == 4 ? 1 : 0)
                    .disabled(selectedTab != 4)
            }
        }
        .background(Color(hex: "1a1a1a"))
    }
}

// Tab Button Component
struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color(hex: "4a9eff").opacity(0.2) : Color.clear)
            .foregroundColor(isSelected ? Color(hex: "4a9eff") : .gray)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
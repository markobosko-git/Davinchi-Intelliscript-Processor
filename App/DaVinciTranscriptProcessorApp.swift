//
//  DaVinciTranscriptProcessorApp.swift
//  DaVinci Transcript Processor
//
//  Created for markobosko-git on 2025-06-09
//  Current UTC: 2025-06-09 22:43:28
//

import SwiftUI

@main
struct DaVinciTranscriptProcessorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}

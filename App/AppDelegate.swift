//
//  AppDelegate.swift
//  DaVinci Transcript Processor
//
//  Created for markobosko-git on 2025-06-09
//  Current UTC: 2025-06-09 22:43:28
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App initialization code can go here
        print("DaVinci Transcript Processor launched")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup code can go here
        print("DaVinci Transcript Processor terminating")
    }
}

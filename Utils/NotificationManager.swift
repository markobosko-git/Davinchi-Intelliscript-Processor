//
//  NotificationManager.swift
//  DaVinci Resolve Transcript Processor
//
//  Created for markobosko-git on 2025-06-09
//  Current UTC: 2025-06-09 22:48:36
//

import SwiftUI

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func showSuccess(_ message: String) {
        #if os(macOS)
        let notification = NSUserNotification()
        notification.title = "Success"
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
        #else
        // iOS implementation would go here if needed
        print("Success: \(message)")
        #endif
    }
    
    func showError(_ message: String) {
        #if os(macOS)
        let notification = NSUserNotification()
        notification.title = "Error"
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
        #else
        // iOS implementation would go here if needed
        print("Error: \(message)")
        #endif
    }
    
    func showInfo(_ message: String) {
        #if os(macOS)
        let notification = NSUserNotification()
        notification.title = "Information"
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
        #else
        // iOS implementation would go here if needed
        print("Info: \(message)")
        #endif
    }
}

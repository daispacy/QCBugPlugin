//
//  QCBugPlugin.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import UIKit

/// Main entry point for the QC Bug Plugin framework
public final class QCBugPlugin {

    private static let manager = QCBugPluginManager.shared
    
    /// Current version of the plugin
    static let version = "1.0.0"
    
    /// Build number
    static let buildNumber = "1"
    
    /// Framework information
    static var frameworkInfo: [String: Any] {
        return [
            "name": "QCBugPlugin",
            "version": version,
            "buildNumber": buildNumber,
            "buildDate": buildDate
        ]
    }
    
    private static var buildDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    // MARK: - Quick Setup Methods
    
    /// Configure the plugin by supplying the host window and configuration
    /// - Parameters:
    ///   - window: The root application window to attach plugin UI elements to
    ///   - configuration: Complete configuration describing integration behaviour
    public static func configure(using window: UIWindow, configuration: QCBugPluginConfig) {
        manager.configure(using: window, configuration: configuration)
    }
    
    // MARK: - Convenience Methods
    
    /// Present the bug report interface
    public static func presentBugReport() {
        manager.presentBugReport()
    }
    
    /// Set custom data to include with bug reports
    /// - Parameter data: Custom data dictionary
    public static func setCustomData(_ data: [String: Any]) {
        manager.setCustomData(data)
    }
    
    /// Enable or disable screen recording
    /// - Parameter enabled: Whether screen recording should be available
    public static func setScreenRecordingEnabled(_ enabled: Bool) {
        manager.setScreenRecordingEnabled(enabled)
    }

    // MARK: - Screen Recording Control

    /// Start screen recording manually
    /// - Parameter completion: Callback with success/failure result
    public static func startScreenRecording(completion: @escaping (Result<Void, Error>) -> Void) {
        manager.startScreenRecording(completion: completion)
    }

    /// Stop screen recording manually
    /// - Parameter completion: Callback with video URL or error
    public static func stopScreenRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        manager.stopScreenRecording(completion: completion)
    }

    /// Check if screen recording is currently active
    public static var isScreenRecording: Bool {
        return manager.isScreenRecording()
    }

    /// Check if the current recording is owned by this plugin
    public static var isScreenRecordingOwnedByPlugin: Bool {
        return manager.isScreenRecordingOwnedByPlugin()
    }

    /// Assign a delegate to receive lifecycle callbacks
    public static func setDelegate(_ delegate: QCBugPluginDelegate?) {
        manager.setDelegate(delegate)
    }

    // MARK: - Debug Helpers
    
    #if DEBUG
    /// Enable debug mode with floating button (Debug builds only)
    static func enableDebugMode(using window: UIWindow) {
        let config = QCBugPluginConfig(
            webhookURL: "https://webhook.site/debug",
            enableFloatingButton: true
        )
    configure(using: window, configuration: config)
        
        print("🐛 QCBugPlugin: Debug mode enabled with floating button")
    }
    
    /// Print framework information
    static func printInfo() {
        print("📦 QCBugPlugin Framework Info:")
        for (key, value) in frameworkInfo {
            print("   \(key): \(value)")
        }
    }
    #endif
}

// MARK: - Documentation

/**
 # QCBugPlugin Framework
 
 A comprehensive bug reporting framework for iOS applications that provides:
 
 ## Features
 -  **Screen Recording**: Native screen recording using ReplayKit framework
    - 📱 **Rich Bug Reports**: Detailed reports including device info, app info, and captured context
 - 🌐 **Webhook Integration**: Submit reports to any webhook endpoint
 - 🎨 **Customizable UI**: Beautiful HTML/JS interface with native bridge communication
 - 🔧 **Easy Integration**: Simple API that works with any iOS app
 
 ## Quick Start
 
 ```swift
 import QCBugPlugin
 
 // Configure the plugin once you have access to the app window
 let config = QCBugPluginConfig(
     webhookURL: "https://your-webhook-url.com/bugs"
 )
 QCBugPlugin.configure(using: window, configuration: config)
 
 // Present bug report interface (can be triggered by shake gesture, button, etc.)
 QCBugPlugin.presentBugReport()
 ```
 
 ## Advanced Configuration
 
 ```swift
 let config = QCBugPluginConfig(
     webhookURL: "https://your-webhook-url.com/bugs",
     apiKey: "your-api-key",
     customData: ["userId": "12345", "environment": "staging"],
     isScreenRecordingEnabled: true,
     enableFloatingButton: true // Debug builds only
 )
 
 QCBugPlugin.configure(using: window, configuration: config)
 ```
 
 ## Integration with App Delegate
 
 ```swift
 func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
     window = UIWindow(frame: UIScreen.main.bounds)
     window?.rootViewController = RootViewController()
     window?.makeKeyAndVisible()

     #if DEBUG || STAGING
     if let window {
         let config = QCBugPluginConfig(webhookURL: "https://your-webhook-url.com/bugs", enableFloatingButton: true)
         QCBugPlugin.configure(using: window, configuration: config)
     }
     #endif

     return true
 }
 ```
 
 ## Shake Gesture Integration
 
 ```swift
 override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
     if motion == .motionShake {
         QCBugPlugin.presentBugReport()
     }
 }
 ```
 */
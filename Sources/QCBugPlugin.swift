//
//  QCBugPlugin.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation

/// Main entry point for the QC Bug Plugin framework
public final class QCBugPlugin {
    
    /// Shared instance of the plugin manager
    public static let shared: QCBugPluginProtocol = QCBugPluginManager.shared
    
    /// Current version of the plugin
    public static let version = "1.0.0"
    
    /// Build number
    public static let buildNumber = "1"
    
    /// Framework information
    public static var frameworkInfo: [String: Any] {
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
    
    /// Quick setup with webhook URL only
    /// - Parameter webhookURL: The webhook URL to send bug reports to
    public static func configure(webhookURL: String) {
        shared.configure(webhookURL: webhookURL, apiKey: nil)
    }
    
    /// Quick setup with webhook URL and API key
    /// - Parameters:
    ///   - webhookURL: The webhook URL to send bug reports to
    ///   - apiKey: Optional API key for authentication
    public static func configure(webhookURL: String, apiKey: String?) {
        shared.configure(webhookURL: webhookURL, apiKey: apiKey)
    }
    
    /// Advanced configuration
    /// - Parameter config: Complete configuration object
    public static func configure(with config: QCBugPluginConfig) {
        (shared as? QCBugPluginManager)?.configure(with: config)
    }
    
    // MARK: - Convenience Methods
    
    /// Start tracking user interactions
    public static func startTracking() {
        shared.startTracking()
    }
    
    /// Stop tracking user interactions
    public static func stopTracking() {
        shared.stopTracking()
    }
    
    /// Present the bug report interface
    public static func presentBugReport() {
        shared.presentBugReport()
    }
    
    /// Check if tracking is enabled
    public static var isTrackingEnabled: Bool {
        return shared.isTrackingEnabled()
    }
    
    /// Set custom data to include with bug reports
    /// - Parameter data: Custom data dictionary
    public static func setCustomData(_ data: [String: Any]) {
        shared.setCustomData(data)
    }
    
    /// Enable or disable screen recording
    /// - Parameter enabled: Whether screen recording should be available
    public static func setScreenRecordingEnabled(_ enabled: Bool) {
        shared.setScreenRecordingEnabled(enabled)
    }

    // MARK: - Screen Recording Control

    /// Start screen recording manually
    /// - Parameter completion: Callback with success/failure result
    public static func startScreenRecording(completion: @escaping (Result<Void, Error>) -> Void) {
        shared.startScreenRecording(completion: completion)
    }

    /// Stop screen recording manually
    /// - Parameter completion: Callback with video URL or error
    public static func stopScreenRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        shared.stopScreenRecording(completion: completion)
    }

    /// Check if screen recording is currently active
    public static var isScreenRecording: Bool {
        return shared.isScreenRecording()
    }

    /// Check if the current recording is owned by this plugin
    public static var isScreenRecordingOwnedByPlugin: Bool {
        return shared.isScreenRecordingOwnedByPlugin()
    }

    // MARK: - Debug Helpers
    
    #if DEBUG
    /// Enable debug mode with floating button (Debug builds only)
    public static func enableDebugMode() {
        let config = QCBugPluginConfig(
            webhookURL: "https://webhook.site/debug",
            enableFloatingButton: true
        )
        configure(with: config)
        startTracking()
        
        print("🐛 QCBugPlugin: Debug mode enabled with floating button")
    }
    
    /// Print framework information
    public static func printInfo() {
        print("📦 QCBugPlugin Framework Info:")
        for (key, value) in frameworkInfo {
            print("   \(key): \(value)")
        }
    }
    #endif
}

// MARK: - Global Extensions

public extension Notification.Name {
    /// Posted when QC Bug Plugin starts tracking
    static let QCBugPluginDidStartTracking = Notification.Name.qcBugPluginDidStartTracking

    /// Posted when QC Bug Plugin stops tracking
    static let QCBugPluginDidStopTracking = Notification.Name.qcBugPluginDidStopTracking

    /// Posted when a bug report is submitted successfully
    static let QCBugPluginDidSubmitReport = Notification.Name.qcBugPluginDidSubmitReport

    /// Posted when bug report submission fails
    static let QCBugPluginDidFailToSubmitReport = Notification.Name.qcBugPluginDidFailToSubmitReport

    /// Posted when a user action is tracked
    static let QCBugPluginDidTrackUserAction = Notification.Name.qcBugPluginDidTrackUserAction

    // MARK: - Screen Recording Notifications

    /// Posted when screen recording starts successfully
    static let QCBugPluginDidStartRecording = Notification.Name.qcBugPluginDidStartRecording

    /// Posted when screen recording stops successfully (userInfo contains "url" key)
    static let QCBugPluginDidStopRecording = Notification.Name.qcBugPluginDidStopRecording

    /// Posted when screen recording fails (userInfo contains "error" key)
    static let QCBugPluginDidFailRecording = Notification.Name.qcBugPluginDidFailRecording
    
    // MARK: - Session Notifications
    
    /// Posted when session is cleared (userInfo contains "count" key with number of removed attachments)
    static let QCBugPluginDidClearSession = Notification.Name.qcBugPluginDidClearSession
}

// MARK: - Documentation

/**
 # QCBugPlugin Framework
 
 A comprehensive bug reporting framework for iOS applications that provides:
 
 ## Features
 - 🎯 **User Interaction Tracking**: Automatically tracks screen views, button taps, and user actions
 - 🎥 **Screen Recording**: Native screen recording using ReplayKit framework
 - 📱 **Rich Bug Reports**: Detailed reports including device info, app info, and user action timeline
 - 🌐 **Webhook Integration**: Submit reports to any webhook endpoint
 - 🎨 **Customizable UI**: Beautiful HTML/JS interface with native bridge communication
 - 🔧 **Easy Integration**: Simple API that works with any iOS app
 
 ## Quick Start
 
 ```swift
 import QCBugPlugin
 
 // Configure the plugin
 QCBugPlugin.configure(webhookURL: "https://your-webhook-url.com/bugs")
 
 // Start tracking user interactions
 QCBugPlugin.startTracking()
 
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
     maxActionHistoryCount: 100,
     enableFloatingButton: true // Debug builds only
 )
 
 QCBugPlugin.configure(with: config)
 ```
 
 ## Integration with App Delegate
 
 ```swift
 func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
     
     #if DEBUG || STAGING
     QCBugPlugin.configure(webhookURL: "https://your-webhook-url.com/bugs")
     QCBugPlugin.startTracking()
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
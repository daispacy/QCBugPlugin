//
//  QCBugPlugin.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Public Exports

/// Re-export CrashReport for public access
public typealias QCCrashReport = CrashReport

/// Custom UIWindow that detects shake gestures to show hidden floating button
/// Use this as your app's main window to enable the shake backdoor feature
///
/// Example usage:
/// ```swift
/// func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
///     window = QCShakeDetectingWindow(frame: UIScreen.main.bounds)
///     window?.rootViewController = RootViewController()
///     window?.makeKeyAndVisible()
///
///     if let window {
///         let config = QCBugPluginConfig(webhookURL: "https://your-webhook.com/bugs", enableFloatingButton: true)
///         QCBugPlugin.configure(using: window, configuration: config)
///     }
///     return true
/// }
/// ```
public class QCShakeDetectingWindow: UIWindow {
    internal weak var shakeDelegate: ShakeDetectionDelegate?

    public override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)

        if motion == .motionShake {
            shakeDelegate?.windowDidDetectShake()
        }
    }
}

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
 - 🔓 **Shake Backdoor**: Secret shake gesture to reveal hidden floating button

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

 ## Integration with App Delegate (with Shake Backdoor)

 ```swift
 func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
     // Use QCShakeDetectingWindow to enable shake backdoor feature
     window = QCShakeDetectingWindow(frame: UIScreen.main.bounds)
     window?.rootViewController = RootViewController()
     window?.makeKeyAndVisible()

     #if DEBUG || STAGING
     if let window {
         let config = QCBugPluginConfig(webhookURL: "https://your-webhook-url.com/bugs", enableFloatingButton: true)
         QCBugPlugin.configure(using: window, configuration: config)
         // Now you can shake the device to show the floating button if it's hidden!
     }
     #endif

     return true
 }
 ```

 ## Shake Backdoor Feature

 The shake backdoor allows you to show the floating button by shaking the device, even if it's hidden.
 This is useful during development/testing when the floating button gets dismissed or hidden.

 **To enable shake backdoor:**
 1. Use `QCShakeDetectingWindow` instead of `UIWindow` as your app's main window
 2. Configure QCBugPlugin with `enableFloatingButton: true`
 3. Shake your device when the floating button is hidden - it will reappear!

 **Note:** The shake backdoor only works when:
 - The floating button is enabled in configuration
 - The floating button is currently hidden (`isHidden = true` or `alpha < 0.1`)
 - The window is an instance of `QCShakeDetectingWindow`

 ## Manual Shake Gesture Integration

 ```swift
 override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
     if motion == .motionShake {
         QCBugPlugin.presentBugReport()
     }
 }
 ```
 */
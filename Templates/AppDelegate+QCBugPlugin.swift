//
//  AppDelegate+QCBugPlugin.swift
//  YourApp
//
//  Template file for integrating QCBugPlugin at the application level
//  WITHOUT modifying the original AppDelegate code.
//
//  Usage:
//  1. Copy this file to your project
//  2. Customize the configuration for your app
//  3. The swizzling will automatically initialize QCBugPlugin
//  4. Build in DEBUG or STAGING configuration
//

import UIKit
import QCBugPlugin
import ObjectiveC

#if DEBUG || STAGING

// MARK: - QCBugPlugin AppDelegate Extension

extension AppDelegate {
    
    // MARK: - Swizzling Setup
    
    private static var swizzlingToken: Int = 0
    
    /// Automatically sets up swizzling when AppDelegate is loaded
    static func initializeQCBugPluginForApp() {
        guard swizzlingToken == 0 else { return }
        
        let originalSelector = #selector(application(_:didFinishLaunchingWithOptions:))
        let swizzledSelector = #selector(qcBugPlugin_application(_:didFinishLaunchingWithOptions:))
        
        guard let originalMethod = class_getInstanceMethod(self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            print("⚠️ QCBugPlugin: Failed to swizzle AppDelegate methods")
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
        swizzlingToken = 1
        
        print("✅ QCBugPlugin: AppDelegate swizzling initialized")
    }
    
    // MARK: - Swizzled Application Lifecycle
    
    @objc private func qcBugPlugin_application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // IMPORTANT: Call original implementation
        let result = qcBugPlugin_application(application, didFinishLaunchingWithOptions: launchOptions)
        
        // Configure QCBugPlugin
        configureQCBugPlugin()
        
        // Enable global shake gesture
        enableGlobalShakeGesture()
        
        return result
    }
    
    // MARK: - QCBugPlugin Configuration
    
    private func configureQCBugPlugin() {
        // TODO: Replace with your actual webhook URL
        let webhookURL = "https://webhook.site/your-unique-id"
        
        // TODO: Add your API key if needed
        let apiKey: String? = nil // "your-api-key-here"
        
        // Get app information
        let appInfo = Bundle.main.infoDictionary
        let appVersion = appInfo?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = appInfo?["CFBundleVersion"] as? String ?? "unknown"
        let appName = appInfo?["CFBundleDisplayName"] as? String ?? 
                      appInfo?["CFBundleName"] as? String ?? "unknown"
        
        // Get environment
        #if DEBUG
        let environment = "DEBUG"
        #elseif STAGING
        let environment = "STAGING"
        #else
        let environment = "UNKNOWN"
        #endif
        
        // Create configuration
        let config = QCBugPluginConfig(
            webhookURL: webhookURL,
            apiKey: apiKey,
            customData: [
                "app": appName,
                "environment": environment,
                "version": appVersion,
                "buildNumber": buildNumber,
                "deviceModel": UIDevice.current.model,
                "systemVersion": UIDevice.current.systemVersion,
                "appLaunchTime": Date().timeIntervalSince1970
            ],
            isScreenRecordingEnabled: true,
            maxActionHistoryCount: 100,
            enableFloatingButton: true // Show floating debug button
        )
        
        // Configure and start tracking
        QCBugPlugin.configure(with: config)
        QCBugPlugin.startTracking()
        
        print("🐛 QCBugPlugin configured for \(appName) - \(environment)")
    }
    
    // MARK: - Global Shake Gesture
    
    private func enableGlobalShakeGesture() {
        // The shake gesture will be handled in UIWindow or individual ViewControllers
        // This is just a placeholder for any global shake configuration
        print("🐛 QCBugPlugin: Global shake gesture enabled")
    }
}

// MARK: - UIWindow Shake Gesture Extension

extension UIWindow {
    
    private static var shakeSwizzlingToken: Int = 0
    
    /// Swizzle motionEnded to enable global shake gesture
    static func setupQCBugPluginShakeGesture() {
        guard shakeSwizzlingToken == 0 else { return }
        
        let originalSelector = #selector(motionEnded(_:with:))
        let swizzledSelector = #selector(qcBugPlugin_motionEnded(_:with:))
        
        guard let originalMethod = class_getInstanceMethod(self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
        shakeSwizzlingToken = 1
    }
    
    @objc private func qcBugPlugin_motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        // Call original implementation
        qcBugPlugin_motionEnded(motion, with: event)
        
        // Handle shake gesture globally
        if motion == .motionShake {
            QCBugPlugin.presentBugReport()
        }
    }
    
    override open class func initialize() {
        super.initialize()
        guard self === UIWindow.self else { return }
        setupQCBugPluginShakeGesture()
    }
}

// MARK: - Auto-Initialize

extension AppDelegate {
    /// Called automatically when AppDelegate class is first loaded
    @objc override open class func initialize() {
        super.initialize()
        guard self === AppDelegate.self else { return }
        initializeQCBugPluginForApp()
    }
}

#endif

// MARK: - Usage Notes
/*
 
 HOW TO USE THIS TEMPLATE:
 
 1. COPY THIS FILE to your project
 
 2. CUSTOMIZE the configuration:
    - Replace webhook URL with your actual endpoint
    - Add API key if your webhook requires authentication
    - Customize customData with your app-specific information
 
 3. BUILD in DEBUG or STAGING configuration
 
 4. TEST the integration:
    - Launch app
    - Check console for "🐛 QCBugPlugin configured" message
    - Shake device to test global bug reporting
    - Use floating button to trigger bug report
 
 CONFIGURATION OPTIONS:
 
 - webhookURL: Your webhook endpoint for receiving bug reports
 - apiKey: Optional authentication key for your webhook
 - customData: App-level data included in all bug reports
 - isScreenRecordingEnabled: Enable/disable screen recording feature
 - maxActionHistoryCount: Number of user actions to track (default: 100)
 - enableFloatingButton: Show floating debug button (true/false)
 
 CUSTOM DATA SUGGESTIONS:
 
 ✅ Include:
 - App name and version
 - Build environment (DEBUG/STAGING)
 - Device model and OS version
 - User ID (if available and appropriate)
 - Feature flags or A/B test variants
 - Session identifiers
 - Current language/locale
 
 ❌ Don't Include:
 - Passwords or authentication tokens
 - Personal identifying information
 - Sensitive user data
 - API keys or secrets
 
 SHAKE GESTURE:
 
 The global shake gesture is enabled by default through UIWindow swizzling.
 Individual ViewControllers can override this behavior in their own
 +QCBugPlugin extensions to provide screen-specific context.
 
 FLOATING BUTTON:
 
 Set enableFloatingButton: true to show a draggable floating button
 that provides easy access to bug reporting without shake gesture.
 The button is automatically hidden in non-DEBUG/STAGING builds.
 
 WEBHOOK SETUP:
 
 For testing, you can use:
 - https://webhook.site (free, public webhook testing)
 - https://requestbin.com (request inspection)
 - Your own backend endpoint
 
 For production use (in STAGING):
 - Set up a secure webhook endpoint
 - Implement authentication (use apiKey)
 - Store bug reports in your database
 - Integrate with your bug tracking system
 
 */

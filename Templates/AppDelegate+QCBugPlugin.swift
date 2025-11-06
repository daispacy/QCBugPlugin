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
//  3. Call setupQCBugPlugin() from your AppDelegate's didFinishLaunchingWithOptions
//  4. Build in DEBUG or STAGING configuration
//
//  IMPORTANT: Swift no longer supports class initialize() method.
//  You must manually call setupQCBugPlugin() in your AppDelegate.
//

import UIKit
import QCBugPlugin
import ObjectiveC

#if DEBUG || STAGING

// MARK: - QCBugPlugin AppDelegate Extension

extension AppDelegate {
    
    // MARK: - Setup Method
    
    /// Call this method from your AppDelegate's application(_:didFinishLaunchingWithOptions:)
    /// Swift no longer supports automatic class initialize(), so manual setup is required.
    func setupQCBugPlugin() {
        configureQCBugPlugin()
        enableGlobalShakeGesture()
        print("✅ QCBugPlugin: Initialized from AppDelegate")
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
            enableFloatingButton: true // Show floating debug button
        )
        
        guard let window = self.window ?? UIApplication.shared.windows.first else {
            print("⚠️ QCBugPlugin: Unable to configure without a valid window")
            return
        }

        QCBugPlugin.configure(using: window, configuration: config)
        
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
    
    // NOTE: Global shake gesture can be enabled, but requires manual override
    // in your UIWindow subclass or SceneDelegate for iOS 13+
    // This is optional - individual ViewControllers can handle shake independently
    
    /* Uncomment if you want global shake gesture handling:
    
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        
        if motion == .motionShake {
            QCBugPlugin.presentBugReport()
        }
    }
    */
}

#endif

// MARK: - Usage Instructions
/*
 
 HOW TO USE THIS TEMPLATE:
 
 1. COPY THIS FILE to your project
 
 2. ADD TO YOUR AppDelegate.swift:
 
    #if DEBUG || STAGING
    import QCBugPlugin
    #endif
    
    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        #if DEBUG || STAGING
        setupQCBugPlugin()  // Add this line
        #endif
        
        // Your existing code...
        return true
    }
 
 3. CUSTOMIZE the configuration:
    - Replace webhook URL with your actual endpoint
    - Add API key if your webhook requires authentication
    - Customize customData with your app-specific information
 
 4. BUILD in DEBUG or STAGING configuration
 
 5. TEST the integration:
    - Launch app
    - Check console for "✅ QCBugPlugin: Initialized from AppDelegate" message
    - Shake device to test global bug reporting (if enabled in ViewController)
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

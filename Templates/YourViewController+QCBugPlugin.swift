//
//  YourViewController+QCBugPlugin.swift
//  YourApp
//
//  Template file for integrating QCBugPlugin into a view controller
//  WITHOUT modifying the original view controller code.
//
//  Usage:
//  1. Copy this file to your project
//  2. Rename to match your ViewController: e.g., CheckoutViewController+QCBugPlugin.swift
//  3. Replace "YourViewController" with your actual class name
//  4. Customize the tracking data for your feature
//  5. Build in DEBUG or STAGING configuration
//

import UIKit
import QCBugPlugin
import ObjectiveC

#if DEBUG || STAGING

// MARK: - QCBugPlugin Integration Extension

extension YourViewController {
    
    // MARK: - Swizzling Setup
    
    /// Storage for the swizzling token to ensure it runs only once
    private static var swizzlingToken: Int = 0
    
    /// Automatically sets up swizzling when the class is first loaded
    static func initializeQCBugPlugin() {
        guard self === YourViewController.self else { return }
        
        // Ensure swizzling happens only once
        if swizzlingToken == 0 {
            swizzleViewDidLoad()
            swizzleViewWillAppear()
            swizzleViewDidDisappear()
            swizzleMotionEnded()
            swizzlingToken = 1
            
            print("✅ QCBugPlugin swizzling initialized for \(String(describing: self))")
        }
    }
    
    // MARK: - Method Swizzling Implementations
    
    private static func swizzleViewDidLoad() {
        let originalSelector = #selector(viewDidLoad)
        let swizzledSelector = #selector(qcBugPlugin_viewDidLoad)
        swizzleMethod(original: originalSelector, swizzled: swizzledSelector)
    }
    
    private static func swizzleViewWillAppear() {
        let originalSelector = #selector(viewWillAppear(_:))
        let swizzledSelector = #selector(qcBugPlugin_viewWillAppear(_:))
        swizzleMethod(original: originalSelector, swizzled: swizzledSelector)
    }
    
    private static func swizzleViewDidDisappear() {
        let originalSelector = #selector(viewDidDisappear(_:))
        let swizzledSelector = #selector(qcBugPlugin_viewDidDisappear(_:))
        swizzleMethod(original: originalSelector, swizzled: swizzledSelector)
    }
    
    private static func swizzleMotionEnded() {
        let originalSelector = #selector(motionEnded(_:with:))
        let swizzledSelector = #selector(qcBugPlugin_motionEnded(_:with:))
        swizzleMethod(original: originalSelector, swizzled: swizzledSelector)
    }
    
    private static func swizzleMethod(original: Selector, swizzled: Selector) {
        guard let originalMethod = class_getInstanceMethod(self, original),
              let swizzledMethod = class_getInstanceMethod(self, swizzled) else {
            print("⚠️ Failed to swizzle method: \(original)")
            return
        }
        
        // Add method if it doesn't exist in the subclass
        let didAddMethod = class_addMethod(
            self,
            original,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )
        
        if didAddMethod {
            class_replaceMethod(
                self,
                swizzled,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    // MARK: - Swizzled Lifecycle Methods
    
    @objc private func qcBugPlugin_viewDidLoad() {
        // IMPORTANT: Call original implementation
        // Due to swizzling, this actually calls the original viewDidLoad
        qcBugPlugin_viewDidLoad()
        
        // Add QCBugPlugin setup
        setupQCBugReporting()
    }
    
    @objc private func qcBugPlugin_viewWillAppear(_ animated: Bool) {
        // IMPORTANT: Call original implementation
        qcBugPlugin_viewWillAppear(animated)
        
        // Update context data when screen appears
        updateBugReportContext()
    }
    
    @objc private func qcBugPlugin_viewDidDisappear(_ animated: Bool) {
        // IMPORTANT: Call original implementation
        qcBugPlugin_viewDidDisappear(animated)
        
        // Optional: Clear or update context when leaving screen
        // clearBugReportContext()
    }
    
    @objc private func qcBugPlugin_motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        // IMPORTANT: Call original implementation if it exists
        qcBugPlugin_motionEnded(motion, with: event)
        
        // Handle shake gesture for bug reporting
        if motion == .motionShake {
            presentBugReportWithContext()
        }
    }
    
    // MARK: - QCBugPlugin Setup
    
    private func setupQCBugReporting() {
        // Add debug button to navigation bar
        addBugReportButton()
        
        // Set initial feature context
        setInitialContext()
        
        print("🐛 QCBugPlugin configured for \(String(describing: type(of: self)))")
    }
    
    private func addBugReportButton() {
        // Add bug report button to navigation bar
        let bugButton = UIBarButtonItem(
            title: "🐛",
            style: .plain,
            target: self,
            action: #selector(bugReportButtonTapped)
        )
        
        // Add to right side of navigation bar
        if let existingItems = navigationItem.rightBarButtonItems {
            navigationItem.rightBarButtonItems = existingItems + [bugButton]
        } else {
            navigationItem.rightBarButtonItem = bugButton
        }
    }
    
    @objc private func bugReportButtonTapped() {
        presentBugReportWithContext()
    }
    
    // MARK: - Context Management
    
    private func setInitialContext() {
        var contextData: [String: Any] = [
            "feature": "YourFeatureName",  // TODO: Change to your feature name
            "screen": String(describing: type(of: self)),
            "screenTitle": title ?? "Unknown"
        ]
        
        // TODO: Add your feature-specific data
        // Example:
        // contextData["userId"] = currentUser?.id
        // contextData["isLoggedIn"] = isUserLoggedIn
        
        QCBugPlugin.setCustomData(contextData)
    }
    
    private func updateBugReportContext() {
        var contextData: [String: Any] = [
            "feature": "YourFeatureName",  // TODO: Change to your feature name
            "screen": String(describing: type(of: self)),
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // TODO: Add dynamic data that changes based on user interactions
        // Example:
        // if let selectedItem = viewModel?.selectedItem {
        //     contextData["selectedItemId"] = selectedItem.id
        //     contextData["selectedItemName"] = selectedItem.name
        // }
        //
        // if let formData = collectFormData() {
        //     contextData.merge(formData) { (_, new) in new }
        // }
        
        QCBugPlugin.setCustomData(contextData)
    }
    
    // TODO: Implement this method to collect form data
    private func collectFormData() -> [String: Any]? {
        var data: [String: Any] = [:]
        
        // Example: Collecting form data (SANITIZED - no passwords/PINs!)
        // data["hasUsername"] = !usernameTextField.text?.isEmpty ?? false
        // data["selectedOption"] = selectedOptionIndex
        // data["hasAmount"] = amountTextField.text != nil
        
        // ❌ NEVER do this:
        // data["password"] = passwordTextField.text  // WRONG!
        // data["cardNumber"] = cardTextField.text     // WRONG!
        // data["pin"] = pinTextField.text             // WRONG!
        
        return data.isEmpty ? nil : data
    }
    
    private func presentBugReportWithContext() {
        // Update context with latest data before presenting
        updateBugReportContext()
        
        // Present the bug report interface
        QCBugPlugin.presentBugReport()
    }
}

// MARK: - Auto-Initialize on Class Load

extension YourViewController {
    /// Called automatically when the class is first accessed
    /// This triggers the swizzling setup
    @objc override open class func initialize() {
        // Call super to maintain inheritance chain
        super.initialize()
        
        // Initialize QCBugPlugin swizzling
        initializeQCBugPlugin()
    }
}

#endif

// MARK: - Usage Notes
/*
 
 HOW TO USE THIS TEMPLATE:
 
 1. COPY THIS FILE to your project
 
 2. RENAME THE FILE to match your ViewController:
    Example: CheckoutViewController+QCBugPlugin.swift
 
 3. REPLACE "YourViewController" with your actual class name throughout the file
 
 4. CUSTOMIZE the context data:
    - Change "YourFeatureName" to your actual feature name
    - Add feature-specific data in setInitialContext()
    - Add dynamic data in updateBugReportContext()
    - Implement collectFormData() if you have forms
 
 5. BUILD in DEBUG or STAGING configuration
 
 6. TEST the integration:
    - Shake device to trigger bug report
    - Tap 🐛 button in navigation bar
    - Verify context data is collected correctly
 
 SECURITY REMINDERS:
 - ✅ DO track: user selections, form presence, feature state
 - ❌ DON'T track: passwords, PINs, full card numbers, sensitive data
 - ✅ DO use presence flags: "hasPassword": true
 - ❌ DON'T use actual values: "password": "abc123"
 
 SWIZZLING SAFETY:
 - Always call the original method (qcBugPlugin_xxx calls original)
 - Use conditional compilation (#if DEBUG || STAGING)
 - Test thoroughly in DEBUG builds
 - Verify original functionality is not affected
 
 */

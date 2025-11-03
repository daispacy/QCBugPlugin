//
//  YourViewController+QCBugPlugin.swift
//  YourApp
//
//  Template file for integrating QCBugPlugin into a view controller
//  using manual lifecycle hooks (no swizzling).
//
//  Usage:
//  1. Copy this file to your project
//  2. Rename to match your ViewController: e.g., CheckoutViewController+QCBugPlugin.swift
//  3. Replace "YourViewController" with your actual class name
//  4. Add lifecycle calls to your original ViewController (see instructions below)
//  5. Customize the tracking data for your feature
//  6. Build in DEBUG or STAGING configuration
//
//  IMPORTANT: Swift no longer supports automatic swizzling via class initialize().
//  You must manually call QCBugPlugin methods from your ViewController's lifecycle methods.
//

import UIKit
import QCBugPlugin
import ObjectiveC

#if DEBUG || STAGING

// MARK: - QCBugPlugin Integration Extension

extension YourViewController {
    
    // MARK: - Setup Methods
    
    /// Call this from your viewDidLoad()
    func setupQCBugReporting() {
        addBugReportButton()
        setInitialContext()
        print("🐛 QCBugPlugin configured for \(String(describing: type(of: self)))")
    }
    
    /// Call this from your viewWillAppear(_:)
    func updateQCBugReportContext() {
        updateBugReportContext()
    }
    
    /// Call this from your motionEnded(_:with:) if you want shake gesture
    func handleQCShakeGesture(_ motion: UIEvent.EventSubtype) {
        if motion == .motionShake {
            presentBugReportWithContext()
        }
    }
    
    // MARK: - UI Setup
    
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

    }
}

#endif

// MARK: - Usage Instructions
/*
 
 HOW TO INTEGRATE INTO YOUR VIEWCONTROLLER:
 
 1. COPY this extension file to your project
 
 2. RENAME the file to match your ViewController
 
 3. ADD THESE CALLS to your original ViewController.swift:
 
    #if DEBUG || STAGING
    import QCBugPlugin
    #endif
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        #if DEBUG || STAGING
        setupQCBugReporting()  // Add this line
        #endif
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        #if DEBUG || STAGING
        updateQCBugReportContext()  // Add this line
        #endif
    }
    
    // Optional: Add shake gesture handling
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        
        #if DEBUG || STAGING
        handleQCShakeGesture(motion)  // Add this line
        #endif
    }
 
 4. CUSTOMIZE the tracking data in this extension file
 
 5. TEST the integration
 
 USAGE NOTES:
 
 NO MORE AUTOMATIC SWIZZLING:
 - Swift no longer supports class initialize() method
 - You must manually call setup methods from your ViewController
 - This gives you explicit control over when QCBugPlugin is activated
 - Minimal changes to original code (just 3 method calls)
 
 INTEGRATION PATTERN:
 - Keep this extension file separate from your main ViewController
 - Only add conditional compilation (#if DEBUG) calls to original code
 - All QCBugPlugin logic stays in the extension
 - Easy to remove by deleting extension file and removing #if blocks
 
 CUSTOMIZATION:
 - Change "YourFeatureName" to your actual feature name
 - Add feature-specific data in setInitialContext()
 - Add dynamic data in updateBugReportContext()
 - Implement collectFormData() if you have forms
 
 SECURITY REMINDERS:
 - ✅ DO track: user selections, form presence, feature state
 - ❌ DON'T track: passwords, PINs, full card numbers, sensitive data
 - ✅ DO use presence flags: "hasPassword": true
 - ❌ DON'T use actual values: "password": "abc123"
 
 */

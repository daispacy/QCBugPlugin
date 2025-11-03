//
//  YourViewModel+QCBugPlugin.swift
//  YourApp
//
//  Template file for integrating QCBugPlugin tracking into a ViewModel
//  WITHOUT modifying the original ViewModel code.
//
//  Usage:
//  1. Copy this file to your project
//  2. Rename to match your ViewModel: e.g., CheckoutViewModel+QCBugPlugin.swift
//  3. Replace "YourViewModel" with your actual class name
//  4. Customize the tracking methods for your business logic
//  5. Call tracking methods from your original ViewModel (minimal intrusion)
//

import Foundation
import QCBugPlugin

#if DEBUG || STAGING

// MARK: - QCBugPlugin Tracking Extension

extension YourViewModel {
    
    // MARK: - Business Logic Tracking
    
    /// Track when a major operation is initiated
    /// Call this at the start of important business operations
    func trackOperationStarted(operationName: String, parameters: [String: Any] = [:]) {
        var trackingData: [String: Any] = [
            "action": "\(operationName)_started",
            "timestamp": Date().timeIntervalSince1970,
            "feature": "YourFeatureName"  // TODO: Change to your feature name
        ]
        
        // Merge operation parameters
        trackingData.merge(parameters) { (_, new) in new }
        
        QCBugPlugin.setCustomData(trackingData)
        
        print("📊 Tracking: \(operationName) started")
    }
    
    /// Track when an operation completes successfully
    /// Call this after successful completion of business operations
    func trackOperationSuccess(operationName: String, result: [String: Any] = [:]) {
        var trackingData: [String: Any] = [
            "action": "\(operationName)_success",
            "timestamp": Date().timeIntervalSince1970,
            "success": true,
            "feature": "YourFeatureName"  // TODO: Change to your feature name
        ]
        
        // Merge result data
        trackingData.merge(result) { (_, new) in new }
        
        QCBugPlugin.setCustomData(trackingData)
        
        print("✅ Tracking: \(operationName) succeeded")
    }
    
    /// Track when an operation fails
    /// Call this in error handling blocks
    func trackOperationFailure(operationName: String, error: Error, context: [String: Any] = [:]) {
        var trackingData: [String: Any] = [
            "action": "\(operationName)_failure",
            "timestamp": Date().timeIntervalSince1970,
            "success": false,
            "errorType": String(describing: type(of: error)),
            "errorMessage": error.localizedDescription,
            "feature": "YourFeatureName"  // TODO: Change to your feature name
        ]
        
        // Add context data
        trackingData.merge(context) { (_, new) in new }
        
        QCBugPlugin.setCustomData(trackingData)
        
        print("❌ Tracking: \(operationName) failed - \(error.localizedDescription)")
    }
    
    // MARK: - User Selection Tracking
    
    /// Track user selections in your feature
    /// Call this when user makes important selections
    func trackUserSelection(selectionType: String, selectedValue: String, additionalData: [String: Any] = [:]) {
        var trackingData: [String: Any] = [
            "action": "user_selection",
            "selectionType": selectionType,
            "selectedValue": selectedValue,
            "timestamp": Date().timeIntervalSince1970,
            "feature": "YourFeatureName"  // TODO: Change to your feature name
        ]
        
        trackingData.merge(additionalData) { (_, new) in new }
        
        QCBugPlugin.setCustomData(trackingData)
        
        print("👆 Tracking: User selected \(selectionType) = \(selectedValue)")
    }
    
    // MARK: - State Changes Tracking
    
    /// Track important state changes in your ViewModel
    /// Call this when significant state transitions occur
    func trackStateChange(from oldState: String, to newState: String, reason: String? = nil) {
        var trackingData: [String: Any] = [
            "action": "state_change",
            "previousState": oldState,
            "currentState": newState,
            "timestamp": Date().timeIntervalSince1970,
            "feature": "YourFeatureName"  // TODO: Change to your feature name
        ]
        
        if let reason = reason {
            trackingData["reason"] = reason
        }
        
        QCBugPlugin.setCustomData(trackingData)
        
        print("🔄 Tracking: State changed from \(oldState) to \(newState)")
    }
    
    // MARK: - Data Validation Tracking
    
    /// Track validation results
    /// Call this after validating user input or data
    func trackValidation(field: String, isValid: Bool, errorMessage: String? = nil) {
        var trackingData: [String: Any] = [
            "action": "validation",
            "field": field,
            "isValid": isValid,
            "timestamp": Date().timeIntervalSince1970,
            "feature": "YourFeatureName"  // TODO: Change to your feature name
        ]
        
        if let errorMessage = errorMessage {
            trackingData["validationError"] = errorMessage
        }
        
        QCBugPlugin.setCustomData(trackingData)
        
        let status = isValid ? "✅" : "❌"
        print("\(status) Tracking: Validation for \(field) - \(isValid)")
    }
    
    // MARK: - Network Request Tracking
    
    /// Track network requests initiated from ViewModel
    /// Call this before making API calls
    func trackNetworkRequest(endpoint: String, method: String, parameters: [String: Any] = [:]) {
        var trackingData: [String: Any] = [
            "action": "network_request",
            "endpoint": endpoint,
            "method": method,
            "timestamp": Date().timeIntervalSince1970,
            "feature": "YourFeatureName"  // TODO: Change to your feature name
        ]
        
        // Add sanitized parameters (remove sensitive data)
        let sanitizedParams = sanitizeParameters(parameters)
        trackingData["parameters"] = sanitizedParams
        
        QCBugPlugin.setCustomData(trackingData)
        
        print("🌐 Tracking: Network request to \(endpoint)")
    }
    
    /// Track network responses
    /// Call this after receiving API responses
    func trackNetworkResponse(endpoint: String, statusCode: Int, success: Bool, responseTime: TimeInterval? = nil) {
        var trackingData: [String: Any] = [
            "action": "network_response",
            "endpoint": endpoint,
            "statusCode": statusCode,
            "success": success,
            "timestamp": Date().timeIntervalSince1970,
            "feature": "YourFeatureName"  // TODO: Change to your feature name
        ]
        
        if let responseTime = responseTime {
            trackingData["responseTime"] = responseTime
        }
        
        QCBugPlugin.setCustomData(trackingData)
        
        let status = success ? "✅" : "❌"
        print("\(status) Tracking: Network response from \(endpoint) - Status: \(statusCode)")
    }
    
    // MARK: - Helper Methods
    
    /// Sanitize parameters to remove sensitive data
    /// Override this method to customize sanitization for your feature
    private func sanitizeParameters(_ parameters: [String: Any]) -> [String: Any] {
        var sanitized = parameters
        
        // Remove common sensitive fields
        let sensitiveKeys = ["password", "pin", "token", "secret", "apiKey", "cardNumber", "cvv"]
        
        for key in sensitiveKeys {
            if sanitized[key] != nil {
                sanitized[key] = "[REDACTED]"
            }
        }
        
        // TODO: Add your specific sensitive fields
        // sanitized["yourSensitiveField"] = "[REDACTED]"
        
        return sanitized
    }
}

// MARK: - Example Integration Points

extension YourViewModel {
    
    /*
     EXAMPLE: How to integrate into your existing ViewModel methods
     
     // In your original ViewModel:
     func fetchData() {
         // Add tracking at the start
         trackOperationStarted(operationName: "FetchData", parameters: ["dataType": "products"])
         
         // Your existing code...
         apiService.fetchData { [weak self] result in
             switch result {
             case .success(let data):
                 // Track success
                 self?.trackOperationSuccess(operationName: "FetchData", result: ["itemCount": data.count])
                 
             case .failure(let error):
                 // Track failure
                 self?.trackOperationFailure(operationName: "FetchData", error: error)
             }
         }
     }
     
     // Track user selections
     func selectItem(_ item: Item) {
         trackUserSelection(
             selectionType: "item",
             selectedValue: item.id,
             additionalData: ["itemName": item.name, "itemPrice": item.price]
         )
         
         // Your existing selection logic...
     }
     
     // Track state changes
     func updateState(to newState: State) {
         let oldState = currentState
         trackStateChange(from: oldState.rawValue, to: newState.rawValue)
         
         // Your existing state update logic...
         currentState = newState
     }
     
     // Track validation
     func validateInput() -> Bool {
         let isValid = input.count > 0
         trackValidation(field: "input", isValid: isValid, errorMessage: isValid ? nil : "Input is empty")
         
         return isValid
     }
     */
}

#endif

// MARK: - Usage Notes
/*
 
 HOW TO USE THIS TEMPLATE:
 
 1. COPY THIS FILE to your project alongside your ViewModel
 
 2. RENAME THE FILE to match your ViewModel:
    Example: CheckoutViewModel+QCBugPlugin.swift
 
 3. REPLACE "YourViewModel" with your actual ViewModel class name
 
 4. REPLACE "YourFeatureName" with your actual feature name throughout
 
 5. ADD TRACKING CALLS to your ViewModel methods:
    - Call trackOperationStarted() at the beginning of operations
    - Call trackOperationSuccess() on successful completion
    - Call trackOperationFailure() in error handlers
    - Call trackUserSelection() when users make selections
    - Call trackStateChange() during state transitions
 
 6. CUSTOMIZE sanitizeParameters() for your specific sensitive data
 
 7. BUILD in DEBUG or STAGING configuration
 
 8. TEST the integration:
    - Perform operations in your feature
    - Check console logs for tracking confirmations
    - Trigger bug report to verify context data
 
 INTEGRATION STRATEGY:
 
 Option 1: Minimal Intrusion (Recommended)
 - Add tracking calls only at key decision points
 - Track start/success/failure of major operations
 - Track user selections and state changes
 
 Option 2: Comprehensive Tracking
 - Track every operation, validation, and state change
 - Provides maximum context for bug reports
 - May require more tracking method calls
 
 BEST PRACTICES:
 
 ✅ DO:
 - Track business logic outcomes (success/failure)
 - Track user selections and inputs (sanitized)
 - Track state transitions
 - Track network requests and responses
 - Sanitize sensitive data before tracking
 
 ❌ DON'T:
 - Track passwords, PINs, tokens, or API keys
 - Track full credit card numbers or CVV
 - Track personal identifying information without sanitization
 - Over-track - focus on meaningful events
 - Block or slow down your business logic
 
 SECURITY CHECKLIST:
 
 □ Wrapped in #if DEBUG || STAGING
 □ Sensitive data sanitized in sanitizeParameters()
 □ No passwords, PINs, or tokens tracked
 □ No full credit card numbers tracked
 □ Network parameters sanitized
 □ User data anonymized or flagged only
 
 */

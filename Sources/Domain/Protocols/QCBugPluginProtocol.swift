//
//  QCBugPluginProtocol.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import UIKit

/// Main protocol for the QC Bug Plugin functionality
public protocol QCBugPluginProtocol: AnyObject {
    /// Start tracking user interactions and screen transitions
    func startTracking()
    
    /// Stop tracking user interactions
    func stopTracking()
    
    /// Present the bug report interface
    func presentBugReport()
    
    /// Check if tracking is currently enabled
    func isTrackingEnabled() -> Bool
    
    /// Configure the plugin with webhook URL and API key
    func configure(webhookURL: String, apiKey: String?)
    
    /// Set custom data to be included with bug reports
    func setCustomData(_ data: [String: Any])
    
    /// Enable or disable screen recording capability
    func setScreenRecordingEnabled(_ enabled: Bool)
}

/// Configuration protocol for the plugin
public protocol QCBugPluginConfiguration {
    var webhookURL: String { get }
    var apiKey: String? { get }
    var customData: [String: Any] { get }
    var isScreenRecordingEnabled: Bool { get }
    var maxActionHistoryCount: Int { get }
    var enableFloatingButton: Bool { get }
}

/// Delegate protocol for plugin events
public protocol QCBugPluginDelegate: AnyObject {
    /// Called when tracking starts
    func bugPluginDidStartTracking(_ plugin: QCBugPluginProtocol)
    
    /// Called when tracking stops
    func bugPluginDidStopTracking(_ plugin: QCBugPluginProtocol)
    
    /// Called when a bug report is submitted successfully
    func bugPlugin(_ plugin: QCBugPluginProtocol, didSubmitBugReport reportId: String)
    
    /// Called when bug report submission fails
    func bugPlugin(_ plugin: QCBugPluginProtocol, didFailToSubmitBugReport error: Error)
    
    /// Called before presenting the bug report interface (return false to cancel)
    func bugPluginShouldPresentBugReport(_ plugin: QCBugPluginProtocol) -> Bool
}
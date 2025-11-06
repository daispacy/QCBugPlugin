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
    /// Present the bug report interface
    func presentBugReport()

    /// Configure the plugin with the primary application window and configuration
    /// - Parameters:
    ///   - window: The host application's root window to attach UI affordances to
    ///   - configuration: The configuration describing integration options
    func configure(using window: UIWindow, configuration: QCBugPluginConfig)
    
    /// Set custom data to be included with bug reports
    func setCustomData(_ data: [String: Any])
    
    /// Enable or disable screen recording capability
    func setScreenRecordingEnabled(_ enabled: Bool)

    /// Start screen recording manually
    /// - Parameter completion: Callback with success/failure result
    func startScreenRecording(completion: @escaping (Result<Void, Error>) -> Void)

    /// Stop screen recording manually
    /// - Parameter completion: Callback with video URL or error
    func stopScreenRecording(completion: @escaping (Result<URL, Error>) -> Void)

    /// Check if screen recording is currently active
    func isScreenRecording() -> Bool

    /// Check if the current recording is owned by this plugin
    func isScreenRecordingOwnedByPlugin() -> Bool
}

/// Configuration protocol for the plugin
public protocol QCBugPluginConfiguration {
    var webhookURL: String { get }
    var apiKey: String? { get }
    var customData: [String: Any] { get }
    var isScreenRecordingEnabled: Bool { get }
    var enableFloatingButton: Bool { get }
    var gitLabAppConfig: GitLabAppConfig? { get }
}

/// Delegate protocol for plugin events
public protocol QCBugPluginDelegate: AnyObject {
    /// Called when a bug report is submitted successfully
    func bugPlugin(_ plugin: QCBugPluginProtocol, didSubmitBugReport reportId: String)

    /// Called when bug report submission fails
    func bugPlugin(_ plugin: QCBugPluginProtocol, didFailToSubmitBugReport error: Error)

    /// Called before presenting the bug report interface (return false to cancel)
    func bugPluginShouldPresentBugReport(_ plugin: QCBugPluginProtocol) -> Bool

    // MARK: - Screen Recording Callbacks (Optional - have default implementations)

    /// Called when screen recording starts successfully
    func bugPluginDidStartRecording(_ plugin: QCBugPluginProtocol)

    /// Called when screen recording stops successfully with the video URL
    func bugPlugin(_ plugin: QCBugPluginProtocol, didStopRecordingWithURL url: URL)

    /// Called when screen recording fails to start or stop
    func bugPlugin(_ plugin: QCBugPluginProtocol, didFailRecordingWithError error: Error)
    
    // MARK: - Session Callbacks (Optional - have default implementations)
    
    /// Called when session is cleared
    func bugPluginDidClearSession(_ plugin: QCBugPluginProtocol)
}

// MARK: - Default Implementations for Optional Methods

public extension QCBugPluginDelegate {
    /// Default implementation - does nothing (override to receive callbacks)
    func bugPluginDidStartRecording(_ plugin: QCBugPluginProtocol) { }

    /// Default implementation - does nothing (override to receive callbacks)
    func bugPlugin(_ plugin: QCBugPluginProtocol, didStopRecordingWithURL url: URL) { }

    /// Default implementation - does nothing (override to receive callbacks)
    func bugPlugin(_ plugin: QCBugPluginProtocol, didFailRecordingWithError error: Error) { }
    
    /// Default implementation - does nothing (override to receive callbacks)
    func bugPluginDidClearSession(_ plugin: QCBugPluginProtocol) { }
}
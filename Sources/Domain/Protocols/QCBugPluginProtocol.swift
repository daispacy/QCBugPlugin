//
//  QCBugPluginProtocol.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation

/// Delegate protocol for plugin events exposed to host applications
public protocol QCBugPluginDelegate: AnyObject {
    /// Return `false` to prevent the bug report interface from being presented
    func bugPluginShouldPresentBugReport() -> Bool

    /// Called when a bug report is submitted successfully
    func bugPluginDidSubmitReport(_ reportId: String)

    /// Called when bug report submission fails
    func bugPluginDidFailToSubmitReport(_ error: Error)

    /// Called when screen recording starts successfully
    func bugPluginDidStartRecording()

    /// Called when screen recording stops successfully with the recorded video URL
    func bugPlugin(didStopRecordingWith url: URL)

    /// Called when screen recording fails to start or stop
    func bugPluginDidFailRecording(_ error: Error)

    /// Called when session data is cleared
    func bugPluginDidClearSession()

    /// Called when pending crash reports are detected on app launch
    func bugPluginDidDetectCrashes(_ crashReports: [CrashReport])

    /// Called when user dismisses a crash report without reporting
    func bugPluginDidDismissCrash(_ crashReport: CrashReport)
}

// MARK: - Default Implementations for Optional Methods

public extension QCBugPluginDelegate {
    func bugPluginShouldPresentBugReport() -> Bool { true }
    func bugPluginDidSubmitReport(_ reportId: String) { }
    func bugPluginDidFailToSubmitReport(_ error: Error) { }
    func bugPluginDidStartRecording() { }
    func bugPlugin(didStopRecordingWith url: URL) { }
    func bugPluginDidFailRecording(_ error: Error) { }
    func bugPluginDidClearSession() { }
    func bugPluginDidDetectCrashes(_ crashReports: [CrashReport]) { }
    func bugPluginDidDismissCrash(_ crashReport: CrashReport) { }
}
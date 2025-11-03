//
//  QCBugPluginConfiguration.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation

/// Configuration for the QC Bug Plugin
public struct QCBugPluginConfig: QCBugPluginConfiguration {
    public let webhookURL: String
    public let apiKey: String?
    public let customData: [String: Any]
    public let isScreenRecordingEnabled: Bool
    public let maxActionHistoryCount: Int
    public let enableFloatingButton: Bool
    
    public init(
        webhookURL: String,
        apiKey: String? = nil,
        customData: [String: Any] = [:],
        isScreenRecordingEnabled: Bool = true,
        maxActionHistoryCount: Int = 50,
        enableFloatingButton: Bool = false
    ) {
        self.webhookURL = webhookURL
        self.apiKey = apiKey
        self.customData = customData
        self.isScreenRecordingEnabled = isScreenRecordingEnabled
        self.maxActionHistoryCount = maxActionHistoryCount
        self.enableFloatingButton = enableFloatingButton
    }
}

/// Notification names for plugin events
public extension Notification.Name {
    static let qcBugPluginDidStartTracking = Notification.Name("qcBugPluginDidStartTracking")
    static let qcBugPluginDidStopTracking = Notification.Name("qcBugPluginDidStopTracking")
    static let qcBugPluginDidSubmitReport = Notification.Name("qcBugPluginDidSubmitReport")
    static let qcBugPluginDidFailToSubmitReport = Notification.Name("qcBugPluginDidFailToSubmitReport")
    static let qcBugPluginDidTrackUserAction = Notification.Name("qcBugPluginDidTrackUserAction")
}
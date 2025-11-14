//
//  QCBugPluginConfiguration.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation

/// Configuration for the QC Bug Plugin
public struct QCBugPluginConfig {
    public let webhookURL: String
    public let apiKey: String?
    public let customData: [String: Any]
    public let isScreenRecordingEnabled: Bool
    public let enableFloatingButton: Bool
    public let gitLabAppConfig: GitLabAppConfig?
    public let enableCrashReporting: Bool
    public let team: String

    public init(
        webhookURL: String,
        apiKey: String? = nil,
        customData: [String: Any] = [:],
        isScreenRecordingEnabled: Bool = true,
        enableFloatingButton: Bool = false,
        gitLabAppConfig: GitLabAppConfig? = nil,
        enableCrashReporting: Bool = true,
        team: String = "ios"
    ) {
        self.webhookURL = webhookURL
        self.apiKey = apiKey
        self.customData = customData
        self.isScreenRecordingEnabled = isScreenRecordingEnabled
        self.enableFloatingButton = enableFloatingButton
        self.gitLabAppConfig = gitLabAppConfig
        self.enableCrashReporting = enableCrashReporting
        self.team = team
    }
}

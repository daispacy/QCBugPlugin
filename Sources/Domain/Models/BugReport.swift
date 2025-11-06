//
//  BugReport.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import UIKit

/// GitLab credentials associated with a bug report submission
struct GitLabCredentials: Codable {
    let pat: String
    let project: String?

    init(pat: String, project: String? = nil) {
        self.pat = pat
        self.project = project
    }
}

/// Represents a complete bug report
struct BugReport: Codable {
    /// Unique identifier for the bug report
    let id: String
    
    /// Timestamp when the report was created
    let timestamp: Date
    
    /// Bug description provided by the user
    let description: String
    
    /// Priority level of the bug
    let priority: BugPriority
    
    /// Category of the bug
    let category: BugCategory
    
    /// Steps to reproduce (user actions history)
    let userActions: [UserAction]
    
    /// Device information
    let deviceInfo: DeviceInfo
    
    /// App information
    let appInfo: AppInfo
    
    /// Screenshot URLs (if any) - Deprecated, use mediaAttachments instead
    let screenshots: [String]

    /// Screen recording URL (if available) - Deprecated, use mediaAttachments instead
    let screenRecordingURL: String?

    /// Media attachments (screenshots and recordings)
    let mediaAttachments: [MediaAttachment]
    
    /// Custom data provided by the app
    let customData: [String: String]
    
    /// Current screen where bug was reported
    let currentScreen: String?
    
    /// Network information
    let networkInfo: NetworkInfo?
    
    /// Memory usage information
    let memoryInfo: MemoryInfo?

    /// Username assigned to handle the bug, if provided
    let assigneeUsername: String?

    /// External issue tracker number associated with the bug
    let issueNumber: Int?

    /// GitLab project path or identifier associated with this submission
    let gitLabProject: String?

    let whtype: String
    let gitLabCredentials: GitLabCredentials?

    init(
        description: String,
        priority: BugPriority,
        category: BugCategory,
        userActions: [UserAction],
        deviceInfo: DeviceInfo,
        appInfo: AppInfo,
        screenshots: [String] = [],
        screenRecordingURL: String? = nil,
        customData: [String: String] = [:],
        currentScreen: String? = nil,
        networkInfo: NetworkInfo? = nil,
        memoryInfo: MemoryInfo? = nil,
        mediaAttachments: [MediaAttachment] = [],
        gitLabProject: String? = nil,
        assigneeUsername: String? = nil,
        issueNumber: Int? = nil,
        whtype: String = "report_issue",
        gitLabCredentials: GitLabCredentials? = nil
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.description = description
        self.priority = priority
        self.category = category
        self.userActions = userActions
        self.deviceInfo = deviceInfo
        self.appInfo = appInfo
        self.screenshots = screenshots
        self.screenRecordingURL = screenRecordingURL
        self.customData = customData
        self.currentScreen = currentScreen
        self.networkInfo = networkInfo
        self.memoryInfo = memoryInfo
        self.mediaAttachments = mediaAttachments
        self.gitLabProject = gitLabProject
        self.assigneeUsername = assigneeUsername
        self.issueNumber = issueNumber
        self.whtype = whtype
        self.gitLabCredentials = gitLabCredentials
    }
}

/// Bug priority levels
enum BugPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var colorHex: String {
        switch self {
        case .low: return "#28a745"      // Green
        case .medium: return "#ffc107"   // Yellow
        case .high: return "#fd7e14"     // Orange
        case .critical: return "#dc3545" // Red
        }
    }
}

/// Bug categories
enum BugCategory: String, Codable, CaseIterable {
    case ui = "ui"
    case functionality = "functionality"
    case performance = "performance"
    case crash = "crash"
    case data = "data"
    case network = "network"
    case security = "security"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .ui: return "UI/UX Issue"
        case .functionality: return "Functionality"
        case .performance: return "Performance"
        case .crash: return "Crash"
        case .data: return "Data Issue"
        case .network: return "Network"
        case .security: return "Security"
        case .other: return "Other"
        }
    }
}

/// Device information
struct DeviceInfo: Codable {
    let deviceModel: String
    let systemName: String
    let systemVersion: String
    let screenSize: CGSize
    let screenScale: CGFloat
    let deviceOrientation: String
    let batteryLevel: Float
    let batteryState: String
    let diskSpace: DiskSpaceInfo
    let locale: String
    let timezone: String
    
    init() {
        let device = UIDevice.current
        let screen = UIScreen.main
        
        self.deviceModel = Self.deviceModel()
        self.systemName = device.systemName
        self.systemVersion = device.systemVersion
        self.screenSize = screen.bounds.size
        self.screenScale = screen.scale
        self.deviceOrientation = Self.orientationString(device.orientation)
        
        device.isBatteryMonitoringEnabled = true
        self.batteryLevel = device.batteryLevel
        self.batteryState = Self.batteryStateString(device.batteryState)
        
        self.diskSpace = DiskSpaceInfo()
        self.locale = Locale.current.identifier
        self.timezone = TimeZone.current.identifier
    }
    
    private static func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    private static func orientationString(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait: return "portrait"
        case .portraitUpsideDown: return "portraitUpsideDown"
        case .landscapeLeft: return "landscapeLeft"
        case .landscapeRight: return "landscapeRight"
        case .faceUp: return "faceUp"
        case .faceDown: return "faceDown"
        default: return "unknown"
        }
    }
    
    private static func batteryStateString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unplugged: return "unplugged"
        case .charging: return "charging"
        case .full: return "full"
        default: return "unknown"
        }
    }
}

/// App information
struct AppInfo: Codable {
    let bundleIdentifier: String
    let version: String
    let buildNumber: String
    let appName: String
    
    init() {
        let bundle = Bundle.main
        self.bundleIdentifier = bundle.bundleIdentifier ?? "unknown"
        self.version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.buildNumber = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        self.appName = bundle.infoDictionary?["CFBundleDisplayName"] as? String ?? 
                      bundle.infoDictionary?["CFBundleName"] as? String ?? "unknown"
    }
}

/// Disk space information
struct DiskSpaceInfo: Codable {
    let freeSpace: Int64
    let totalSpace: Int64
    
    init() {
        let fileManager = FileManager.default
        if let attributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            self.freeSpace = (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            self.totalSpace = (attributes[.systemSize] as? NSNumber)?.int64Value ?? 0
        } else {
            self.freeSpace = 0
            self.totalSpace = 0
        }
    }
}

/// Network information
struct NetworkInfo: Codable {
    let connectionType: String
    let carrierName: String?
    
    init() {
        // This would need to be implemented with proper network detection
        self.connectionType = "unknown"
        self.carrierName = nil
    }
}

/// Memory information
struct MemoryInfo: Codable {
    let usedMemory: Int64
    let availableMemory: Int64
    
    init() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            self.usedMemory = Int64(info.resident_size)
        } else {
            self.usedMemory = 0
        }
        
        // Get available memory
        let hostPort = mach_host_self()
        var hostSize = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.stride / MemoryLayout<integer_t>.stride)
        var pageSize: vm_size_t = 0
        
        var vmStats = vm_statistics_data_t()
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(hostSize)) {
                host_statistics(hostPort, HOST_VM_INFO, $0, &hostSize)
            }
        }
        
        let _ = host_page_size(hostPort, &pageSize)
        
        if result == KERN_SUCCESS {
            self.availableMemory = Int64(vmStats.free_count) * Int64(pageSize)
        } else {
            self.availableMemory = 0
        }
    }
}

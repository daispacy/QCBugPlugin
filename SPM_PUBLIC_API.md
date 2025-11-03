# QCBugPlugin - Swift Package Manager Public API Guide

## Overview
This document outlines the public API surface for QCBugPlugin SPM framework, ensuring proper encapsulation and extensibility.

## ✅ Current Public API Status

### 1. Entry Point (100% Public)
```swift
// QCBugPlugin.swift
public final class QCBugPlugin {
    public static let shared: QCBugPluginProtocol
    public static let version: String
    public static let buildNumber: String
    public static var frameworkInfo: [String: Any]
    
    public static func configure(webhookURL: String)
    public static func configure(webhookURL: String, apiKey: String?)
    public static func configure(with config: QCBugPluginConfig)
    public static func startTracking()
    public static func stopTracking()
    public static func presentBugReport()
    public static var isTrackingEnabled: Bool
    public static func setCustomData(_ data: [String: Any])
    public static func setScreenRecordingEnabled(_ enabled: Bool)
}
```

### 2. Protocols (All Public)
```swift
// Domain/Protocols/QCBugPluginProtocol.swift
public protocol QCBugPluginProtocol: AnyObject { ... }
public protocol QCBugPluginConfiguration { ... }
public protocol QCBugPluginDelegate: AnyObject { ... }

// Domain/Protocols/UITrackingProtocol.swift
public protocol UITrackingProtocol: AnyObject { ... }
public protocol UITrackingDelegate: AnyObject { ... }

// Domain/Protocols/ScreenRecordingProtocol.swift
public protocol ScreenRecordingProtocol: AnyObject { ... }

// Domain/Protocols/BugReportProtocol.swift
public protocol BugReportProtocol: AnyObject { ... }
```

### 3. Models (All Public)
```swift
// Domain/Models/BugReport.swift
public struct BugReport: Codable {
    public let id: String
    public let timestamp: Date
    public let description: String
    // ... all properties public
    public init(...) // Public initializer
}

public enum BugPriority: String, Codable, CaseIterable {
    case low, medium, high, critical
    public var displayName: String { ... }
    public var colorHex: String { ... }
}

public enum BugCategory: String, Codable, CaseIterable {
    case ui, functionality, performance, crash, data, network, security, other
    public var displayName: String { ... }
}

public struct DeviceInfo: Codable {
    // All properties public
    public init() // Public initializer
}

public struct AppInfo: Codable {
    public init()
}

public struct NetworkInfo: Codable {
    public init()
}

public struct MemoryInfo: Codable {
    public init()
}

public struct DiskSpaceInfo: Codable {
    public init()
}

// Domain/Models/UserAction.swift
public struct UserAction: Codable {
    public let id: String
    public let timestamp: Date
    public let actionType: ActionType
    // ... all properties public
    public init(...) // Public initializer
}

public enum ActionType: String, Codable, CaseIterable {
    case screenView, buttonTap, textInput, ...
    public var displayName: String { ... }
}

public struct ElementInfo: Codable {
    // All properties public
    public init(...) // Public initializer
}

// Domain/Models/QCBugPluginConfiguration.swift
public struct QCBugPluginConfig: QCBugPluginConfiguration {
    public let webhookURL: String
    public let apiKey: String?
    // ... all properties public
    public init(...) // Public initializer
}
```

### 4. Error Types (Public)
```swift
// Domain/Protocols/ScreenRecordingProtocol.swift
public enum ScreenRecordingError: Error, LocalizedError {
    case notAvailable
    case alreadyRecording
    case notRecording
    case recordingFailed(String)
    case saveFailed(String)
    
    public var errorDescription: String? { ... }
}

// Domain/Protocols/BugReportProtocol.swift
public enum BugReportError: Error, LocalizedError {
    case invalidURL
    case invalidData
    case networkError(String)
    case serverError(Int)
    case timeout
    case unknown
    
    public var errorDescription: String? { ... }
}
```

### 5. Notifications (Public)
```swift
// Domain/Models/QCBugPluginConfiguration.swift
public extension Notification.Name {
    static let qcBugPluginDidStartTracking
    static let qcBugPluginDidStopTracking
    static let qcBugPluginDidSubmitReport
    static let qcBugPluginDidFailToSubmitReport
    static let qcBugPluginDidTrackUserAction
}
```

### 6. Service Classes (Public for Extensibility)
```swift
// Data/Services/UITrackingService.swift
public final class UITrackingService: NSObject, UITrackingProtocol {
    public weak var delegate: UITrackingDelegate?
    public var isTracking: Bool { get }
    public var maxActionHistoryCount: Int { get set }
    
    public override init()
    
    public func startTracking()
    public func stopTracking()
    public func getActionHistory() -> [UserAction]
    public func clearActionHistory()
}

// Data/Services/ScreenRecordingService.swift
public final class ScreenRecordingService: NSObject, ScreenRecordingProtocol {
    public var isAvailable: Bool { get }
    public var isRecording: Bool { get }
    
    public override init()
    
    public func requestPermission(completion: @escaping (Bool) -> Void)
    public func startRecording(completion: @escaping (Result<Void, ScreenRecordingError>) -> Void)
    public func stopRecording(completion: @escaping (Result<URL, ScreenRecordingError>) -> Void)
}

// Data/Services/BugReportAPIService.swift
public final class BugReportAPIService: BugReportProtocol {
    public init(webhookURL: String, apiKey: String? = nil)
    
    public func submitBugReport(_ report: BugReport, completion: @escaping (Result<String, BugReportError>) -> Void)
    public func uploadFile(_ fileURL: URL, for reportId: String, completion: @escaping (Result<String, BugReportError>) -> Void)
}
```

### 7. UI Components (Public)
```swift
// Presentation/QCBugReportViewController.swift
public protocol QCBugReportViewControllerDelegate: AnyObject {
    func bugReportViewController(_ controller: QCBugReportViewController, didSubmitReport report: BugReport)
    func bugReportViewControllerDidCancel(_ controller: QCBugReportViewController)
}

public final class QCBugReportViewController: UIViewController {
    public weak var delegate: QCBugReportViewControllerDelegate?
    
    public init(
        actionHistory: [UserAction],
        screenRecorder: ScreenRecordingProtocol?,
        configuration: QCBugPluginConfiguration?
    )
}

// Presentation/QCFloatingButton.swift
public final class QCFloatingButton: UIButton {
    public override init(frame: CGRect)
    // Public for customization if needed
}
```

### 8. Manager (Public Interface)
```swift
// Manager/QCBugPluginManager.swift
public final class QCBugPluginManager: QCBugPluginProtocol {
    public static let shared: QCBugPluginManager
    public weak var delegate: QCBugPluginDelegate?
    
    public func configure(webhookURL: String, apiKey: String?)
    public func configure(with config: QCBugPluginConfig)
    public func startTracking()
    public func stopTracking()
    public func presentBugReport()
    public func isTrackingEnabled() -> Bool
    public func setCustomData(_ data: [String: Any])
    public func setScreenRecordingEnabled(_ enabled: Bool)
}

// QCBugReportViewControllerDelegate implementation
extension QCBugPluginManager {
    public func bugReportViewController(_ controller: QCBugReportViewController, didSubmitReport report: BugReport)
    public func bugReportViewControllerDidCancel(_ controller: QCBugReportViewController)
}
```

## 🔒 Internal/Private Implementation Details

### Should NOT Be Public:
1. **Method Swizzling Extensions**: Extensions on UIViewController, UIButton, UITextField for swizzling
2. **Private Helpers**: Internal utility methods in services
3. **HTML Generation**: Can be internal for easier testing, not part of public API
4. **State Management**: Internal properties like `actionHistory`, `_isTracking`

### Example Internal Code:
```swift
// UITrackingService.swift - These are INTERNAL
extension UIViewController {
    @objc dynamic func qc_viewDidAppear(_ animated: Bool) { ... }
    @objc dynamic func qc_viewDidDisappear(_ animated: Bool) { ... }
}

extension UIButton {
    @objc dynamic func qc_sendAction(...) { ... }
}

// Private/Internal helpers
private func addAction(_ action: UserAction) { ... }
private func trimHistoryIfNeeded() { ... }
private func getCurrentScreenInfo() -> (String, String) { ... }
```

## 📦 SPM Integration Example

### For Package Consumers:
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/daispacy/QCBugPlugin.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["QCBugPlugin"]
    )
]
```

### Usage:
```swift
import QCBugPlugin

// Simple setup
QCBugPlugin.configure(webhookURL: "https://webhook.example.com")
QCBugPlugin.startTracking()

// Advanced setup
let config = QCBugPluginConfig(
    webhookURL: "https://webhook.example.com",
    apiKey: "your-key",
    customData: ["environment": "staging"],
    isScreenRecordingEnabled: true,
    maxActionHistoryCount: 100,
    enableFloatingButton: true
)
QCBugPlugin.configure(with: config)

// Use delegates
class MyDelegate: QCBugPluginDelegate {
    func bugPluginDidStartTracking(_ plugin: QCBugPluginProtocol) { ... }
    func bugPluginDidSubmitReport(_ plugin: QCBugPluginProtocol, report: BugReport) { ... }
}
```

## ✨ Extensibility Points

### 1. Custom UI Tracking Service
```swift
import QCBugPlugin

class CustomUITracker: UITrackingProtocol {
    // Implement protocol
    // Use instead of default UITrackingService
}
```

### 2. Custom Screen Recording
```swift
import QCBugPlugin

class CustomRecorder: ScreenRecordingProtocol {
    // Implement protocol
    // Use custom recording logic
}
```

### 3. Custom Bug Report Service
```swift
import QCBugPlugin

class CustomBugReportAPI: BugReportProtocol {
    // Implement protocol
    // Send to custom endpoint with custom format
}
```

## 🎯 Summary

**Total Public API Surface:**
- ✅ 1 main entry class (`QCBugPlugin`)
- ✅ 7 protocols (all public)
- ✅ 11 model structs/enums (all public with public inits)
- ✅ 2 error enums (public)
- ✅ 5 notification names (public)
- ✅ 3 service classes (public for extensibility)
- ✅ 2 UI component classes (public)
- ✅ 1 manager class (public)

**All public types have:**
- ✅ `public` access modifier
- ✅ `public` initializers where applicable
- ✅ All protocol requirements are `public`
- ✅ Proper documentation comments

This design ensures:
1. ✅ Easy integration for SPM consumers
2. ✅ Clear API boundaries
3. ✅ Extensibility through protocols
4. ✅ Proper encapsulation of internal details
5. ✅ Type-safe, compile-time checked integration

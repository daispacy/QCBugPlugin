# QCBugPlugin Framework - AI Coding Assistant Instructions

## Architecture Overview

QCBugPlugin is an iOS Swift Package Manager framework for QC bug reporting with optional screen recording and webhook integration. It follows Clean Architecture with protocol-based design and native floating controls managed internally by the framework.

**Key Architecture Layers:**
- **Entry Point**: `QCBugPlugin.swift` - Static convenience API that delegates to `QCBugPluginManager.shared`
- **Manager**: `QCBugPluginManager` - Singleton coordinator managing all services and state
- **Services**: Screen recording (ReplayKit), API submission (multipart webhooks)
- **Presentation**: Hybrid WKWebView + HTML/JS interface with native bridge communication

## SPM Public API Requirements

### What MUST Be Public
**Entry Points & Managers:**
- `QCBugPlugin` class - all static methods and properties
- `QCBugPluginManager.shared` property (typed as `QCBugPluginProtocol`)

**All Protocols:**
- `QCBugPluginProtocol`, `ScreenRecordingProtocol`, `BugReportProtocol`
- `QCBugPluginDelegate`, `QCBugReportViewControllerDelegate`
- `QCBugPluginConfiguration`

**All Models & Enums:**
- `BugReport`, `UserAction`, `ElementInfo`, `QCBugPluginConfig`
- `DeviceInfo`, `AppInfo`, `NetworkInfo`, `MemoryInfo`, `DiskSpaceInfo`
- `BugPriority`, `BugCategory`, `UserAction.ActionType`
- `ScreenRecordingError`, `BugReportError`
- All model initializers (with `public init()`)

**Service Classes (for extensibility):**
- `ScreenRecordingService`, `BugReportAPIService`
- `QCBugReportViewController`, `QCFloatingButton`
- All protocol-conforming methods

**Notifications:**
- `Notification.Name` extensions (`.qcBugPluginDidSubmitReport`, etc.)

### What SHOULD Be Internal/Private
- Private helper methods in services
- Internal state management properties
- HTML/CSS/JS generation internals (can be `internal` for testing)

## Critical Patterns & Conventions

### Protocol-First Design
All major components implement protocols (`QCBugPluginProtocol`, `ScreenRecordingProtocol`, `BugReportProtocol`). When extending functionality:
- Define protocol in `Domain/Protocols/` first (mark `public`)
- Implement service in `Data/Services/` (class is `public final`, methods are `public`)
- Wire through `QCBugPluginManager`

### Native-Web Bridge Communication
`QCBugReportViewController` uses WKScriptMessageHandler pattern:
- JavaScript calls: `window.webkit.messageHandlers.bugReportHandler.postMessage(data)`
- Native handling: `userContentController(_:didReceive:)` routes messages
- HTML generation: All UI in `QCBugReportViewController+HTML.swift`

### Threading Model
- **Main Queue**: UI operations, delegate callbacks, notifications
- **Background**: Screen recording, API calls

## Essential Workflows

### Bug Report Submission Flow
1. User triggers via floating button/shake gesture → `QCBugPluginManager.presentBugReport()`
2. Collect data: device info, custom data, any captured media
3. Present WKWebView with HTML form
4. User fills form → JS → native bridge → validation
5. Optional screen recording via ReplayKit
6. Package as `BugReport` model → multipart HTTP POST to webhook

### Integration Points
**Host App Setup:**
```swift
// AppDelegate - typical integration
import QCBugPlugin

func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = RootViewController()
    window?.makeKeyAndVisible()

    if let window {
        let config = QCBugPluginConfig(webhookURL: "https://...", enableFloatingButton: true)
        QCBugPlugin.configure(using: window, configuration: config)
    }

    return true
}
```

**Custom Data Pattern:**
```swift
QCBugPlugin.setCustomData([
    "userId": UserManager.current.id,
    "feature_flags": FeatureManager.enabledFlags
])
```

### SPM Configuration
- **Package.swift**: iOS 12+ support, Swift 5.3+
- **No external dependencies** (uses native ReplayKit, WebKit, UIKit)
- **Resources**: Processed from `Presentation/Resources/`
- **Test target**: Prepared for unit tests

## Key Implementation Details

### Memory Management
- Screen recordings stored temporarily, cleaned after submission
- Weak delegate references throughout

### Error Handling
- Network errors in `BugReportAPIService` with comprehensive mapping (public enum)
- ReplayKit permission/availability checks in `ScreenRecordingService` (public enum)
- Graceful degradation when services unavailable

### Debug Features
- `QCFloatingButton` for debug builds only
- Comprehensive console logging with emoji prefixes
- Framework version/build info accessible via `QCBugPlugin.frameworkInfo`

### Security Considerations
- Local processing only, direct webhook submission
- Optional API key authentication
- HTTPS webhook URLs recommended
- Avoid collecting sensitive user data in custom fields

## File Organization Logic

- **Domain/Models/**: Pure `public struct` data structures with `public init()`
- **Domain/Protocols/**: `public protocol` service contracts and delegation patterns
- **Manager/**: `public final class` central coordination
- **Data/Services/**: `public final class` implementations with `internal` helpers
- **Presentation/**: `public final class` UI controllers

When adding features, follow this layering and always start with `public protocol` definition in Domain layer.
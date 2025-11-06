# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QCBugPlugin is an iOS Swift Package Manager framework for bug reporting with screen recording, screenshot annotation, and GitLab webhook integration. It follows Clean Architecture principles with protocol-based design.

**Core Features:**
- Screen recording via ReplayKit framework
- Screenshot capture with annotation tools
- GitLab webhook submission with authentication
- Floating action buttons for debug builds
- Comprehensive device/app diagnostics collection
- Session-based media attachment management

## Architecture

### Clean Architecture Layers

The codebase follows Clean Architecture with strict separation of concerns:

**Domain Layer** (`Sources/Domain/`):
- **Models**: Pure data structures (structs/enums) with `public init()`
- **Protocols**: Service contracts and delegate patterns (all `public protocol`)
- Contains no implementation logic or external dependencies

**Data Layer** (`Sources/Data/Services/`):
- Service implementations as `public final class`
- Conforming to Domain protocols
- Handles external interactions (ReplayKit, networking, file system)

**Presentation Layer** (`Sources/Presentation/`):
- UIKit view controllers as `public final class`
- Hybrid WKWebView + HTML/JS interface with native bridge
- HTML generation in separate extensions (e.g., `QCBugReportViewController+HTML.swift`)

**Manager Layer** (`Sources/Manager/`):
- `QCBugPluginManager` - Singleton coordinator managing all services
- Internal implementation, not exposed via public API

**Entry Point** (`Sources/QCBugPlugin.swift`):
- Static convenience API delegating to `QCBugPluginManager.shared`
- All methods and properties must be `public`

### Key Architecture Patterns

**Protocol-First Design**: All major components implement protocols defined in `Domain/Protocols/`. When adding functionality:
1. Define protocol in `Domain/Protocols/` (mark `public`)
2. Implement service in `Data/Services/` (class is `public final`, methods are `public`)
3. Wire through `QCBugPluginManager`

**Native-Web Bridge**: `QCBugReportViewController` uses WKScriptMessageHandler:
- JavaScript → Native: `window.webkit.messageHandlers.bugReportHandler.postMessage(data)`
- Native handling: `userContentController(_:didReceive:)` routes messages
- HTML/JS stored in `Presentation/Resources/` and loaded at runtime

**Session Management**: `QCBugPluginManager` maintains session state:
- `sessionMediaAttachments`: Media files captured during session
- `sessionBugDescription/Priority/Category`: Form state preservation
- `sessionBugReportViewController`: Reusable VC instance
- Session persists across form open/close until explicitly cleared

**Threading Model**:
- Main Queue: All UI operations, delegate callbacks, notifications
- Background: Screen recording operations, API calls, file operations

## Development Commands

### Building
```bash
# Build the package
swift build

# Build for release
swift build -c release
```

### Testing
```bash
# Run all tests
swift test

# Run specific test
swift test --filter QCBugPluginTests.testConfigurationDoesNotCrash
```

### Package Resolution
```bash
# Update package dependencies
swift package update

# Reset package cache
swift package reset

# Generate Xcode project (for development)
swift package generate-xcodeproj
```

## SPM Public API Requirements

### Must Be Public

**Entry Points**:
- `QCBugPlugin` class - all static methods and properties
- `QCBugPluginManager.shared` (typed as `QCBugPluginProtocol`)

**All Protocols**:
- `QCBugPluginProtocol`, `ScreenRecordingProtocol`, `BugReportProtocol`, `ScreenCaptureProtocol`
- `GitLabAuthProtocol`, `GitLabAuthProviding`
- `QCBugPluginDelegate`, `QCBugReportViewControllerDelegate`

**All Models & Enums**:
- `BugReport`, `MediaAttachment`, `UserAction`
- `QCBugPluginConfig`, `GitLabAppConfig`
- `DeviceInfo`, `AppInfo`, `NetworkInfo`, `MemoryInfo`, `DiskSpaceInfo`
- `BugPriority`, `BugCategory`, `MediaType`
- `ScreenRecordingError`, `BugReportError`, `ScreenshotAnnotationError`
- All model initializers must have `public init()`

**Service Classes**:
- `ScreenRecordingService`, `BugReportAPIService`, `ScreenCaptureService`
- `GitLabAuthService`, `GitLabSessionStore`
- All protocol-conforming methods

**View Controllers**:
- `QCBugReportViewController`, `QCScreenshotAnnotationViewController`
- `QCFloatingButton`, `QCFloatingActionButtons`

### Should Be Internal/Private

- Private helper methods in services
- Internal state management properties
- HTML/CSS/JS generation internals (can be `internal` for testing)

## GitLab Integration

The framework supports GitLab webhook authentication via OAuth2/JWT:

**Configuration**:
```swift
let gitLabConfig = GitLabAppConfig(
    appId: "your-app-id",
    secret: "your-secret",
    signingKey: "your-signing-key",
    redirectURI: URL(string: "myapp://oauth/callback"),
    baseURL: URL(string: "https://gitlab.com")!,
    scopes: ["api"],
    project: "group/project"
)

let config = QCBugPluginConfig(
    webhookURL: "https://gitlab.com/api/v4/projects/:id/issues",
    gitLabAppConfig: gitLabConfig
)
```

**Authentication Flow**:
1. `GitLabAuthService` generates JWT tokens or handles OAuth flow
2. Tokens cached in `GitLabSessionStore` (persistent storage)
3. `BugReportAPIService` uses tokens for API authentication
4. Session can be invalidated via `QCBugPlugin.invalidateGitLabSession()`

## File Organization

When adding new features:

- **Domain/Models/**: Pure `public struct` data with `public init()` and no logic
- **Domain/Protocols/**: `public protocol` interfaces only
- **Manager/**: `public final class` or `final class` central coordination
- **Data/Services/**: `public final class` implementations with `internal` helpers
- **Presentation/**: `public final class` UI controllers with `private` UI logic

## Integration Patterns

### Basic Setup
```swift
// AppDelegate.swift
import QCBugPlugin

func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = RootViewController()
    window?.makeKeyAndVisible()

    if let window {
        let config = QCBugPluginConfig(
            webhookURL: "https://your-webhook.com/bugs",
            enableFloatingButton: true // Debug builds only
        )
        QCBugPlugin.configure(using: window, configuration: config)
    }

    return true
}
```

### Shake Gesture
```swift
override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    if motion == .motionShake {
        QCBugPlugin.presentBugReport()
    }
}
```

### Custom Data
```swift
QCBugPlugin.setCustomData([
    "userId": UserManager.current.id,
    "feature_flags": FeatureManager.enabledFlags
])
```

### Delegate Pattern
```swift
class AppDelegate: UIResponder, UIApplicationDelegate, QCBugPluginDelegate {
    func bugPluginDidSubmitReport(_ reportId: String) {
        print("Bug report submitted: \(reportId)")
    }

    func bugPluginDidFailToSubmitReport(_ error: Error) {
        print("Bug report failed: \(error)")
    }
}

// Set delegate after configuration
QCBugPlugin.setDelegate(appDelegate)
```

## Memory Management

- Screen recordings stored in temp directory
- Media files cleaned on submission or session clear
- Weak delegate references throughout
- `QCBugPluginManager.clearSession()` removes all media attachments

## Important Conventions

**Access Control**: This is an SPM library. Classes/protocols/structs/enums exposed to consumers must be `public`. Internal helpers should be `internal` or `private`.

**Error Handling**:
- Network errors mapped to specific enum cases in services
- ReplayKit permission/availability checks with user-friendly messages
- Graceful degradation when features unavailable

**Logging**: Console logs use emoji prefixes:
- ✅ Success operations
- ❌ Errors
- ⚠️ Warnings
- 🎥 Screen recording
- 📸 Screenshots
- 🐛 Debug info

**Version Info**: Framework version accessible via `QCBugPlugin.frameworkInfo`

## Testing Notes

- Minimal test coverage currently (only configuration test)
- Tests use `@testable import QCBugPlugin` to access internal APIs
- Tests require UIKit (iOS simulator/device)
- Consider adding tests for: protocol implementations, session management, media handling

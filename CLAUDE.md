# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QCBugPlugin is an iOS Swift Package Manager framework for comprehensive bug reporting with screen recording, screenshot annotation, crash detection, and GitLab webhook integration. It follows Clean Architecture with protocol-based design and a hybrid Native-Web UI pattern.

**Platform:** iOS 12.0+
**Language:** Swift 5.3+
**Build System:** Swift Package Manager (SPM)
**Dependencies:** None (uses native frameworks: ReplayKit, WebKit, UIKit, AVFoundation)

## Build & Test Commands

### Building
```bash
# Build for iOS simulator (recommended for development)
xcodebuild -scheme QCBugPlugin -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'

# Build using Swift Package Manager
swift build

# Note: `swift build` may fail with "no such module 'UIKit'" because it builds for macOS by default.
# Always use xcodebuild with an iOS destination for reliable builds.
```

### Testing
```bash
# Run all tests
xcodebuild test -scheme QCBugPlugin -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'

# List available tests
swift test list

# Run specific test
xcodebuild test -scheme QCBugPlugin -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' -only-testing:QCBugPluginTests/TestClassName/testMethodName
```

### Clean Build
```bash
# Clean SPM build artifacts
swift package clean

# Or clean with xcodebuild
xcodebuild clean -scheme QCBugPlugin
```

## Architecture

### Clean Architecture Layers

**Domain Layer** (`Sources/Domain/`)
- **Protocols**: Business logic interfaces (`QCBugPluginProtocol`, `ScreenRecordingProtocol`, `BugReportProtocol`, `GitLabAuthProtocol`, `CrashDetectionProtocol`)
- **Models**: Business entities (`BugReport`, `MediaAttachment`, `UserAction`, `QCBugPluginConfiguration`, `GitLabAppConfiguration`, `CrashReport`)

**Data Layer** (`Sources/Data/Services/`)
- Service implementations of domain protocols
- `ScreenRecordingService`: ReplayKit wrapper with ownership tracking
- `BugReportAPIService`: HTTP webhook submission with media compression
- `GitLabAuthService`: OAuth2 + JWT authentication
- `CrashDetectionService`: NSException/Signal handler crash monitoring
- `GitLabSessionStore`: UserDefaults-based session persistence

**Presentation Layer** (`Sources/Presentation/`)
- `QCBugReportViewController`: WKWebView-based form with Native-Web bridge
- `QCScreenshotAnnotationViewController`: Native screenshot annotation UI
- `QCFloatingActionButtons`: Draggable floating action buttons
- `QCCrashReportAlertController`: Crash report alert dialog

**Manager Layer** (`Sources/Manager/`)
- `QCBugPluginManager`: Singleton coordinator managing all services and session state

**Public API** (`Sources/QCBugPlugin.swift`)
- Static facade delegating to `QCBugPluginManager.shared`

### Key Architectural Patterns

**1. Facade Pattern**
- `QCBugPlugin` provides minimal public API that delegates to `QCBugPluginManager`
- Entry point: `Sources/QCBugPlugin.swift`

**2. Protocol-Based Dependency Injection**
```swift
// Services implement protocols from Domain layer
private var screenRecorder: ScreenRecordingProtocol?
private var bugReportService: BugReportProtocol?

// Injected during configuration
func configure(using window: UIWindow, configuration: QCBugPluginConfig) {
    self.screenRecorder = ScreenRecordingService()
    self.bugReportService = BugReportAPIService(...)
}
```

**3. Native-Web Bridge Pattern**
- `QCBugReportViewController` uses WKWebView with bidirectional JavaScript bridge
- JavaScript → Native: `WKScriptMessageHandler` handles messages (updateDescription, gitlabLogin, deleteMediaAttachment, etc.)
- Native → JavaScript: `evaluateJavaScript()` injects data (media attachments, form state, GitLab state)
- HTML template: `Sources/Presentation/Resources/bug_report.html`
- JavaScript logic: `Sources/Presentation/Resources/bug_report.js`

**4. Session Management**
- `QCBugPluginManager` maintains in-memory session state:
  - `sessionMediaAttachments`: Screenshots and recordings
  - `sessionBugDescription/Priority/Category`: Form state
  - `sessionBugReportViewController`: Reused view controller instance
- Media files stored in Documents directory
- Form state persists across dismissals/re-opens
- Clear session via floating button or API call

**5. Crash Detection Flow**
1. Install handlers on configure: `NSSetUncaughtExceptionHandler` + signal handlers (SIGABRT, SIGSEGV, etc.)
2. On crash: capture stack trace, write log to Documents, save metadata JSON
3. On next launch: `checkForPendingCrashReports()` presents alert
4. User chooses "Report" → auto-fills bug form with crash data
5. Crash log attached as media attachment

## SPM Public API Requirements

### What MUST Be Public
- **Entry Points**: `QCBugPlugin` class (all static methods), `QCBugPluginManager.shared`
- **All Protocols**: `QCBugPluginProtocol`, `ScreenRecordingProtocol`, `BugReportProtocol`, `GitLabAuthProtocol`, `CrashDetectionProtocol`, `QCBugPluginDelegate`
- **All Models & Enums**: `BugReport`, `UserAction`, `MediaAttachment`, `QCBugPluginConfig`, `GitLabAppConfig`, `CrashReport`, `BugPriority`, `BugCategory`, etc.
- **Model Initializers**: All `public init()` for external instantiation
- **Service Classes**: `ScreenRecordingService`, `BugReportAPIService`, `GitLabAuthService` (for extensibility)
- **View Controllers**: `QCBugReportViewController`, `QCFloatingActionButtons` (if exposed in API)

### What SHOULD Be Internal/Private
- Private helper methods in services
- Internal state management properties
- HTML/CSS/JS generation internals (can be `internal` for testing)

When adding features:
1. Define `public protocol` in `Domain/Protocols/` first
2. Implement `public final class` in `Data/Services/`
3. Wire through `QCBugPluginManager`
4. Expose via `QCBugPlugin` facade if needed

## Common Development Workflows

### Adding a New Service
1. Define protocol in `Sources/Domain/Protocols/YourServiceProtocol.swift`
2. Create model in `Sources/Domain/Models/` if needed
3. Implement service in `Sources/Data/Services/YourService.swift`
4. Inject in `QCBugPluginManager.configure()`
5. Add public API method to `QCBugPlugin` if needed
6. Mark protocol/classes as `public`, methods as `public`

### Modifying Bug Report Form
1. Update HTML: `Sources/Presentation/Resources/bug_report.html`
2. Update JavaScript: `Sources/Presentation/Resources/bug_report.js`
3. Add message handler case in `QCBugReportViewController.handleBugReportMessage()`
4. Add injection method for new data (e.g., `injectCustomField()`)

### Adding Custom Media Compression Logic
- Edit `BugReportAPIService.compressImage()` or `compressVideo()`
- Current limits: Images 320KB (JPEG + scaling), Videos 5MB (AVAssetExportSession presets)

### GitLab Integration Workflow
1. User taps "GitLab Login" → `requestGitLabAuthentication()`
2. `ASWebAuthenticationSession` OAuth2 code flow with state parameter
3. Server handles token exchange and JWT generation
4. Server redirects back with JWT and username in callback URL
5. iOS app receives and caches JWT via `GitLabSessionStore`
6. JWT injected in bug report submission headers

### GitLab OAuth Configuration

**IMPORTANT:** The server handles OAuth token exchange and JWT generation. The iOS app only receives and caches the JWT.

**iOS Configuration:**
```swift
let gitLabConfig = GitLabAppConfig(
    appId: "your_gitlab_app_id",
    secret: "your_gitlab_app_secret",
    scheme: "yourapp", // Used as OAuth state for CSRF protection
    redirectURI: URL(string: "yourapp://gitlab/callback")!,
    baseURL: URL(string: "https://gitlab.com")!,
    project: "namespace/project-name"
)
```

**Backend Server Requirements:**

The backend server must:
1. Handle the OAuth authorization callback from GitLab
2. Exchange the authorization code for an access token
3. Generate a JWT with the user's information
4. Redirect back to the iOS app with: `<redirectURI>?jwt=<token>&username=<username>`

**Example callback format:**
```
yourapp://gitlab/callback?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...&username=john.doe
```

**Important Notes:**
- iOS app no longer generates JWTs - this is handled server-side
- The server must handle the OAuth token exchange with GitLab
- The server generates the JWT and returns it via the callback URL
- iOS app simply caches the JWT and uses it for authenticated requests
- JWT expiration defaults to 31 days (configurable via `jwtExpiration` parameter)

## Key Files Reference

| File Path | Purpose |
|-----------|---------|
| `Sources/QCBugPlugin.swift` | Public API facade |
| `Sources/Manager/QCBugPluginManager.swift` | Singleton coordinator |
| `Sources/Domain/Models/QCBugPluginConfiguration.swift` | Framework configuration |
| `Sources/Domain/Models/BugReport.swift` | Bug report data structure |
| `Sources/Presentation/QCBugReportViewController.swift` | Native-Web bridge form |
| `Sources/Presentation/QCBugReportViewController+HTML.swift` | HTML template generation |
| `Sources/Data/Services/ScreenRecordingService.swift` | ReplayKit wrapper |
| `Sources/Data/Services/BugReportAPIService.swift` | HTTP submission + compression |
| `Sources/Data/Services/GitLabAuthService.swift` | OAuth2 + JWT authentication |
| `Sources/Data/Services/CrashDetectionService.swift` | Crash monitoring |
| `Sources/Presentation/QCFloatingActionButtons.swift` | Floating UI controls |

## Integration Example

```swift
import QCBugPlugin

// In AppDelegate
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = RootViewController()
    window?.makeKeyAndVisible()

    if let window {
        let config = QCBugPluginConfig(
            webhookURL: "https://your-webhook.com/bugs",
            enableFloatingButton: true
        )
        QCBugPlugin.configure(using: window, configuration: config)
    }

    return true
}

// Optional: Set delegate for lifecycle callbacks
QCBugPlugin.setDelegate(self) // Implement QCBugPluginDelegate

// Optional: Add custom data
QCBugPlugin.setCustomData([
    "userId": currentUserId,
    "environment": "production"
])
```

## Troubleshooting

**Build fails with "no such module 'UIKit'"**
- Cause: `swift build` builds for macOS by default
- Solution: Use `xcodebuild` with iOS destination instead

**Screen recording not working**
- Check `Info.plist` has `NSPhotoLibraryUsageDescription` and `NSMicrophoneUsageDescription`
- Verify `isScreenRecordingEnabled: true` in configuration
- Check if recording started externally (Control Center) - plugin tracks ownership

**WebView not loading bug report form**
- Verify `Sources/Presentation/Resources/` contains `bug_report.html` and `bug_report.js`
- Check `Package.swift` has `.process("Presentation/Resources")` in resources
- Verify WKWebView console logs in `QCBugReportViewController`

**Crash reports not detected**
- Ensure `configure()` called before any potential crash
- Check `Documents/QCBugPlugin/CrashReports/` for crash logs
- Verify `CrashDetectionService` initialized in `QCBugPluginManager`

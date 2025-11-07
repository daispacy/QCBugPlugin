# QCBugPlugin Framework - Architecture Analysis & Crash Detection Integration Guide

## Executive Summary

QCBugPlugin is a comprehensive iOS bug reporting framework built with Clean Architecture principles. It provides real-time screen recording, screenshot capture, user action tracking, and webhook-based bug report submission with GitLab integration.

**Framework Version:** 1.0.0  
**Target iOS:** iOS 12+  
**Architecture Pattern:** Clean Architecture (Domain/Data/Presentation)  
**State Management:** Singleton Manager Pattern  

---

## 1. Architecture Overview

### 1.1 Layer Structure

```
┌─────────────────────────────────────────┐
│   PRESENTATION LAYER                     │
│  (UI Components & ViewControllers)      │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────┴──────────────────────┐
│   MANAGER LAYER                         │
│  (QCBugPluginManager - Singleton)       │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────┴──────────────────────┐
│   DOMAIN LAYER                          │
│  (Business Logic & Protocols)           │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────┴──────────────────────┐
│   DATA LAYER                            │
│  (Services & API Integration)           │
└─────────────────────────────────────────┘
```

### 1.2 Key Principles

- **Dependency Injection:** Protocol-based abstractions for all services
- **Session Management:** Maintains media, form state, and user selections across presentations
- **Lifecycle Aware:** Responds to app background/foreground events
- **Thread Safe:** Uses dispatch queues for concurrent operations

---

## 2. Core Components Deep Dive

### 2.1 Entry Point: QCBugPlugin.swift
**Location:** `/Sources/QCBugPlugin.swift`

**Public API:**
```swift
- configure(using:configuration:)           // Initialize with window & config
- presentBugReport()                        // Show bug report UI
- setCustomData(_:)                         // Add custom metadata
- setScreenRecordingEnabled(_:)             // Toggle recording
- startScreenRecording(completion:)         // Manual recording start
- stopScreenRecording(completion:)          // Manual recording stop
- isScreenRecording                         // Recording state property
- setDelegate(_:)                           // Set lifecycle callbacks
```

**Framework Info:**
- Version: 1.0.0
- Build: 1
- Exposes through static API to QCBugPluginManager singleton

---

### 2.2 Manager: QCBugPluginManager (Singleton)
**Location:** `/Sources/Manager/QCBugPluginManager.swift`

**Responsibilities:**
- Window management and floating UI setup
- Service initialization and dependency injection
- Session state persistence (media, form data)
- Delegation and lifecycle event handling
- Media attachment lifecycle (capture, annotation, cleanup)
- GitLab session invalidation

**Key Properties:**
```swift
configuration: QCBugPluginConfig?           // Global config
hostWindow: UIWindow?                       // Target window for UI
sessionMediaAttachments: [MediaAttachment]  // Session media
sessionBugReportViewController: QCBugReportViewController?
sessionBugDescription: String               // Form state
sessionBugPriority: BugPriority
sessionBugCategory: BugCategory
sessionWebhookURL: String?                  // User override
sessionAssigneeUsername: String?            // GitLab assignment
sessionIssueNumber: Int?                    // External issue tracker
```

**Services Managed:**
- `screenRecorder: ScreenRecordingProtocol?`
- `screenCapture: ScreenCaptureProtocol?`
- `bugReportService: BugReportProtocol?`
- `gitLabAuthService: GitLabAuthProviding?`
- `floatingActionButtons: QCFloatingActionButtons?`

**Critical Methods:**
- `configure()` - Initializes all services based on config
- `presentBugReport()` - Creates/reuses BugReportViewController
- `captureScreenshot(completion:)` - Captures screen → annotation editor
- `stopScreenRecording(completion:)` - Creates MediaAttachment → auto-presents form
- `clearSession()` - Cleanup media files and reset state

**Delegation Chain:**
- Implements `QCFloatingActionButtonsDelegate`
- Implements `QCBugReportViewControllerDelegate`

---

### 2.3 Configuration System

#### QCBugPluginConfig (Domain Model)
**Location:** `/Sources/Domain/Models/QCBugPluginConfiguration.swift`

```swift
public struct QCBugPluginConfig {
    let webhookURL: String                      // Webhook endpoint
    let apiKey: String?                         // Optional API auth
    let customData: [String: Any]               // App-provided metadata
    let isScreenRecordingEnabled: Bool = true   // Feature toggle
    let enableFloatingButton: Bool = false      // Debug mode only
    let gitLabAppConfig: GitLabAppConfig?       // GitLab auth config
}
```

#### GitLabAppConfig
**Location:** `/Sources/Domain/Models/GitLabAppConfiguration.swift`

```swift
public struct GitLabAppConfig {
    let appId: String                           // OAuth app ID
    let secret: String                          // OAuth secret
    let baseURL: URL = "https://gitlab.com"     // GitLab instance
    let scopes: [String] = ["api"]              // OAuth scopes
    let audience: String?                       // JWT audience claim
    let jwtExpiration: TimeInterval = 300       // JWT TTL (5 min)
    let signingKey: String                      // HMAC-SHA256 key
    let redirectURI: URL?                       // OAuth callback
    let project: String?                        // Default GitLab project
}
```

---

## 3. Bug Reporting System

### 3.1 Bug Report Data Model
**Location:** `/Sources/Domain/Models/BugReport.swift`

```swift
struct BugReport {
    // Core Report
    let id: String                              // UUID
    let timestamp: Date
    let description: String                     // User input
    let priority: BugPriority                   // low/medium/high/critical
    let category: BugCategory                   // ui/functionality/crash/...
    
    // Context Data
    let userActions: [UserAction]              // Action history
    let deviceInfo: DeviceInfo                 // Device specs
    let appInfo: AppInfo                       // Bundle info
    let currentScreen: String?                 // Active screen
    let networkInfo: NetworkInfo?              // Connection type
    let memoryInfo: MemoryInfo?                // RAM usage
    
    // Media
    let mediaAttachments: [MediaAttachment]    // Screenshots + videos
    let screenshots: [String]                  // Deprecated
    let screenRecordingURL: String?            // Deprecated
    
    // Integration
    let customData: [String: String]           // App metadata
    let assigneeUsername: String?              // GitLab user
    let issueNumber: Int?                      // External issue
    let gitLabProject: String?                 // GitLab project path
    let gitLabCredentials: GitLabCredentials?  // Auth
    let whtype: String = "report_issue"        // Webhook type
}
```

**Important Enums:**
```swift
enum BugPriority: String, Codable, CaseIterable {
    case low = "low"              // #28a745 (green)
    case medium = "medium"        // #ffc107 (yellow)
    case high = "high"            // #fd7e14 (orange)
    case critical = "critical"    // #dc3545 (red)
}

enum BugCategory: String, Codable, CaseIterable {
    case ui = "ui"
    case functionality = "functionality"
    case performance = "performance"
    case crash = "crash"          // **FOR CRASH DETECTION**
    case data = "data"
    case network = "network"
    case security = "security"
    case other = "other"
}
```

### 3.2 Device & System Information

**DeviceInfo Structure:**
```swift
struct DeviceInfo {
    let deviceModel: String                     // e.g., "iPhone14,2"
    let systemName: String                      // "iOS"
    let systemVersion: String                   // e.g., "17.2.1"
    let screenSize: CGSize
    let screenScale: CGFloat
    let deviceOrientation: String              // portrait/landscape/etc
    let batteryLevel: Float                    // 0.0 - 1.0
    let batteryState: String                   // charging/unplugged/full
    let diskSpace: DiskSpaceInfo                // Free/total
    let locale: String                         // e.g., "en_US"
    let timezone: String                       // e.g., "America/New_York"
}

struct MemoryInfo {
    let usedMemory: Int64                       // Resident set size
    let availableMemory: Int64                  // Free memory
    // Uses mach kernel APIs for accuracy
}
```

---

## 4. Media Attachment System

### 4.1 MediaAttachment Structure
**Location:** `/Sources/Domain/Models/MediaAttachment.swift`

```swift
struct MediaAttachment: Codable {
    let type: MediaType                        // .screenshot or .screenRecording
    let fileURL: String                        // Local file path as string
    let fileName: String                       // Extracted from URL
    let timestamp: Date                        // When captured
    let fileSize: Int64?                       // File size in bytes
}

enum MediaType: String, Codable {
    case screenshot = "screenshot"              // MIME: image/png
    case screenRecording = "screen_recording"   // MIME: video/mp4
}
```

### 4.2 Attachment Processing Pipeline (BugReportAPIService)
**Location:** `/Sources/Data/Services/BugReportAPIService.swift`

#### Compression Limits:
```swift
Screenshots:
  - Max: 320 KB (JPEG)
  - Min dimensions: 60x60 pixels
  - Strategy: Compression ratio + scale-down

Video Recordings:
  - Max: 5 MB (MP4)
  - Min dimensions: 120x120 pixels
  - Presets: 640x480, 1280x720, 1920x1080
  - Strategy: Cascading export presets with fallback
```

#### Processing Flow:
1. **Screenshots:** `UIImage` → JPEG compression → Base64 encode
2. **Videos:** `AVURLAsset` → `AVAssetExportSession` → MP4 → Base64 encode
3. **Parallelization:** `DispatchGroup` for concurrent processing
4. **Error Handling:** Fallback to lower quality if size exceeded

---

## 5. Presentation Layer

### 5.1 Floating UI Components

#### QCFloatingActionButtons
**Location:** `/Sources/Presentation/QCFloatingActionButtons.swift`

**Features:**
- Expandable menu with 4 buttons:
  - 🎥 Record (toggle)
  - 📸 Screenshot
  - 📝 Bug Report Form
  - 🗑️ Clear Session
- Pan gesture to move around screen
- Snaps to nearest edge (left/right)
- Respects safe areas and keyboard
- Orientation & keyboard aware
- Emoji-based UI (iOS 12 compatible)

**Delegate Protocol:**
```swift
protocol QCFloatingActionButtonsDelegate {
    func floatingButtonsDidTapRecord()
    func floatingButtonsDidTapScreenshot()
    func floatingButtonsDidTapBugReport()
    func floatingButtonsDidTapClearSession()
}
```

**State Management:**
- `isExpanded: Bool` - Tracks menu state
- `keyboardHeight: CGFloat` - Adjusts for keyboard
- `lastLocation: CGPoint` - For pan gesture

#### QCFloatingButton (Legacy)
**Location:** `/Sources/Presentation/QCFloatingButton.swift`

Single floating button with drag capability. Used in older implementation.

### 5.2 Bug Report View Controller
**Location:** `/Sources/Presentation/QCBugReportViewController.swift`

**Architecture:**
- `UIViewController` with embedded `WKWebView`
- Web-to-native bridge using JavaScript message handlers
- Dual inheritance: HTML/JS UI + native attachment handling

**Key Responsibilities:**
- HTML/CSS/JS form rendering (`QCBugReportViewController+HTML.swift`)
- Media attachment display and management
- Form state validation
- GitLab credential injection into web context
- Session restoration on re-presentation

**Internal State:**
```swift
bugDescription: String
selectedPriority: BugPriority
selectedCategory: BugCategory
selectedAssigneeUsername: String?
issueNumber: Int?
webhookURL: String
gitLabProject: String?

mediaAttachments: [MediaAttachment]  // Displayed in web UI
isFetchingGitLabCredentials: Bool    // Auth state
didInjectGitLabCredentials: Bool     // Injection tracking
gitLabJWT: String?                   // Current auth token
gitLabUsername: String?              // Current user
```

**Delegate:**
```swift
protocol QCBugReportViewControllerDelegate: AnyObject {
    func bugReportViewController(_:didSubmitReport:)
    func bugReportViewControllerDidCancel(_:)
    func bugReportViewController(_:requestNativePreviewFor:)
}
```

### 5.3 Screenshot Annotation
**Location:** `/Sources/Presentation/QCScreenshotAnnotationViewController.swift`

Allows users to annotate screenshots before inclusion in bug report.

---

## 6. Data/API Layer

### 6.1 Bug Report API Service
**Location:** `/Sources/Data/Services/BugReportAPIService.swift`

**Protocol:**
```swift
protocol BugReportProtocol: AnyObject {
    func submitBugReport(_ report: BugReport, completion: @escaping (Result<String, BugReportError>) -> Void)
    func uploadFile(_ fileURL: URL, for reportId: String, completion: @escaping (Result<String, BugReportError>) -> Void)
}

enum BugReportError: LocalizedError {
    case invalidURL
    case invalidData
    case networkError(String)
    case serverError(Int, String)
    case fileUploadFailed(String)
    case authenticationFailed
}
```

**Request Structure:**
```swift
// BugReportPayload (submitted to webhook)
struct BugReportPayload: Encodable {
    let whtype: String = "report_issue"
    let report: ReportDTO
    let attachments: [AttachmentPayload]      // Inline base64
    let gitlab: GitLabPayload?
    let metadata: MetadataPayload?
}

// AttachmentPayload (inline in report)
struct AttachmentPayload: Encodable {
    let type: String                          // "screenshot" or "screen_recording"
    let fileName: String
    let mimeType: String
    let timestamp: String                     // ISO8601
    let size: Int                             // Bytes
    let width: Int?, height: Int?             // Images
    let duration: Double?                     // Videos (seconds)
    let data: String                          // Base64 encoded
}
```

**HTTP Details:**
- Method: POST
- Content-Type: application/json
- Auth: Bearer token (API key or JWT)
- User-Agent: "QCBugPlugin/1.0"
- Request ID header: UUID (tracing)
- Timeout: 30s per request, 60s per resource

**Error Handling:**
- Automatic retry on network errors
- Cascading video compression on size failure
- Image re-compression with quality + dimension adjustment
- Detailed logging at each step

### 6.2 GitLab Authentication Service
**Location:** `/Sources/Data/Services/GitLabAuthService.swift`

**Features:**
- OAuth 2.0 device flow
- JWT generation (HMAC-SHA256)
- Token caching with TTL
- ASWebAuthenticationSession for secure auth
- Username resolution from API

**Key Methods:**
```swift
func fetchAuthorization(completion:) -> Result<GitLabAuthorization, GitLabAuthError>
func authenticateInteractively(from:completion:)
func hasValidAuthorization() -> Bool
func clearCache()
```

**Cached Data (GitLabSessionStore):**
- Current JWT token
- Current username
- Token expiration time

### 6.3 Screen Recording Service
**Location:** `/Sources/Data/Services/ScreenRecordingService.swift`

**Implementation:**
- Uses ReplayKit framework
- Detects if recording already active externally
- File saved to app's Caches directory
- Automatic cleanup on app background

**Protocol:**
```swift
protocol ScreenRecordingProtocol: AnyObject {
    var isAvailable: Bool { get }
    var isRecording: Bool { get }
    var isRecordingOwnedByService: Bool { get }
    
    func startRecording(completion:)
    func stopRecording(completion:)
    func requestPermission(completion:)
}
```

### 6.4 Screen Capture Service
**Location:** `/Sources/Data/Services/ScreenCaptureService.swift`

**Implementation:**
- Uses `UIGraphicsImageRenderer` for pixel-perfect capture
- Support for full screen or specific view capture
- Saved as PNG to temp directory
- Auto-cleanup of old files

---

## 7. User Action Tracking

### 7.1 UserAction Model
**Location:** `/Sources/Domain/Models/UserAction.swift`

```swift
struct UserAction: Codable {
    let id: String                              // UUID
    let timestamp: Date
    let actionType: ActionType                  // enum
    let screenName: String                      // For context
    let viewControllerClass: String             // View controller name
    let elementInfo: ElementInfo?               // Button, field, etc.
    let coordinates: CGPoint?                   // Tap location
    let metadata: [String: String]?             // Custom data
}

enum ActionType: String, Codable, CaseIterable {
    case screenView, screenDisappear
    case buttonTap, textInput, textFieldTap
    case scroll, swipe, pinch, longPress
    case segmentedControlTap, switchToggle, sliderChange
    case alertAction
    case navigationBack, tabChange
    case modalPresent, modalDismiss
}

struct ElementInfo: Codable {
    let accessibilityIdentifier: String?
    let accessibilityLabel: String?
    let className: String
    let text: String?
    let tag: Int?
    let frame: CGRect?
}
```

---

## 8. Domain Protocols (Abstraction Layer)

### 8.1 Core Protocols

#### QCBugPluginDelegate (Public)
```swift
public protocol QCBugPluginDelegate: AnyObject {
    func bugPluginShouldPresentBugReport() -> Bool        // Guard
    func bugPluginDidSubmitReport(_ reportId: String)     // Success
    func bugPluginDidFailToSubmitReport(_ error: Error)   // Failure
    func bugPluginDidStartRecording()                      // Recording lifecycle
    func bugPlugin(didStopRecordingWith url: URL)
    func bugPluginDidFailRecording(_ error: Error)
    func bugPluginDidClearSession()                        // Session cleared
}
```

#### GitLabAuthProtocol
```swift
protocol GitLabAuthProviding: AnyObject {
    func fetchAuthorization(completion:) -> Result<GitLabAuthorization, GitLabAuthError>
    func clearCache()
    func hasValidAuthorization() -> Bool
    func authenticateInteractively(from presenter:completion:)
}

struct GitLabAuthorization {
    let authorizationHeader: String              // For HTTP requests
    let jwt: String                              // For payload
    let username: String?
    let project: String?
}

enum GitLabAuthError: LocalizedError {
    case invalidConfiguration
    case networkError(String)
    case invalidResponse
    case tokenGenerationFailed
    case jwtGenerationFailed(String)
    case userAuthenticationRequired
    case authenticationCancelled
}
```

---

## 9. File Organization

```
Sources/
├── QCBugPlugin.swift                    # Public API entry point
├── Manager/
│   └── QCBugPluginManager.swift         # Main coordinator (singleton)
├── Presentation/
│   ├── QCFloatingActionButtons.swift    # Expandable button menu
│   ├── QCFloatingButton.swift           # Legacy single button
│   ├── QCBugReportViewController.swift  # Main form view controller
│   ├── QCBugReportViewController+HTML.swift  # Web UI generation
│   └── QCScreenshotAnnotationViewController.swift  # Annotation editor
├── Domain/
│   ├── Models/
│   │   ├── BugReport.swift              # Core bug report + system info
│   │   ├── QCBugPluginConfiguration.swift
│   │   ├── GitLabAppConfiguration.swift
│   │   ├── MediaAttachment.swift         # Screenshots + videos
│   │   ├── UserAction.swift             # Action tracking
│   │   └── ScreenshotAnnotationError.swift
│   └── Protocols/
│       ├── QCBugPluginProtocol.swift    # Public delegate
│       ├── BugReportProtocol.swift      # API submission
│       ├── GitLabAuthProtocol.swift     # Auth abstraction
│       ├── ScreenRecordingProtocol.swift
│       └── ScreenCaptureProtocol.swift
└── Data/
    └── Services/
        ├── BugReportAPIService.swift     # Webhook POST + attachment compression
        ├── GitLabAuthService.swift       # OAuth + JWT generation
        ├── GitLabSessionStore.swift      # Token persistence
        ├── ScreenRecordingService.swift  # ReplayKit wrapper
        └── ScreenCaptureService.swift    # UIGraphics renderer
```

---

## 10. Crash Detection Integration Points

### 10.1 Strategic Integration Locations

The framework already has ideal integration points for crash detection:

#### A. BugReport Category System
```swift
enum BugCategory: String, Codable, CaseIterable {
    case crash = "crash"  // **EXISTING** - Just needs population
    // ...
}
```

**Current State:** Enum value exists but not automatically populated  
**Enhancement Opportunity:** Auto-detect crash conditions

#### B. BugReport Initialization
```swift
struct BugReport {
    init(
        description: String,
        priority: BugPriority,
        category: BugCategory,  // **AUTO-SET FROM CRASH DETECTOR**
        userActions: [UserAction],
        deviceInfo: DeviceInfo,
        appInfo: AppInfo,
        mediaAttachments: [MediaAttachment],
        memoryInfo: MemoryInfo?,  // **IMPORTANT FOR CRASHES**
        // ...
    )
}
```

**Key Fields for Crash Context:**
- `memoryInfo` - RAM usage at crash time
- `userActions` - Steps leading to crash
- `currentScreen` - Which screen crashed
- `deviceInfo` - Device state (battery, orientation, etc.)

#### C. Presentation Trigger
```swift
// Manager.presentBugReport() - Can be called from crash handler
QCBugPlugin.presentBugReport()  // Auto-shows form with pre-filled data
```

#### D. Custom Data Pipeline
```swift
QCBugPlugin.setCustomData([
    "crashType": "NSException",
    "exceptionName": "NSInvalidArgumentException",
    "exceptionReason": "...",
    "stackTrace": "..."
])
```

### 10.2 Recommended Crash Detection Architecture

**New Component: CrashDetectionService**
```swift
// Detect crashes from:
// - NSSetUncaughtExceptionHandler() hook
// - Signal handlers (SIGSEGV, SIGBUS, etc.)
// - Exception throwing in try-catch blocks
// - UIApplication.didFinishLaunchingWithOptions checks

// Store crash context:
// - Stack trace
// - Exception details
// - Current screen
// - Memory snapshot
// - Battery state
// - Network state

// On next app launch:
// - Detect crash file
// - Auto-populate BugReport.category = .crash
// - Pre-fill description from stack trace
// - Set priority = .high or .critical
// - Prompt user to submit or edit
```

### 10.3 Integration Points for Implementation

1. **AppDelegate Integration**
   ```swift
   func application(_ application: UIApplication, 
                    didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
       // Initialize crash detector
       CrashDetectionService.shared.setupHandlers()
       
       // Check for previous crashes
       if let previousCrash = CrashDetectionService.shared.loadPreviousCrash() {
           // Auto-prepare bug report
           QCBugPlugin.setCustomData(previousCrash.toDictionary())
       }
       
       // Continue with plugin config
       let config = QCBugPluginConfig(webhookURL: "...")
       QCBugPlugin.configure(using: window, configuration: config)
   }
   ```

2. **Error Catching in Try-Catch**
   ```swift
   do {
       // Risky operation
   } catch {
       CrashDetectionService.shared.recordException(
           error,
           context: "MethodName",
           metadata: ["key": "value"]
       )
       // Optionally auto-show form
       QCBugPlugin.presentBugReport()
   }
   ```

3. **Memory Warning Response**
   ```swift
   override func viewDidLoad() {
       super.viewDidLoad()
       NotificationCenter.default.addObserver(
           self,
           selector: #selector(handleMemoryWarning),
           name: UIApplication.didReceiveMemoryWarningNotification,
           object: nil
       )
   }
   
   @objc func handleMemoryWarning() {
       let memInfo = MemoryInfo()  // Already implemented!
       CrashDetectionService.shared.recordMemoryWarning(memInfo)
   }
   ```

---

## 11. Key Implementation Patterns

### 11.1 Session State Management
- Cached in `QCBugPluginManager` properties
- Persisted across form dismissals
- Restored when form re-presented
- Cleared only on explicit `.clearSession()`

### 11.2 Thread Safety
- Manager: Main thread operations
- API Service: Uses `DispatchQueue` for processing
- Media processing: Concurrent dispatch group
- GitLab auth: Concurrent state queue

### 11.3 Lifecycle Awareness
```
Configure (once)
  ↓
Present Bug Report (can repeat)
  ↓
Capture Screenshot/Record → Auto-add to session
  ↓
Submit Report (preserves session)
  ↓
Clear Session (explicit cleanup)
```

### 11.4 Error Recovery
- Network errors: Logged + returned to UI
- File errors: Cleanup + user notification
- Auth errors: Guide to interactive login
- Attachment errors: Skip + continue with smaller files

---

## 12. Data Flow Example: Screenshot to Submission

```
User taps "Screenshot" button
    ↓
QCFloatingActionButtons.screenshotButtonTapped()
    ↓
Manager.captureScreenshot(completion:)
    ↓
ScreenCaptureService.captureScreen()
    ↓
UIGraphicsImageRenderer → PNG file
    ↓
Manager.presentScreenshotAnnotationEditor()
    ↓
User annotates (optional)
    ↓
Manager.handleScreenshotAnnotationResult()
    ↓
Create MediaAttachment
    ↓
Add to sessionMediaAttachments[]
    ↓
Manager.presentBugReport()
    ↓
MediaAttachment appears in web UI
    ↓
User fills form + submits
    ↓
Manager.bugReportViewControllerDidSubmit()
    ↓
Build BugReport object (includes mediaAttachments[])
    ↓
BugReportAPIService.submitBugReport()
    ↓
Process attachments in parallel:
  - Screenshot: Compress JPEG → Base64
  - Video: AVAssetExport MP4 → Base64
    ↓
POST to webhook with inline attachments
    ↓
Return reportId (or generated UUID)
    ↓
Delegate callback: bugPluginDidSubmitReport(reportId)
```

---

## 13. Key Classes Reference

| File | Class | Purpose |
|------|-------|---------|
| QCBugPlugin.swift | `QCBugPlugin` | Public static API facade |
| QCBugPluginManager.swift | `QCBugPluginManager` | Core coordinator (singleton) |
| QCFloatingActionButtons.swift | `QCFloatingActionButtons` | Expandable FAB menu |
| QCBugReportViewController.swift | `QCBugReportViewController` | Form controller |
| BugReportAPIService.swift | `BugReportAPIService` | Webhook submission + compression |
| GitLabAuthService.swift | `GitLabAuthService` | OAuth + JWT |
| ScreenRecordingService.swift | `ScreenRecordingService` | ReplayKit wrapper |
| ScreenCaptureService.swift | `ScreenCaptureService` | Screenshot capture |
| BugReport.swift | `BugReport` | Core data model + SystemInfo |
| MediaAttachment.swift | `MediaAttachment` | File metadata |
| UserAction.swift | `UserAction` | Interaction tracking |

---

## 14. Critical Files for Crash Detection Implementation

**Must Read Before Implementation:**
1. ✅ `/Sources/Manager/QCBugPluginManager.swift` - Entry point for all operations
2. ✅ `/Sources/Domain/Models/BugReport.swift` - Data structure (add crash fields)
3. ✅ `/Sources/Domain/Models/QCBugPluginConfiguration.swift` - Config extension point
4. ✅ `/Sources/Data/Services/BugReportAPIService.swift` - API payload structure
5. ✅ `/Sources/Presentation/QCBugReportViewController.swift` - Form pre-population

**Nice to Have:**
- `/Sources/Domain/Models/UserAction.swift` - For action replay
- `/Sources/Data/Services/GitLabAuthService.swift` - For issue creation
- `/Sources/Presentation/QCFloatingActionButtons.swift` - For auto-trigger UI

---

## 15. Integration Checklist for Crash Detection

- [ ] Create `CrashDetectionService` protocol & implementation
- [ ] Add exception handlers in AppDelegate
- [ ] Implement crash file persistence
- [ ] Hook into `didFinishLaunchingWithOptions`
- [ ] Extend `BugReport` with crash-specific fields
- [ ] Extend `BugCategory.crash` detection
- [ ] Add memory monitoring
- [ ] Create signal handlers for C-level crashes
- [ ] Implement stack trace capture (NSException)
- [ ] Add UI flow for crash-initiated reports
- [ ] Test with intentional crashes
- [ ] Verify attachment inclusion
- [ ] Test webhook payload serialization
- [ ] Verify GitLab integration with crash data

---

## Summary

QCBugPlugin provides a **robust foundation** for crash detection integration:

✅ **Ready:** BugReport category system, DeviceInfo, MemoryInfo, UserAction tracking  
✅ **Extensible:** Protocol-based design allows new services  
✅ **Thread-safe:** Proper use of dispatch queues  
✅ **Proven:** Media compression, API submission, GitLab auth  

**Next Steps:** Create crash detection service layer and hook into app lifecycle.


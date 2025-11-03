# QCBugPlugin Framework Structure

## 📋 Overview

QCBugPlugin is a comprehensive iOS framework designed for QC bug reporting with automatic user interaction tracking, screen recording capabilities, and webhook integration. The framework follows Clean Architecture principles with clear separation of concerns and protocol-based design.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    QCBugPlugin Framework                     │
├─────────────────────────────────────────────────────────────┤
│  📱 Presentation Layer                                       │
│  ├── QCBugReportViewController (WKWebView + HTML/JS)       │
│  ├── QCFloatingButton (Debug UI)                           │
│  └── Native-Web Communication Bridge                        │
├─────────────────────────────────────────────────────────────┤
│  🧠 Manager Layer                                            │
│  └── QCBugPluginManager (Singleton Coordinator)            │
├─────────────────────────────────────────────────────────────┤
│  🔧 Data/Service Layer                                       │
│  ├── UITrackingService (Method Swizzling)                  │
│  ├── ScreenRecordingService (ReplayKit)                    │
│  └── BugReportAPIService (Webhook Integration)             │
├─────────────────────────────────────────────────────────────┤
│  🎯 Domain Layer                                             │
│  ├── Protocols (Interfaces)                                │
│  ├── Models (Data Structures)                              │
│  └── Configuration                                          │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Directory Structure

```
QCBugPlugin/
├── QCBugPlugin.h                              # Framework header
├── Info.plist                                # Framework metadata
├── README.md                                 # User documentation
├── STRUCTURE.md                              # This architecture document
└── Sources/
    ├── QCBugPlugin.swift                     # 🚪 Main entry point & convenience API
    ├── Domain/                               # 🎯 Business logic & abstractions
    │   ├── Protocols/
    │   │   ├── QCBugPluginProtocol.swift     # Main plugin interface
    │   │   ├── ScreenRecordingProtocol.swift # Screen recording abstraction
    │   │   ├── UITrackingProtocol.swift      # UI tracking abstraction
    │   │   └── BugReportProtocol.swift       # Bug submission abstraction
    │   └── Models/
    │       ├── UserAction.swift              # User interaction data model
    │       ├── BugReport.swift               # Complete bug report model
    │       └── QCBugPluginConfiguration.swift # Configuration & notifications
    ├── Manager/
    │   └── QCBugPluginManager.swift          # 🧠 Central coordinator & state manager
    ├── Data/
    │   └── Services/
    │       ├── UITrackingService.swift       # 👆 Method swizzling implementation
    │       ├── ScreenRecordingService.swift  # 🎥 ReplayKit wrapper
    │       └── BugReportAPIService.swift     # 🌐 Webhook communication
    └── Presentation/
        ├── QCBugReportViewController.swift   # 📱 Main bug report UI controller
        ├── QCBugReportViewController+HTML.swift # 🎨 HTML/CSS/JS generation
        └── QCFloatingButton.swift            # 🐛 Debug floating button
```

## 🎯 Domain Layer

### Protocols (Contracts)

#### `QCBugPluginProtocol`
- **Purpose**: Main interface for the entire plugin
- **Key Methods**:
  - `startTracking()` / `stopTracking()`
  - `presentBugReport()`
  - `configure(webhookURL:apiKey:)`
  - `setCustomData(_:)` / `setScreenRecordingEnabled(_:)`

#### `UITrackingProtocol`
- **Purpose**: Abstraction for user interaction tracking
- **Key Methods**:
  - `startTracking()` / `stopTracking()`
  - `getActionHistory()` / `clearActionHistory()`
- **Properties**: `isTracking`, `maxActionHistoryCount`

#### `ScreenRecordingProtocol`
- **Purpose**: Abstraction for screen recording functionality
- **Key Methods**:
  - `startRecording(completion:)` / `stopRecording(completion:)`
  - `requestPermission(completion:)`
- **Properties**: `isAvailable`, `isRecording`

#### `BugReportProtocol`
- **Purpose**: Abstraction for bug report submission
- **Key Methods**:
  - `submitBugReport(_:completion:)`
  - `uploadFile(_:for:completion:)`

### Models (Data Structures)

#### `UserAction`
```swift
struct UserAction: Codable {
    let id: String                    // Unique identifier
    let timestamp: Date               // When action occurred
    let actionType: ActionType        // Type of interaction
    let screenName: String            // Screen/view name
    let viewControllerClass: String   // VC class name
    let elementInfo: ElementInfo?     // UI element details
    let coordinates: CGPoint?         // Touch coordinates
    let metadata: [String: String]?   // Additional context
}
```

**Supported Action Types**:
- `screen_view` / `screen_disappear`
- `button_tap` / `textfield_tap`
- `text_input` / `scroll` / `swipe`
- `pinch` / `long_press`
- `segmented_control_tap` / `switch_toggle`
- `alert_action` / `navigation_back`
- `tab_change` / `modal_present` / `modal_dismiss`

#### `BugReport`
```swift
struct BugReport: Codable {
    let id: String                    // Unique report ID
    let timestamp: Date               // Report creation time
    let description: String           // User-provided description
    let priority: BugPriority         // Low/Medium/High/Critical
    let category: BugCategory         // UI/Functionality/Performance/etc.
    let userActions: [UserAction]     // Action history
    let deviceInfo: DeviceInfo        // Device specifications
    let appInfo: AppInfo             // App version info
    let screenshots: [String]         // Screenshot URLs
    let screenRecordingURL: String?   // Video recording URL
    let customData: [String: String]  // App-specific data
    let currentScreen: String?        // Current screen name
    let networkInfo: NetworkInfo?     // Network status
    let memoryInfo: MemoryInfo?       // Memory usage
}
```

#### `QCBugPluginConfig`
```swift
struct QCBugPluginConfig: QCBugPluginConfiguration {
    let webhookURL: String            // Webhook endpoint
    let apiKey: String?               // Optional API key
    let customData: [String: Any]     // Custom data to include
    let isScreenRecordingEnabled: Bool // Enable screen recording
    let maxActionHistoryCount: Int    // Max actions to track
    let enableFloatingButton: Bool    // Show debug button
}
```

## 🧠 Manager Layer

### `QCBugPluginManager`
**Role**: Central coordinator and singleton entry point

**Responsibilities**:
- 🔧 Configuration management
- 🎯 Service coordination (UITracking, ScreenRecording, BugReport)
- 📱 UI presentation orchestration
- 📡 Notification management
- 🔄 Lifecycle management

**Key Components**:
```swift
class QCBugPluginManager: QCBugPluginProtocol {
    // Dependencies
    private var uiTracker: UITrackingProtocol?
    private var screenRecorder: ScreenRecordingProtocol?
    private var bugReportService: BugReportProtocol?
    
    // State
    private var configuration: QCBugPluginConfig?
    private var isConfigured: Bool = false
    private var floatingButton: QCFloatingButton?
    
    // Delegation
    public weak var delegate: QCBugPluginDelegate?
}
```

## 🔧 Data/Service Layer

### `UITrackingService`
**Purpose**: Tracks user interactions using method swizzling

**Technical Implementation**:
- **Method Swizzling**: Runtime method replacement for UIViewController, UIButton, UITextField
- **Thread Safety**: Uses dedicated queue for action history management
- **Memory Management**: Configurable action history limit with automatic trimming

**Swizzled Methods**:
```swift
// UIViewController
viewDidAppear(_:) → qc_viewDidAppear(_:)
viewDidDisappear(_:) → qc_viewDidDisappear(_:)

// UIButton
sendAction(_:to:for:) → qc_sendAction(_:to:for:)

// UITextField
becomeFirstResponder() → qc_becomeFirstResponder()

// UITapGestureRecognizer
touchesBegan(_:with:) → qc_touchesBegan(_:with:)
```

### `ScreenRecordingService`
**Purpose**: Manages screen recording using ReplayKit framework

**Technical Implementation**:
- **ReplayKit Integration**: Wraps `RPScreenRecorder.shared()`
- **Permission Handling**: Automatic permission management
- **Video Processing**: Handles preview controller and video saving
- **File Management**: Temporary storage with cleanup utilities

**Recording Flow**:
1. Check availability (`RPScreenRecorder.shared().isAvailable`)
2. Start recording with callback
3. Handle preview controller presentation
4. Save video to documents directory
5. Return file URL for upload

### `BugReportAPIService`
**Purpose**: Handles webhook submission with multipart data

**Technical Implementation**:
- **Multipart Upload**: Creates form-data with JSON + video file
- **Error Handling**: Comprehensive error mapping and retry logic
- **Authentication**: Optional API key support
- **Progress Tracking**: Upload progress and status reporting

**HTTP Request Structure**:
```
POST /webhook-endpoint
Content-Type: multipart/form-data; boundary=...
Authorization: Bearer <api-key> (optional)

--boundary
Content-Disposition: form-data; name="bug_report"
Content-Type: application/json

{...bug report JSON...}

--boundary
Content-Disposition: form-data; name="screen_recording"; filename="recording.mp4"
Content-Type: video/mp4

<video binary data>
--boundary--
```

## 📱 Presentation Layer

### `QCBugReportViewController`
**Purpose**: Main bug report interface using WKWebView

**Architecture**:
- **Hybrid Approach**: Native UIViewController + HTML/JS interface
- **Bridge Communication**: WKScriptMessageHandler for JS→Native communication
- **Responsive Design**: Mobile-first CSS with iOS design language

**Communication Flow**:
```
JavaScript ←→ WKScriptMessageHandler ←→ Native Code
    ↓               ↓                      ↓
HTML Form    Message Routing         Data Processing
Updates   →  bugReportHandler    →   Form Validation
           →  recordingHandler    →   Recording Control
```

**Message Handlers**:
- `bugReportHandler`: Form updates (description, priority, category)
- `recordingHandler`: Recording controls (start/stop)

### `QCFloatingButton`
**Purpose**: Debug-only floating button for easy access

**Features**:
- **Draggable**: Pan gesture with edge snapping
- **Visual Feedback**: Scale animations and haptic feedback
- **Smart Positioning**: Respects safe areas and screen bounds
- **Debug Only**: Conditionally compiled for debug builds

## 🔄 Data Flow

### User Interaction Tracking Flow
```
User Action → Method Swizzling → UITrackingService → Action History → Timeline Display
     ↓              ↓                    ↓               ↓              ↓
Touch Button → qc_sendAction → addAction() → actionHistory → HTML Timeline
```

### Bug Report Submission Flow
```
User Input → JavaScript → Native Bridge → Data Collection → API Service → Webhook
    ↓           ↓            ↓              ↓               ↓             ↓
Form Data → postMessage → Handler → BugReport → Multipart → HTTP POST
```

### Screen Recording Flow
```
User Tap → JS Message → Native Handler → ReplayKit → Preview VC → File Save → Upload
   ↓          ↓            ↓              ↓           ↓           ↓         ↓
Record → startRecording → RPScreenRecorder → RPPreviewVC → Documents → Webhook
```

## 🔌 Integration Points

### With Host Application

#### Initialization
```swift
// AppDelegate.swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    #if DEBUG || STAGING
    QCBugPlugin.configure(
        webhookURL: "https://your-webhook.com/bugs",
        apiKey: "your-api-key"
    )
    QCBugPlugin.startTracking()
    #endif
    
    return true
}
```

#### Trigger Integration
```swift
// Any ViewController
override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    if motion == .motionShake {
        QCBugPlugin.presentBugReport()
    }
}
```

#### Notification Listening
```swift
NotificationCenter.default.addObserver(
    forName: .QCBugPluginDidSubmitReport,
    object: nil,
    queue: .main
) { notification in
    // Handle successful submission
}
```

### Custom Data Integration
```swift
// Set user context
QCBugPlugin.setCustomData([
    "userId": UserManager.current.id,
    "sessionId": SessionManager.current.sessionId,
    "environment": BuildConfiguration.environment,
    "feature_flags": FeatureManager.enabledFlags
])
```

## 🧪 Testing Strategy

### Unit Testing
- **Protocol Mocking**: Mock implementations for all protocols
- **Service Testing**: Isolated testing of each service
- **Model Testing**: Codable compliance and data integrity

### Integration Testing
- **End-to-End Flow**: Complete bug report submission
- **UI Testing**: WebView interaction and native bridge
- **Network Testing**: Webhook integration with mock servers

### Debug Features
- **Mock API Service**: `MockBugReportAPIService` for testing
- **Debug Logging**: Comprehensive console output
- **Framework Info**: Version and build information

## 📊 Performance Considerations

### Memory Management
- **Action History Limit**: Configurable with automatic trimming
- **Video Storage**: Temporary files with cleanup
- **Weak References**: Proper delegate and observer patterns

### CPU Impact
- **Method Swizzling**: Minimal overhead, only when tracking enabled
- **Background Queues**: Action processing on utility queue
- **Lazy Loading**: Services initialized only when needed

### Storage Impact
- **Temporary Files**: Screen recordings cleaned up after submission
- **Action History**: Limited by configuration (default: 50 actions)
- **Framework Size**: Optimized for minimal binary size

## 🔒 Security & Privacy

### Data Handling
- **Local Processing**: All data processed locally before submission
- **No Third-Party**: Direct webhook submission, no intermediary services
- **Configurable**: Optional screen recording and custom data

### Privacy Compliance
- **Opt-in Screen Recording**: User must explicitly enable
- **No Sensitive Data**: Only UI interactions tracked, not content
- **Custom Data Control**: App controls what additional data is included

### Network Security
- **HTTPS Support**: Webhook URLs should use HTTPS
- **API Key Support**: Optional authentication
- **Request Validation**: Proper error handling for network issues

## 🚀 Extensibility

### Adding New Action Types
1. Add case to `ActionType` enum
2. Implement swizzling for new UI component
3. Update HTML display logic
4. Add appropriate icon and description

### Custom UI Elements
1. Modify HTML/CSS in `QCBugReportViewController+HTML.swift`
2. Add corresponding JavaScript handlers
3. Update native message processing

### Additional Data Sources
1. Create new protocol in Domain layer
2. Implement service in Data layer
3. Integrate in `QCBugPluginManager`

## 📈 Future Enhancements

### Planned Features
- **Screenshot Capture**: Automatic screenshot on bug report
- **Crash Detection**: Integration with crash reporting
- **A/B Testing**: Different UI variations
- **Analytics**: Usage statistics and metrics

### Architecture Improvements
- **Dependency Injection**: Replace singletons with DI container
- **SwiftUI Support**: Native SwiftUI bug report interface
- **Combine Integration**: Replace callbacks with Combine publishers
- **Plugin Architecture**: Modular components for different features

---

*This structure document serves as a comprehensive guide for understanding, maintaining, and extending the QCBugPlugin framework.*
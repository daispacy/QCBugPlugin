# QCBugPlugin Framework

A comprehensive iOS framework for QC bug reporting with user interaction tracking, screen recording, and webhook integration.

## 🚀 Features

### Core Features
- **🎯 User Interaction Tracking**: Automatically tracks screen views, button taps, text input, and navigation
- **🎥 Screen Recording**: Native screen recording using ReplayKit framework
- **📸 Screenshot Capture**: Instant screen capture with auto-submit workflow
- **📱 Rich Bug Reports**: Detailed reports with device info, app info, and user action timeline
- **🌐 Webhook Integration**: Submit reports to any webhook endpoint with multipart data
- **🎨 Beautiful UI**: HTML/JS interface with native communication bridge
- **🔧 Easy Integration**: Simple API that works with any iOS app

### New in v1.1.0 ✨
- **🎯 Floating Action Buttons**: Multi-button interface with record, screenshot, and bug report actions
- **📸 One-Tap Screenshot**: Capture screen and auto-present bug report form
- **🎬 Smart Recording Workflow**: Start/stop recording with automatic form presentation
- **📦 Multi-File Attachments**: Support for multiple screenshots and recordings per report
- **🔄 Auto-Present Form**: Automatic bug report form after capture/recording completion
- **📤 Enhanced Webhook**: Multi-file upload with proper MIME types and field naming

## 📦 Installation

### Swift Package Manager (Recommended)

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/daispacy/QCBugPlugin.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter repository URL: `https://github.com/daispacy/QCBugPlugin.git`
3. Select version and add to your target

### Manual Integration

1. Add the `QCBugPlugin` folder to your Xcode project
2. Add the framework to your target's dependencies
3. Import the framework: `import QCBugPlugin`

### Requirements

- iOS 12.0+
- Swift 5.3+
- Xcode 12.0+

## 🔧 Quick Start

## 🚀 Quick Start

### Installation

Add QCBugPlugin to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/daispacy/QCBugPlugin.git", from: "1.0.0")
]
```

### Basic Setup

**IMPORTANT:** Swift no longer supports automatic `class func initialize()`. You must manually call setup methods.

**1. App-Level Setup (AppDelegate):**

```swift
import UIKit
#if DEBUG || STAGING
import QCBugPlugin
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        #if DEBUG || STAGING
        // Configure QCBugPlugin
        QCBugPlugin.configure(webhookURL: "https://your-webhook.com/bugs")
        QCBugPlugin.startTracking()
        #endif
        
        return true
    }
}
```

**2. Feature-Level Setup (ViewController):**

```swift
import UIKit
#if DEBUG || STAGING
import QCBugPlugin
#endif

class YourViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        #if DEBUG || STAGING
        setupQCBugReporting()  // Call from extension
        #endif
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        #if DEBUG || STAGING
        updateQCBugReportContext()  // Call from extension
        #endif
    }
}
```

See [Templates/](Templates/) for complete integration examples.

### Advanced Configuration

```swift
#if DEBUG || STAGING
let config = QCBugPluginConfig(
    webhookURL: "https://your-webhook-url.com/bugs",
    apiKey: "your-api-key",
    customData: [
        "app": "YourApp",
        "environment": "DEBUG",
        "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    ],
    isScreenRecordingEnabled: true,
    maxActionHistoryCount: 100,
    enableFloatingButton: true  // Enables new floating action buttons UI
)

QCBugPlugin.configure(with: config)
QCBugPlugin.startTracking()
#endif
```

## 🎯 Floating Action Buttons (New!)

The new floating action buttons provide a streamlined workflow for bug reporting:

### Features
- **🐛 Main Button**: Expands to reveal recording and screenshot options
- **🎥 Record Button**: Start/stop screen recording
- **📸 Screenshot Button**: Instant screen capture
- **Drag & Drop**: Reposition anywhere on screen
- **Auto-Snap**: Automatically snaps to screen edges
- **Smart Workflow**: Auto-presents bug report form after capture

### Usage

The floating buttons appear automatically when `enableFloatingButton: true`:

```swift
// 1. User taps main button (🐛)
//    → Expands to show record and screenshot buttons

// 2. User taps screenshot button (📸)
//    → Captures screen
//    → Saves to local storage
//    → Auto-presents bug report form with screenshot attached

// 3. User taps record button (🎥)
//    → First tap: Starts recording (button shows ⏹️)
//    → Second tap: Stops recording
//    → Auto-presents bug report form with video attached

// 4. User fills out form and submits
//    → All media files uploaded to webhook
```

### Programmatic Control

```swift
// Capture screenshot programmatically
QCBugPluginManager.shared.captureScreenshot { result in
    switch result {
    case .success(let url):
        print("Screenshot saved: \(url)")
        // Form auto-presents with screenshot
    case .failure(let error):
        print("Error: \(error)")
    }
}

// Control recording programmatically
QCBugPluginManager.shared.startScreenRecording { result in
    switch result {
    case .success:
        print("Recording started")
    case .failure(let error):
        print("Error: \(error)")
    }
}

QCBugPluginManager.shared.stopScreenRecording { result in
    switch result {
    case .success(let url):
        print("Recording saved: \(url)")
        // Form auto-presents with recording
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### Global Trigger (Shake Gesture)

```swift
// In AppDelegate or SceneDelegate
override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    if motion == .motionShake {
        QCBugPlugin.presentBugReport()
    }
}
```

## 🎯 Feature-Specific Integration (Manual Setup Pattern)

### Integration Philosophy

**Keep QCBugPlugin code separate!** Create extension files with setup methods that you call from your ViewControllers.

### ⚠️ Important: No Automatic Swizzling

**Swift no longer supports `class func initialize()`**, so automatic swizzling is not possible. You must:
1. Create a separate extension file with QCBugPlugin setup code
2. Manually call setup methods from your ViewController lifecycle methods
3. Use `#if DEBUG || STAGING` to conditionally compile

### 📁 Ready-to-Use Templates

We provide complete templates for manual integration. See the [`Templates/`](Templates/) folder:

- **`AppDelegate+QCBugPlugin.swift`** - App-level initialization with manual setup
- **`YourViewController+QCBugPlugin.swift`** - Per-feature screen tracking with lifecycle hooks
- **`YourViewModel+QCBugPlugin.swift`** - Business logic tracking (copy per ViewModel)

👉 **[See Templates README for detailed usage guide](Templates/README.md)**

### Quick Integration Steps

1. **Copy** the appropriate template from `Templates/` folder
2. **Rename** to match your class (e.g., `CheckoutViewController+QCBugPlugin.swift`)
3. **Replace** placeholder names with your actual class names
4. **Add method calls** to your original ViewController (3 lines with `#if DEBUG`)
5. **Customize** tracking data for your feature
6. **Build** in DEBUG or STAGING

**Minimal modifications to original code (only conditional method calls)!**

### Pattern: Extension-Based Integration

For each feature, create a separate file: `<FeatureViewController>+QCBugPlugin.swift`

#### Example: Manual Integration

**File:** `CheckoutViewController+QCBugPlugin.swift`

```swift
import UIKit
import QCBugPlugin

#if DEBUG || STAGING

extension CheckoutViewController {
    
    /// Call from viewDidLoad()
    func setupQCBugReporting() {
        // Add debug button
        let bugButton = UIBarButtonItem(title: "🐛", style: .plain, 
                                        target: self, action: #selector(showBugReport))
        navigationItem.rightBarButtonItem = bugButton
        
        // Set feature context
        QCBugPlugin.setCustomData([
            "feature": "Checkout",
            "screen": "CheckoutViewController"
        ])
    }
    
    /// Call from viewWillAppear(_:)
    func updateQCBugReportContext() {
        // Update dynamic data
        QCBugPlugin.setCustomData([
            "feature": "Checkout",
            "itemsInCart": cart.items.count,
            "totalAmount": cart.total
        ])
    }
    
    @objc private func showBugReport() {
        QCBugPlugin.presentBugReport()
    }
}

#endif
```

**In your original CheckoutViewController.swift:**

```swift
class CheckoutViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        #if DEBUG || STAGING
        setupQCBugReporting()  // Add this one line
        #endif
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        #if DEBUG || STAGING
        updateQCBugReportContext()  // Add this one line
        #endif
    }
}
```

**That's it!** Just two conditional method calls in your original code.

### Complete Templates

For comprehensive integration with all lifecycle hooks, data tracking, and best practices, use the templates in the [`Templates/`](Templates/) folder. Each template includes:

- ✅ Full method swizzling setup
- ✅ Multiple lifecycle hooks (viewDidLoad, viewWillAppear, etc.)
- ✅ Shake gesture handling
- ✅ Debug button integration
- ✅ Context data management
- ✅ Security guidelines and sanitization examples
- ✅ Detailed inline documentation

```swift
import UIKit
import QCBugPlugin

#if DEBUG || STAGING

extension InstallmentFeeViewController {
    
    // MARK: - QCBugPlugin Auto-Setup
    
    /// Automatically called when the class is first accessed
    static func setupQCBugPlugin() {
        swizzleViewDidLoad()
        swizzleViewWillAppear()
        swizzleMotionEnded()
    }
    
    // MARK: - Method Swizzling
    
    private static func swizzleViewDidLoad() {
        let originalSelector = #selector(viewDidLoad)
        let swizzledSelector = #selector(qcBugPlugin_viewDidLoad)
        
        guard let originalMethod = class_getInstanceMethod(self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    private static func swizzleViewWillAppear() {
        let originalSelector = #selector(viewWillAppear(_:))
        let swizzledSelector = #selector(qcBugPlugin_viewWillAppear(_:))
        
        guard let originalMethod = class_getInstanceMethod(self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    private static func swizzleMotionEnded() {
        let originalSelector = #selector(motionEnded(_:with:))
        let swizzledSelector = #selector(qcBugPlugin_motionEnded(_:with:))
        
        guard let originalMethod = class_getInstanceMethod(self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    // MARK: - Swizzled Methods
    
    @objc private func qcBugPlugin_viewDidLoad() {
        // Call original implementation
        qcBugPlugin_viewDidLoad() // This calls the original due to swizzling
        
        // Add QCBugPlugin setup
        setupBugReportButton()
        setupFeatureTracking()
    }
    
    @objc private func qcBugPlugin_viewWillAppear(_ animated: Bool) {
        // Call original implementation
        qcBugPlugin_viewWillAppear(animated)
        
        // Update custom data when view appears
        updateContextData()
    }
    
    @objc private func qcBugPlugin_motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        // Call original implementation if it exists
        qcBugPlugin_motionEnded(motion, with: event)
        
        // Handle shake gesture for bug reporting
        if motion == .motionShake {
            presentBugReportWithContext()
        }
    }
    
    // MARK: - QCBugPlugin Setup Methods
    
    private func setupBugReportButton() {
        let bugButton = UIBarButtonItem(
            title: "🐛",
            style: .plain,
            target: self,
            action: #selector(bugReportButtonTapped)
        )
        navigationItem.rightBarButtonItem = bugButton
    }
    
    @objc private func bugReportButtonTapped() {
        presentBugReportWithContext()
    }
    
    private func setupFeatureTracking() {
        QCBugPlugin.setCustomData([
            "feature": "InstallmentFeeCheck",
            "screen": "InstallmentFeeViewController",
            "screenTitle": title ?? "Unknown"
        ])
        
        print("🐛 QCBugPlugin configured for InstallmentFeeCheck feature")
    }
    
    private func updateContextData() {
        var contextData: [String: Any] = [
            "feature": "InstallmentFeeCheck",
            "screen": "InstallmentFeeViewController"
        ]
        
        // Add feature-specific data (example - adapt to your feature)
        // if let selectedBank = viewModel?.selectedBank {
        //     contextData["selectedBank"] = selectedBank.name
        //     contextData["selectedBankCode"] = selectedBank.code
        // }
        
        QCBugPlugin.setCustomData(contextData)
    }
    
    private func presentBugReportWithContext() {
        // Update context with latest data before presenting
        updateContextData()
        
        // Present bug report
        QCBugPlugin.presentBugReport()
    }
}

// MARK: - Auto-Initialize

extension InstallmentFeeViewController {
    /// Called automatically when class is first loaded
    @objc override open class func initialize() {
        super.initialize()
        
        // Ensure this runs only once
        struct Static {
            static var token: Int = 0
        }
        
        if self === InstallmentFeeViewController.self {
            setupQCBugPlugin()
        }
    }
}

#endif
```

### Pattern: ViewModel Extension

**File:** `InstallmentFeeViewModel+QCBugPlugin.swift`

```swift
import Foundation
import QCBugPlugin

#if DEBUG || STAGING

extension InstallmentFeeViewModel {
    
    // MARK: - Business Logic Tracking
    
    func trackFeeChargeRequest() {
        QCBugPlugin.setCustomData([
            "action": "FeeChargeRequest",
            "timestamp": Date().timeIntervalSince1970,
            "selectedBank": selectedBank?.code ?? "none",
            "amount": amountEntered ?? 0
        ])
    }
    
    func trackFeeChargeSuccess(fee: Decimal) {
        QCBugPlugin.setCustomData([
            "action": "FeeChargeSuccess",
            "feeAmount": NSDecimalNumber(decimal: fee).doubleValue,
            "success": true
        ])
    }
    
    func trackFeeChargeFailure(error: Error) {
        QCBugPlugin.setCustomData([
            "action": "FeeChargeFailure",
            "errorType": String(describing: type(of: error)),
            "errorMessage": error.localizedDescription,
            "success": false
        ])
    }
    
    func trackUserSelection(type: String, value: String) {
        QCBugPlugin.setCustomData([
            "action": "UserSelection",
            "selectionType": type,
            "selectedValue": value
        ])
    }
}

#endif
```

### Integration Rules

#### ✅ DO:
1. **Create separate extension files**: `<YourViewController>+QCBugPlugin.swift`
2. **Use method swizzling**: Hook into existing lifecycle methods without modifying original code
3. **Wrap in `#if DEBUG || STAGING`**: Keep bug reporting out of production builds
4. **Track feature-specific context**: Add meaningful custom data for each feature
5. **Provide multiple triggers**: Shake gesture, debug button, floating button
6. **Update context dynamically**: Refresh custom data in `viewWillAppear` or before presenting

#### ❌ DON'T:
1. **Modify existing feature code**: Never change original ViewController or ViewModel files
2. **Include in production**: Always use conditional compilation for DEBUG/STAGING only
3. **Track sensitive data**: Sanitize or exclude passwords, card numbers, PINs
4. **Block main thread**: Keep tracking operations lightweight
5. **Forget to call original**: Always call the original method in swizzled implementations

### Swizzling Template

For any ViewController that needs integration:

```swift
import UIKit
import QCBugPlugin
import ObjectiveC

#if DEBUG || STAGING

extension YourViewController {
    
    private static let swizzling: Void = {
        let originalSelector = #selector(viewDidLoad)
        let swizzledSelector = #selector(qc_viewDidLoad)
        
        guard let originalMethod = class_getInstanceMethod(YourViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(YourViewController.self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()
    
    @objc private func qc_viewDidLoad() {
        qc_viewDidLoad() // Calls original due to swizzling
        
        // Your QCBugPlugin setup here
        setupQCBugReporting()
    }
    
    private func setupQCBugReporting() {
        // Add debug button
        let bugButton = UIBarButtonItem(title: "🐛", style: .plain, target: self, action: #selector(showBugReport))
        navigationItem.rightBarButtonItem = bugButton
        
        // Set feature context
        QCBugPlugin.setCustomData([
            "feature": "YourFeatureName",
            "screen": String(describing: type(of: self))
        ])
    }
    
    @objc private func showBugReport() {
        QCBugPlugin.presentBugReport()
    }
    
    // Auto-trigger swizzling when class loads
    public override class func initialize() {
        guard self === YourViewController.self else { return }
        _ = swizzling
    }
}

#endif
```

### Available Swizzling Points

The framework provides automatic swizzling for:
- `viewDidAppear(_:)` - Screen tracking
- `viewDidDisappear(_:)` - Screen exit tracking  
- `sendAction(_:to:for:)` - Button tap tracking (UIButton)
- `becomeFirstResponder()` - TextField focus tracking

You can add custom swizzling for:
- `viewDidLoad` - Initial setup
- `viewWillAppear(_:)` - Context updates
- `viewWillDisappear(_:)` - Cleanup
- Custom methods - Feature-specific tracking

### Security & Privacy

#### Data Sanitization Example:

```swift
private func collectFormData() -> [String: Any] {
    var data: [String: Any] = [:]
    
    // ✅ Safe: Presence flags
    data["hasCardPrefix"] = !cardPrefixTextField.text.isEmpty
    data["hasAmount"] = amountTextField.text != nil
    
    // ✅ Safe: Non-sensitive selections
    data["selectedBank"] = selectedBank?.name
    data["selectedPeriod"] = selectedPeriod
    
    // ❌ DON'T: Never track actual sensitive values
    // data["cardNumber"] = cardNumberTextField.text  // WRONG!
    // data["pin"] = pinTextField.text                 // WRONG!
    
    return data
}
```

### Testing Your Integration

```swift
#if DEBUG
// In your ViewController or AppDelegate
func testQCBugPluginIntegration() {
    // Verify tracking is active
    print("Tracking enabled: \(QCBugPlugin.isTrackingEnabled)")
    
    // Check framework info
    print("Framework: \(QCBugPlugin.frameworkInfo)")
    
    // Manually trigger bug report
    QCBugPlugin.presentBugReport()
}
#endif
```

## 🎯 Debug Mode

Enable debug mode with floating button (Debug builds only):

```swift
#if DEBUG
QCBugPlugin.enableDebugMode()
#endif
```

## 📡 Webhook Format

The plugin sends bug reports as multipart form data with the following structure:

### HTTP Request
```
POST /your-webhook-endpoint
Content-Type: multipart/form-data; boundary=Boundary-...
Authorization: Bearer your-api-key
```

### JSON Data (bug_report field)
```json
{
  "id": "uuid",
  "timestamp": "2025-11-04T10:30:00Z",
  "description": "User description of the bug",
  "priority": "medium",
  "category": "ui",
  "userActions": [
    {
      "id": "action-uuid",
      "timestamp": "2025-11-04T10:29:45Z",
      "actionType": "button_tap",
      "screenName": "Home Screen",
      "viewControllerClass": "HomeViewController",
      "elementInfo": {
        "className": "UIButton",
        "text": "Login",
        "accessibilityLabel": "Login Button"
      },
      "coordinates": {"x": 150, "y": 300}
    }
  ],
  "deviceInfo": {
    "deviceModel": "iPhone14,2",
    "systemName": "iOS",
    "systemVersion": "17.0",
    "screenSize": {"width": 390, "height": 844}
  },
  "appInfo": {
    "bundleIdentifier": "com.example.app",
    "version": "1.0.0",
    "buildNumber": "123"
  },
  "mediaAttachments": [
    {
      "type": "screenshot",
      "fileURL": "file:///.../qc_screenshot_1699012345.png",
      "fileName": "qc_screenshot_1699012345.png",
      "timestamp": "2025-11-04T10:30:00Z",
      "fileSize": 524288
    },
    {
      "type": "screen_recording",
      "fileURL": "file:///.../qc_screen_recording_1699012350.mp4",
      "fileName": "qc_screen_recording_1699012350.mp4",
      "timestamp": "2025-11-04T10:30:05Z",
      "fileSize": 2097152
    }
  ],
  "customData": {
    "userId": "12345",
    "environment": "staging"
  }
}
```

### Multipart Form Data Structure (New!)

The complete multipart payload includes:

```
--Boundary-...
Content-Disposition: form-data; name="bug_report"
Content-Type: application/json

{...JSON data above...}
--Boundary-...
Content-Disposition: form-data; name="screenshot_0"; filename="qc_screenshot_1699012345.png"
Content-Type: image/png

[PNG binary data]
--Boundary-...
Content-Disposition: form-data; name="screenshot_1"; filename="qc_screenshot_1699012346.png"
Content-Type: image/png

[PNG binary data]
--Boundary-...
Content-Disposition: form-data; name="screen_recording"; filename="qc_screen_recording_1699012350.mp4"
Content-Type: video/mp4

[MP4 binary data]
--Boundary-...--
```

### Media File Details

#### Screenshots
- **Field Name**: `screenshot_0`, `screenshot_1`, etc. (indexed)
- **Format**: PNG
- **MIME Type**: `image/png`
- **Naming**: `qc_screenshot_{timestamp}.png`
- **Location**: Documents directory

#### Screen Recordings
- **Field Name**: `screen_recording`
- **Format**: MP4
- **Codec**: H.264
- **MIME Type**: `video/mp4`
- **Naming**: `qc_screen_recording_{timestamp}.mp4`
- **Location**: Documents directory
- **⚠️ Device Only**: Screen recording only works on physical devices (iOS limitation)

## 🔄 Lifecycle Events

Listen for plugin events:

```swift
NotificationCenter.default.addObserver(
    forName: .QCBugPluginDidStartTracking,
    object: nil,
    queue: .main
) { notification in
    print("Started tracking user interactions")
}

NotificationCenter.default.addObserver(
    forName: .QCBugPluginDidSubmitReport,
    object: nil,
    queue: .main
) { notification in
    if let reportId = notification.userInfo?["reportId"] as? String {
        print("Bug report submitted: \(reportId)")
    }
}
```

## 🎨 UI Customization

The bug report interface is built with HTML/JS and can be customized by modifying the `QCBugReportViewController+HTML.swift` file.

### Key Components:
- **Bug Description**: Text area for user input
- **Priority Selection**: Low, Medium, High, Critical
- **Category Selection**: UI, Functionality, Performance, Crash, etc.
- **Screen Recording Controls**: Start/Stop recording
- **User Actions Timeline**: Chronological list of tracked actions
- **System Information**: Device and app details

## 🔒 Privacy & Permissions

### Required Permissions:
- **Screen Recording**: ReplayKit handles permissions automatically
- **Network**: For webhook submissions

### Privacy Considerations:
- Only tracks UI interactions, not sensitive data
- Screen recordings are stored temporarily and can be deleted
- All data is sent to your specified webhook endpoint
- No data is sent to third parties

## 🧪 Testing

### Mock API Service
For testing without a real webhook:

```swift
let mockService = MockBugReportAPIService()
mockService.shouldSucceed = true
mockService.mockReportId = "test-report-123"
```

### Debug Information

```swift
#if DEBUG
QCBugPlugin.printInfo()
#endif
```

## 📋 Requirements

- iOS 12.0+
- Swift 5.3+
- Xcode 12.0+
- Required Frameworks: ReplayKit, WebKit, AVFoundation (automatically linked via SPM)
- **Physical iOS Device** required for screen recording feature (simulator not supported)

## 🤝 Integration Examples

### Example 1: E-commerce Checkout Flow

```swift
// CheckoutViewController+QCBugPlugin.swift
#if DEBUG || STAGING
extension CheckoutViewController {
    private func setupQCBugReporting() {
        QCBugPlugin.setCustomData([
            "feature": "Checkout",
            "cartItems": cartItemCount,
            "totalAmount": orderTotal,
            "paymentMethod": selectedPaymentMethod?.name ?? "none"
        ])
    }
}
#endif
```

### Example 2: User Profile Feature

```swift
// ProfileViewController+QCBugPlugin.swift
#if DEBUG || STAGING
extension ProfileViewController {
    private func updateBugReportContext() {
        QCBugPlugin.setCustomData([
            "feature": "UserProfile",
            "userId": user?.id ?? "guest",
            "isVerified": user?.isVerified ?? false,
            "lastUpdate": user?.lastModified
        ])
    }
}
#endif
```

## 📝 Best Practices

1. **Conditional Compilation**: Always wrap QCBugPlugin code in `#if DEBUG || STAGING`
2. **Extension Pattern**: Use separate `+QCBugPlugin.swift` files for each feature
3. **Method Swizzling**: Hook into lifecycle methods without modifying original code
4. **Context Tracking**: Update custom data in `viewWillAppear` for accuracy
5. **Data Sanitization**: Never track passwords, PINs, or full card numbers
6. **Multiple Triggers**: Provide shake gesture, debug button, and floating button options
7. **Test Integration**: Verify data collection before deploying to QC team
8. **Physical Device Testing**: Always test screen recording on physical devices, not simulator
9. **Webhook Validation**: Verify your webhook can handle multipart/form-data with files
10. **Media Cleanup**: Old screenshots and recordings are auto-cleaned on app launch

## 📚 Documentation & Resources

- **[Integration Templates](Templates/)** - Ready-to-use templates for non-intrusive integration
- **[Integration Checklist](INTEGRATION_CHECKLIST.md)** - Complete checklist for proper integration
- **[Sample Implementation](SAMPLE_IMPLEMENT.md)** - Real-world integration example
- **[Architecture Guide](STRUCTURE.md)** - Framework architecture and design patterns
- **[Public API Reference](SPM_PUBLIC_API.md)** - Complete SPM public API documentation
- **[Features Update](docs/FEATURES_UPDATE.md)** - New floating buttons and media attachments guide
- **[Copilot Instructions](.github/copilot-instructions.md)** - AI assistant guidelines

## 🎬 New Features Quick Reference

### Floating Action Buttons
| Button | Icon | Action | Result |
|--------|------|--------|--------|
| Main | 🐛 | Tap to expand | Shows record & screenshot buttons |
| Record | 🎥/⏹️ | Start/Stop recording | Auto-presents form with video |
| Screenshot | 📸 | Capture screen | Auto-presents form with image |

### File Organization
```
Documents/
├── qc_screenshot_1699012345.png       # Screenshot files
├── qc_screenshot_1699012346.png
└── qc_screen_recording_1699012350.mp4 # Recording files
```

### Webhook Field Names
```
bug_report          → JSON data with mediaAttachments array
screenshot_0        → First screenshot (PNG)
screenshot_1        → Second screenshot (PNG)
screenshot_N        → Nth screenshot (PNG)
screen_recording    → Screen recording (MP4)
```

## 🧪 Testing

### Important: Simulator vs Physical Device

#### ✅ Works on Simulator
- Screenshot capture
- Bug report form
- Webhook submission
- User interaction tracking

#### ⚠️ Physical Device Required
- **Screen Recording** - iOS limitation, ReplayKit not available on simulator
- Full floating button workflow testing

### Debug Information

```swift
#if DEBUG
// Print framework info
print(QCBugPlugin.frameworkInfo)

// Check tracking status
print("Tracking: \(QCBugPluginManager.shared.isTrackingEnabled())")

// Check recording availability
print("Recording available: \(QCBugPluginManager.shared.screenRecorder?.isAvailable ?? false)")

// Test screenshot capture
QCBugPluginManager.shared.captureScreenshot { result in
    print("Screenshot result: \(result)")
}

// Test bug report presentation
QCBugPluginManager.shared.presentBugReport()
#endif
```

### Testing Workflow

1. **On Simulator** (Development)
   ```swift
   // Test screenshot capture
   QCBugPluginManager.shared.captureScreenshot { result in
       // Verify form auto-presents
       // Check screenshot attachment
   }
   ```

2. **On Physical Device** (Full Testing)
   ```swift
   // Test recording workflow
   QCBugPluginManager.shared.startScreenRecording { _ in }
   // ... perform actions ...
   QCBugPluginManager.shared.stopScreenRecording { result in
       // Verify form auto-presents
       // Check recording attachment
   }
   ```

### Mock Webhook for Testing

Use services like:
- webhook.site
- requestbin.com
- httpbin.org/post
- Your local development server

Example webhook URL format:
```
https://webhook.site/your-unique-id
```

### Verifying Webhook Payload

Check that your webhook receives:
- ✅ `bug_report` field with JSON data
- ✅ `screenshot_0`, `screenshot_1`, etc. with PNG files
- ✅ `screen_recording` field with MP4 file
- ✅ Proper `Content-Type` headers for each part
- ✅ Correct file sizes and MIME types

## 📝 License

This framework is available for internal use within your organization.

## 🐛 Issues & Support

For issues and feature requests, please contact the development team or create an issue in your internal repository.

---

**Made with ❤️ for better QC processes**
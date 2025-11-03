# QCBugPlugin Framework

A comprehensive iOS framework for QC bug reporting with user interaction tracking, screen recording, and webhook integration.

## 🚀 Features

- **🎯 User Interaction Tracking**: Automatically tracks screen views, button taps, text input, and navigation
- **🎥 Screen Recording**: Native screen recording using ReplayKit framework
- **📱 Rich Bug Reports**: Detailed reports with device info, app info, and user action timeline
- **🌐 Webhook Integration**: Submit reports to any webhook endpoint with multipart data
- **🎨 Beautiful UI**: HTML/JS interface with native communication bridge
- **🔧 Easy Integration**: Simple API that works with any iOS app
- **🐛 Debug Mode**: Floating button for easy access during testing

## 📦 Installation

### Manual Integration

1. Add the `QCBugPlugin` folder to your Xcode project
2. Add the framework to your target's dependencies
3. Import the framework: `import QCBugPlugin`

### Xcode Project Setup

1. Add QCBugPlugin as a framework target in your existing project
2. Link the framework to your app target
3. Make sure to add required frameworks: `ReplayKit`, `WebKit`

## 🔧 Quick Start

### Basic Setup

```swift
import QCBugPlugin

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Configure the plugin
        QCBugPlugin.configure(webhookURL: "https://your-webhook-url.com/bugs")
        
        // Start tracking user interactions
        QCBugPlugin.startTracking()
        
        return true
    }
}
```

### Trigger Bug Report

```swift
// Option 1: Shake gesture
override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    if motion == .motionShake {
        QCBugPlugin.presentBugReport()
    }
}

// Option 2: Button action
@IBAction func reportBugTapped(_ sender: UIButton) {
    QCBugPlugin.presentBugReport()
}
```

## ⚙️ Advanced Configuration

```swift
let config = QCBugPluginConfig(
    webhookURL: "https://your-webhook-url.com/bugs",
    apiKey: "your-api-key",
    customData: [
        "userId": "12345",
        "environment": "staging",
        "version": "1.2.0"
    ],
    isScreenRecordingEnabled: true,
    maxActionHistoryCount: 100,
    enableFloatingButton: true // Debug builds only
)

QCBugPlugin.configure(with: config)
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

### JSON Data (bug_report field)
```json
{
  "id": "uuid",
  "timestamp": "2025-11-03T10:30:00Z",
  "description": "User description of the bug",
  "priority": "medium",
  "category": "ui",
  "userActions": [
    {
      "id": "action-uuid",
      "timestamp": "2025-11-03T10:29:45Z",
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
  "customData": {
    "userId": "12345",
    "environment": "staging"
  }
}
```

### Video File (screen_recording field)
- Format: MP4
- Codec: H.264
- Only included if screen recording was enabled and used

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
- Xcode 12.0+
- Swift 5.0+

## 🤝 Integration with Other Apps

This framework is designed to be easily portable between iOS apps:

1. Copy the `QCBugPlugin` framework
2. Configure with your webhook URL
3. Start tracking
4. Integrate trigger mechanism (shake, button, etc.)

## 📝 License

This framework is available for internal use within your organization.

## 🐛 Issues & Support

For issues and feature requests, please contact the development team or create an issue in your internal repository.

---

**Made with ❤️ for better QC processes**
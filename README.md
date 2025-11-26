# QCBugPlugin

A comprehensive iOS bug reporting framework with screen recording, screenshot annotation, and GitLab webhook integration.

[![Swift Version](https://img.shields.io/badge/Swift-5.3+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2012.0+-lightgrey.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![SPM Compatible](https://img.shields.io/badge/SPM-Compatible-brightgreen.svg)](https://swift.org/package-manager/)

## Features

- 📱 **Screen Recording** - Native screen recording using ReplayKit framework
- 📸 **Screenshot Capture** - Screenshot capture with annotation tools
- 🎨 **Rich Bug Reports** - Detailed reports including device info, app info, and user actions
- 🔐 **GitLab Integration** - Direct submission to GitLab issues via webhooks with OAuth2/JWT authentication
- 🎯 **Floating Action Buttons** - Convenient floating UI for debug builds
- 💾 **Session Management** - Persistent session state across form interactions
- 🏗️ **Clean Architecture** - Protocol-based design following Clean Architecture principles
- 🔧 **Easy Integration** - Simple API that works with any iOS app

## Installation

### Swift Package Manager

Add QCBugPlugin to your project using Swift Package Manager:

1. In Xcode, select **File > Add Packages...**
2. Enter the repository URL: `https://github.com/yourusername/QCBugPlugin.git`
3. Select the version you want to use

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/QCBugPlugin.git", from: "1.0.0")
]
```

## Quick Start

### Basic Setup

Configure QCBugPlugin in your `AppDelegate`:

```swift
import QCBugPlugin

func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = RootViewController()
    window?.makeKeyAndVisible()

    // Configure QCBugPlugin
    if let window {
        let config = QCBugPluginConfig(
            webhookURL: "https://your-webhook-url.com/bugs",
            enableFloatingButton: true // Shows floating action buttons
        )
        QCBugPlugin.configure(using: window, configuration: config)
    }

    return true
}
```

### Triggering Bug Reports

#### Option 1: Shake Gesture

```swift
override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    if motion == .motionShake {
        QCBugPlugin.presentBugReport()
    }
}
```

#### Option 2: Button Action

```swift
@IBAction func reportBugTapped(_ sender: UIButton) {
    QCBugPlugin.presentBugReport()
}
```

#### Option 3: Floating Action Buttons

Enable floating action buttons in your configuration:

```swift
let config = QCBugPluginConfig(
    webhookURL: "https://your-webhook-url.com/bugs",
    enableFloatingButton: true // Shows floating buttons for recording, screenshots, and bug reports
)
```

## Configuration Options

### Basic Configuration

```swift
let config = QCBugPluginConfig(
    webhookURL: "https://your-webhook-url.com/bugs",
    apiKey: "your-api-key", // Optional
    customData: ["environment": "staging"], // Optional
    isScreenRecordingEnabled: true, // Default: true
    enableFloatingButton: false // Default: false
)

QCBugPlugin.configure(using: window, configuration: config)
```

### GitLab Integration

QCBugPlugin supports direct submission to GitLab issues:

```swift
let gitLabConfig = GitLabAppConfig(
    appId: "your-gitlab-app-id",
    secret: "your-gitlab-secret",
    scheme: "myapp",
    redirectURI: URL(string: "myapp://oauth/callback")!,
    baseURL: URL(string: "https://gitlab.com")!,
    scopes: ["api"],
    project: "group/project-name"
)

let config = QCBugPluginConfig(
    webhookURL: "https://gitlab.com/api/v4/projects/:id/issues",
    gitLabAppConfig: gitLabConfig
)

QCBugPlugin.configure(using: window, configuration: config)
```

**Important:** When using GitLab integration, you must register the custom URL scheme in your app's `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.yourapp.oauth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>myapp</string>
        </array>
    </dict>
</array>
```

Replace `myapp` with the same scheme you used in `GitLabAppConfig`. This allows the OAuth callback to return to your app after authentication.

## Advanced Usage

### Adding Custom Data

```swift
// Add custom metadata to bug reports
QCBugPlugin.setCustomData([
    "userId": UserManager.current.id,
    "sessionId": SessionManager.sessionId,
    "feature_flags": FeatureManager.enabledFlags
])
```

### Screen Recording Control

```swift
// Start recording
QCBugPlugin.startScreenRecording { result in
    switch result {
    case .success:
        print("Recording started")
    case .failure(let error):
        print("Failed to start recording: \(error)")
    }
}

// Stop recording
QCBugPlugin.stopScreenRecording { result in
    switch result {
    case .success(let url):
        print("Recording saved to: \(url)")
    case .failure(let error):
        print("Failed to stop recording: \(error)")
    }
}

// Check recording status
if QCBugPlugin.isScreenRecording {
    print("Currently recording")
}
```

### Delegate Pattern

Implement `QCBugPluginDelegate` to receive lifecycle callbacks:

```swift
class AppDelegate: UIResponder, UIApplicationDelegate, QCBugPluginDelegate {

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure plugin
        let config = QCBugPluginConfig(webhookURL: "https://your-webhook.com/bugs")
        QCBugPlugin.configure(using: window!, configuration: config)

        // Set delegate
        QCBugPlugin.setDelegate(self)

        return true
    }

    // MARK: - QCBugPluginDelegate

    func bugPluginShouldPresentBugReport() -> Bool {
        // Return false to prevent bug report from being presented
        return true
    }

    func bugPluginDidSubmitReport(_ reportId: String) {
        print("Bug report submitted with ID: \(reportId)")
        // Show success message to user
    }

    func bugPluginDidFailToSubmitReport(_ error: Error) {
        print("Bug report submission failed: \(error)")
        // Show error message to user
    }

    func bugPluginDidStartRecording() {
        print("Screen recording started")
    }

    func bugPlugin(didStopRecordingWith url: URL) {
        print("Screen recording saved to: \(url)")
    }

    func bugPluginDidFailRecording(_ error: Error) {
        print("Screen recording failed: \(error)")
    }

    func bugPluginDidClearSession() {
        print("Bug report session cleared")
    }
}
```

### Session Management

```swift
// Get current session media count
let mediaCount = QCBugPluginManager.shared.getSessionMediaCount()

// Get all session media attachments
let attachments = QCBugPluginManager.shared.getSessionMediaAttachments()

// Clear session (removes all media and resets form state)
QCBugPluginManager.shared.clearSession()

// Remove specific media attachment
QCBugPluginManager.shared.removeSessionMedia(at: index)
```

## Bug Report Structure

Each bug report includes:

- **Description** - User-provided bug description
- **Priority** - Low, Medium, High, or Critical
- **Category** - UI/UX, Functionality, Performance, Crash, Data, Network, Security, or Other
- **Device Info** - Model, OS version, screen size, battery level, disk space, locale
- **App Info** - Bundle ID, version, build number, app name
- **Media Attachments** - Screenshots and screen recordings
- **User Actions** - History of user interactions (if tracked)
- **Network Info** - Connection type and carrier (if available)
- **Memory Info** - Used and available memory
- **Custom Data** - Any custom metadata you provide

## Permissions

The framework requires the following permissions:

### Info.plist

Add these keys to your `Info.plist`:

```xml
<!-- Required for screen recording -->
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to save screen recordings for bug reports</string>

<!-- Required for microphone during screen recording (optional) -->
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access to record audio with screen recordings</string>

<!-- Required for GitLab OAuth integration (if using GitLab features) -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.yourapp.oauth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourapp</string>
        </array>
    </dict>
</array>
```

**Note:** Replace `yourapp` with your app's custom URL scheme that matches the `scheme` parameter in `GitLabAppConfig`.

## Architecture

QCBugPlugin follows Clean Architecture principles:

- **Domain Layer** - Models and protocols (business logic interface)
- **Data Layer** - Service implementations (ReplayKit, networking, file system)
- **Presentation Layer** - View controllers and UI components
- **Manager Layer** - Central coordination and state management

Key architectural patterns:
- Protocol-first design
- Dependency injection via protocols
- Singleton coordinator pattern
- Native-Web bridge for hybrid UI
- Session-based state management

## Requirements

- iOS 12.0+
- Swift 5.3+
- Xcode 12.0+

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Note: feature branch `feature/ui-agent-builder` contains UI improvements for recording preview handling and floating UI backoff timing. See tests for details.

## License

QCBugPlugin is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## Author

**VietUnion**
Copyright © 2025 VietUnion. All rights reserved.

## Support

For issues, questions, or feature requests, please [open an issue](https://github.com/yourusername/QCBugPlugin/issues).

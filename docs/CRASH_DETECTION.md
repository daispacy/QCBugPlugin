# Crash Detection & Reporting

QCBugPlugin includes a Firebase-like crash detection system that automatically captures and reports app crashes.

## Features

- ✅ Automatic crash detection (NSException and POSIX signals)
- ✅ Crash log storage with detailed stack traces
- ✅ User prompt to report crashes on next app launch
- ✅ Automatic attachment of crash logs to bug reports
- ✅ Full device and app context capture
- ✅ Support for multiple pending crash reports

## How It Works

1. **Crash Capture**: When the app crashes, the crash detection service captures:
   - Exception name and reason
   - Full stack trace
   - Device information (model, OS version)
   - App information (bundle ID, version)
   - Timestamp

2. **Log Storage**: Crash data is saved to disk in the app's Documents directory

3. **Next Launch**: When the user reopens the app, a dialog prompts them to report the crash

4. **Bug Report**: If the user chooses to report, the crash log is automatically attached to a new bug report

## Configuration

Enable crash reporting in your QCBugPlugin configuration:

```swift
let config = QCBugPluginConfig(
    webhookURL: "https://your-webhook-url.com/bugs",
    enableCrashReporting: true  // Default is true
)

QCBugPlugin.configure(using: window, configuration: config)
```

## Delegate Callbacks

Implement the delegate protocol to receive crash-related events:

```swift
extension AppDelegate: QCBugPluginDelegate {
    func bugPluginDidDetectCrashes(_ crashReports: [QCCrashReport]) {
        print("Detected \(crashReports.count) crash(es)")

        // Send analytics event
        Analytics.logEvent("crash_detected", parameters: [
            "count": crashReports.count
        ])
    }

    func bugPluginDidDismissCrash(_ crashReport: QCCrashReport) {
        print("User dismissed crash report")

        // Log dismissal
        Analytics.logEvent("crash_dismissed")
    }
}

// Set the delegate
QCBugPlugin.setDelegate(self)
```

## Crash Report Data Structure

```swift
public struct CrashReport {
    public let timestamp: Date
    public let crashType: CrashType  // .exception or .signal
    public let exceptionName: String?
    public let exceptionReason: String?
    public let stackTrace: [String]
    public let appInfo: AppInfo
    public let deviceInfo: DeviceInfo
    public let logFilePath: String
    public let identifier: String

    public enum CrashType: String {
        case exception
        case signal
        case unknown
    }

    public struct AppInfo {
        public let bundleIdentifier: String
        public let version: String
        public let buildNumber: String
    }

    public struct DeviceInfo {
        public let model: String
        public let systemName: String
        public let systemVersion: String
        public let locale: String
    }
}
```

## User Experience

When a crash is detected on app launch:

### Single Crash
```
┌─────────────────────────────┐
│       App Crashed           │
├─────────────────────────────┤
│ The app crashed unexpectedly│
│                             │
│ Crash time: Nov 6, 2025     │
│             2:30 PM         │
│                             │
│ Would you like to report    │
│ this crash to help us fix   │
│ the issue?                  │
├─────────────────────────────┤
│         [Report]            │
│     [View Details]          │
│        [Dismiss]            │
└─────────────────────────────┘
```

### Multiple Crashes
```
┌─────────────────────────────┐
│       App Crashed           │
├─────────────────────────────┤
│ The app crashed 3 times     │
│ since you last used it.     │
│                             │
│ Would you like to report    │
│ these crashes to help us    │
│ fix the issue?              │
├─────────────────────────────┤
│       [Report All]          │
│      [Dismiss All]          │
└─────────────────────────────┘
```

## Crash Log Format

```
=====================================
CRASH REPORT
=====================================

Timestamp: 2025-11-06 14:30:15
Crash Type: exception
Identifier: 1A2B3C4D-5E6F-7890

Exception Name: NSInvalidArgumentException
Exception Reason: unrecognized selector sent to instance

Application Info:
- Bundle ID: com.example.myapp
- Version: 1.0.0 (123)

Device Info:
- Model: iPhone 15 Pro
- System: iOS 17.5
- Locale: en_US

Stack Trace:
0: MyApp`-[ViewController buttonTapped:] + 42
1: UIKitCore`-[UIApplication sendAction:to:from:forEvent:] + 96
2: UIKitCore`-[UIControl sendAction:to:forEvent:] + 69
...

=====================================
```

## Integration with Bug Reports

When a crash is reported:

1. Bug category is automatically set to `.crash`
2. Priority is set to `.high`
3. Description includes crash summary
4. Crash log file is attached
5. All device and app context is included

## Storage Location

Crash reports are stored at:
```
Documents/QCBugPlugin/CrashReports/
  ├── crash_2025-11-06_14-30-15_1A2B3C4D.log
  ├── crash_2025-11-06_15-45-30_2B3C4D5E.log
  └── crash_metadata.json
```

## Signal Handling

The service captures the following POSIX signals:
- `SIGABRT` - Abort signal
- `SIGILL` - Illegal instruction
- `SIGSEGV` - Segmentation fault
- `SIGFPE` - Floating point exception
- `SIGBUS` - Bus error
- `SIGPIPE` - Broken pipe

## Best Practices

1. **Enable in Production**: Crash reporting should be enabled in production builds
2. **Monitor Delegate**: Implement delegate methods to track crash metrics
3. **Test Crashes**: Use debug tools to simulate crashes during testing
4. **Privacy**: Crash logs may contain sensitive data - review before submission

## Testing

To test crash detection:

```swift
#if DEBUG
// Simulate exception crash
func testExceptionCrash() {
    let array = [1, 2, 3]
    _ = array[10]  // Out of bounds
}

// Simulate signal crash
func testSignalCrash() {
    let pointer: UnsafeMutablePointer<Int>? = nil
    pointer?.pointee = 42  // Null pointer dereference
}
#endif
```

## Disable Crash Reporting

To disable crash reporting:

```swift
let config = QCBugPluginConfig(
    webhookURL: "https://your-webhook-url.com/bugs",
    enableCrashReporting: false
)
```

## Comparison with Firebase Crashlytics

| Feature | QCBugPlugin | Firebase Crashlytics |
|---------|-------------|---------------------|
| Crash Detection | ✅ | ✅ |
| User Prompt | ✅ | ❌ |
| Manual Reporting | ✅ | ❌ |
| Automatic Upload | ❌ | ✅ |
| Cloud Dashboard | ❌ | ✅ |
| Offline Storage | ✅ | ✅ |
| No External Dependencies | ✅ | ❌ |

QCBugPlugin focuses on user consent and manual reporting, while Crashlytics emphasizes automatic cloud sync and analytics.

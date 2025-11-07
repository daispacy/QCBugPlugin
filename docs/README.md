# QCBugPlugin Architecture Documentation

This directory contains comprehensive architecture analysis and integration guides for the QCBugPlugin framework.

## Quick Navigation

### 📋 START HERE
- **[INTEGRATION_SUMMARY.md](INTEGRATION_SUMMARY.md)** - Quick reference for crash detection integration (10 min read)
  - Most important files to modify
  - Implementation checklist
  - Data structures to create
  - AppDelegate integration example

### 📚 DETAILED REFERENCE
- **[ARCHITECTURE_ANALYSIS.md](ARCHITECTURE_ANALYSIS.md)** - Complete architecture deep dive (45 min read)
  - Layer-by-layer breakdown
  - All components explained
  - Data models reference
  - Key implementation patterns
  - Crash detection integration points

- **[COMPONENT_DIAGRAM.md](COMPONENT_DIAGRAM.md)** - Visual architecture maps (15 min read)
  - System architecture diagrams
  - Component interaction maps
  - Data flow visualizations
  - Configuration initialization flow
  - Bug report submission pipeline

## File Summaries

### Core Files by Responsibility

| Responsibility | File | Lines | Priority |
|---|---|---|---|
| **Public API** | `QCBugPlugin.swift` | 193 | Critical |
| **Main Coordinator** | `QCBugPluginManager.swift` | 753 | Critical |
| **Bug Report Model** | `BugReport.swift` | 332 | Critical |
| **API Service** | `BugReportAPIService.swift` | 936 | Critical |
| **Configuration** | `QCBugPluginConfiguration.swift` | 35 | Important |
| **Form UI** | `QCBugReportViewController.swift` | 100+ | Important |
| **GitLab Auth** | `GitLabAuthService.swift` | 80+ | Important |
| **Floating Buttons** | `QCFloatingActionButtons.swift` | 681 | Nice-to-have |
| **User Actions** | `UserAction.swift` | 171 | Nice-to-have |

## Quick Facts

- **Framework Type:** iOS Bug Reporting SDK
- **Architecture:** Clean Architecture (Domain/Data/Presentation)
- **iOS Target:** iOS 12+
- **Main Coordinator:** `QCBugPluginManager` (Singleton)
- **State Management:** Session-based with persistence
- **Thread Safety:** Main thread UI + concurrent processing

## Integration Steps (Summary)

### Phase 1: Core Detection
1. Create `CrashDetectionService` protocol
2. Implement exception handlers
3. Capture crash context
4. Persist to disk

### Phase 2: QCBugPlugin Integration
1. Extend `BugReport` for crash fields
2. Update `BugCategory.crash` detection
3. Hook into AppDelegate
4. Load crashes on app startup

### Phase 3: UI & Auto-Submission
1. Pre-populate form with crash data
2. Auto-screenshot on crash
3. Optional silent submission
4. Crash history viewer

### Phase 4: Testing
1. Unit tests for detection
2. Integration tests with webhook
3. Manual crash scenarios
4. Performance validation

## Key Integration Points

### 1. AppDelegate Hook
```swift
// In didFinishLaunchingWithOptions:
CrashDetectionService.shared.setupHandlers()

if let crash = CrashDetectionService.shared.loadPreviousCrash() {
    QCBugPlugin.setCustomData(crash.toDictionary())
}

QCBugPlugin.configure(using: window, configuration: config)
```

### 2. Session State Management
The Manager persists across presentations:
- `sessionBugCategory` → Use `.crash` on detection
- `sessionBugPriority` → Use `.critical` on crash
- `sessionBugDescription` → Pre-fill with stack trace
- `sessionCustomData` → Store exception details

### 3. Crash Data Available
```swift
BugReport includes:
- memoryInfo (RAM state at crash)
- deviceInfo (device state)
- userActions (actions before crash)
- currentScreen (where crash occurred)
- customData (exception details)
```

## Architecture Layers

```
┌─────────────────────────┐
│  PRESENTATION LAYER     │
│  (UI Components)        │
├─────────────────────────┤
│  MANAGER LAYER          │
│  (Singleton Coordinator)│
├─────────────────────────┤
│  DOMAIN LAYER           │
│  (Models & Protocols)   │
├─────────────────────────┤
│  DATA LAYER             │
│  (Services & APIs)      │
└─────────────────────────┘
```

## Critical Methods to Know

### Public API (QCBugPlugin)
```swift
QCBugPlugin.configure(using:configuration:)
QCBugPlugin.presentBugReport()
QCBugPlugin.setCustomData(_:)
QCBugPlugin.setDelegate(_:)
```

### Manager (QCBugPluginManager)
```swift
presentBugReport()
captureScreenshot(completion:)
stopScreenRecording(completion:)
setCustomData(_:)
clearSession()
```

### Crash Integration
```swift
QCBugPlugin.setCustomData(crashData)       // Pre-fill
QCBugPlugin.presentBugReport()             // Show form
```

## Data Model Reference

### BugReport (Core)
Contains all bug context:
- `id`, `timestamp`, `description`
- `priority` (low/medium/high/critical)
- `category` (ui/functionality/**crash**/...)
- `userActions`, `deviceInfo`, `appInfo`
- `memoryInfo`, `mediaAttachments`
- `customData` (app-specific fields)

### MediaAttachment
- Type: screenshot | screenRecording
- FileURL, fileName, timestamp, fileSize

### UserAction
- ID, timestamp, actionType
- screenName, viewControllerClass
- elementInfo, coordinates, metadata

## Testing Strategy

### Unit Tests
- Exception handler installation
- Stack trace capture
- Crash context serialization
- Memory info capture

### Integration Tests
- Crash detection with NSException
- Crash detection with signals
- Webhook payload structure
- GitLab issue creation

### Manual Testing
- Throw NSException
- Trigger SIGSEGV
- Memory warnings
- Low disk space
- Form pre-population

## Performance Impact

- **Handler setup:** <5 ms
- **Stack trace capture:** 10-50 ms
- **Memory overhead:** <1 MB (10 crashes)
- **Disk I/O:** Negligible (async writes)
- **Normal flow:** No impact (only on crash)

## API Webhook Contract

**POST to** `configuration.webhookURL`

**Headers:**
- `Content-Type: application/json`
- `Authorization: Bearer {jwt|apikey}`
- `User-Agent: QCBugPlugin/1.0`
- `X-Request-ID: {uuid}`

**Body:** JSON with:
- Report metadata (ID, timestamp, category, priority)
- Device state (model, OS, battery, memory)
- App info (bundle, version, build)
- User actions (history of taps/scrolls/etc)
- Media attachments (base64 inline)
- Custom data (exception details)
- GitLab credentials (if configured)

## Next Steps

1. **Read** `INTEGRATION_SUMMARY.md` for implementation overview
2. **Study** `ARCHITECTURE_ANALYSIS.md` for detailed component behavior
3. **Reference** `COMPONENT_DIAGRAM.md` for visual understanding
4. **Implement** following the 4-phase checklist
5. **Test** using provided testing strategy

## Files Modified During Integration

- `Sources/Manager/QCBugPluginManager.swift` - Add crash session state
- `Sources/Domain/Models/BugReport.swift` - Add crash fields (maybe)
- `Sources/Domain/Models/QCBugPluginConfiguration.swift` - Add crash options
- `AppDelegate.swift` (host app) - Initialize crash detector
- NEW: `Sources/Data/Services/CrashDetectionService.swift` - New service

## Questions?

Refer to:
- **"How do I trigger crash form?"** → INTEGRATION_SUMMARY.md § "How to Hook Into AppDelegate"
- **"What's the data flow?"** → COMPONENT_DIAGRAM.md § "Data Flow: Bug Report Submission Pipeline"
- **"Which services do I need?"** → ARCHITECTURE_ANALYSIS.md § "6. Data/API Layer"
- **"How's session state managed?"** → ARCHITECTURE_ANALYSIS.md § "11.1 Session State Management"

---

**Last Updated:** November 6, 2025  
**Version:** 1.0.0  
**Status:** Ready for implementation

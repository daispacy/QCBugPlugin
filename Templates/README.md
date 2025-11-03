# QCBugPlugin Integration Templates

This folder contains ready-to-use templates for integrating QCBugPlugin into your iOS app features **without modifying existing code**.

## 📋 Templates Overview

| Template | Purpose | When to Use |
|----------|---------|-------------|
| `AppDelegate+QCBugPlugin.swift` | App-level configuration | Once per app, for global setup |
| `YourViewController+QCBugPlugin.swift` | View controller integration | Once per feature/screen |
| `YourViewModel+QCBugPlugin.swift` | Business logic tracking | Once per ViewModel that needs tracking |

## 🚀 Quick Start

### Step 1: App-Level Setup

1. Copy `AppDelegate+QCBugPlugin.swift` to your project
2. Customize the webhook URL and configuration
3. Build in DEBUG or STAGING - QCBugPlugin is automatically initialized!

**No need to modify your original AppDelegate.swift!**

### Step 2: Feature Integration

For each feature you want to add bug reporting:

1. Copy `YourViewController+QCBugPlugin.swift`
2. Rename to match your controller (e.g., `CheckoutViewController+QCBugPlugin.swift`)
3. Replace `YourViewController` with your actual class name
4. Customize the tracking data
5. Build and test!

**Your original ViewController.swift remains unchanged!**

### Step 3: ViewModel Tracking (Optional)

For comprehensive business logic tracking:

1. Copy `YourViewModel+QCBugPlugin.swift`
2. Rename to match your ViewModel
3. Replace `YourViewModel` with your actual class name
4. Add tracking calls to your ViewModel methods (minimal changes)

## 🎯 Integration Philosophy

### Non-Intrusive Pattern

**Core Principle:** Never modify existing feature code!

```
✅ DO:
- Create separate +QCBugPlugin.swift extension files
- Use method swizzling to hook into lifecycle
- Keep QCBugPlugin code isolated
- Wrap everything in #if DEBUG || STAGING

❌ DON'T:
- Modify original ViewController/ViewModel files
- Add QCBugPlugin imports to production code
- Mix QCBugPlugin code with feature code
- Forget conditional compilation
```

### Method Swizzling

The templates use method swizzling to automatically integrate without code changes:

```swift
Original Method          →  Swizzled Method
viewDidLoad()           →  qcBugPlugin_viewDidLoad()
viewWillAppear(_:)      →  qcBugPlugin_viewWillAppear(_:)
motionEnded(_:with:)    →  qcBugPlugin_motionEnded(_:with:)
```

**Benefits:**
- No changes to original code
- Automatic initialization
- Easy to add/remove
- Compile-time conditional

## 📝 Template Usage Guide

### Template 1: AppDelegate+QCBugPlugin.swift

**Purpose:** Initialize QCBugPlugin when app launches

**What it does:**
- Swizzles `application(_:didFinishLaunchingWithOptions:)`
- Configures QCBugPlugin with app-level settings
- Enables global shake gesture
- Sets up floating debug button

**Customization points:**
```swift
// TODO: Set your webhook URL
let webhookURL = "https://webhook.site/your-unique-id"

// TODO: Add API key if needed
let apiKey: String? = "your-api-key"

// TODO: Customize app-level custom data
customData: [
    "app": appName,
    "environment": environment,
    "userId": currentUserId,  // Add your data
    "featureFlags": enabledFlags
]
```

### Template 2: YourViewController+QCBugPlugin.swift

**Purpose:** Add bug reporting to a specific screen

**What it does:**
- Swizzles lifecycle methods (viewDidLoad, viewWillAppear, etc.)
- Adds debug button (🐛) to navigation bar
- Handles shake gesture with screen context
- Updates tracking data when screen appears

**Customization points:**
```swift
// TODO: Change feature name
"feature": "YourFeatureName"

// TODO: Add screen-specific data
private func updateBugReportContext() {
    var contextData = [...]
    // Add your dynamic data here
    contextData["selectedItem"] = selectedItem?.id
    contextData["hasFilters"] = !filters.isEmpty
}

// TODO: Implement form data collection
private func collectFormData() -> [String: Any]? {
    // Collect sanitized form data
}
```

### Template 3: YourViewModel+QCBugPlugin.swift

**Purpose:** Track business logic and operations

**What it does:**
- Provides tracking methods for operations
- Tracks success/failure outcomes
- Tracks user selections and state changes
- Tracks network requests/responses

**Integration approach:**
```swift
// In your original ViewModel, add minimal tracking calls:

func fetchData() {
    trackOperationStarted(operationName: "FetchData")  // Add this line
    
    // Your existing code...
    apiService.fetch { result in
        switch result {
        case .success(let data):
            self?.trackOperationSuccess(operationName: "FetchData")  // Add this line
        case .failure(let error):
            self?.trackOperationFailure(operationName: "FetchData", error: error)  // Add this line
        }
    }
}
```

## 🔒 Security Guidelines

### Data Sanitization

**Always sanitize sensitive data:**

```swift
✅ SAFE - Track presence:
data["hasPassword"] = true
data["hasCardNumber"] = true
data["emailProvided"] = !email.isEmpty

❌ UNSAFE - Never track actual values:
data["password"] = "abc123"        // NEVER!
data["cardNumber"] = "1234..."     // NEVER!
data["pin"] = "1234"               // NEVER!
```

### Conditional Compilation

**Always wrap in DEBUG/STAGING:**

```swift
#if DEBUG || STAGING
extension YourViewController {
    // QCBugPlugin code here
}
#endif
```

This ensures QCBugPlugin is completely removed from production builds.

## 🧪 Testing Your Integration

### 1. Verify Swizzling

Check console logs when app launches:
```
✅ QCBugPlugin: AppDelegate swizzling initialized
✅ QCBugPlugin swizzling initialized for YourViewController
🐛 QCBugPlugin configured for YourApp - DEBUG
```

### 2. Test Triggers

- **Shake Device:** Should present bug report from any screen
- **Debug Button:** Tap 🐛 in navigation bar
- **Floating Button:** Drag and tap the floating debug button

### 3. Verify Context Data

1. Trigger bug report
2. Check the submitted webhook data
3. Verify feature-specific context is included
4. Confirm sensitive data is sanitized

### 4. Test Original Functionality

**Critical:** Ensure original app functionality is unchanged!

- Navigate through your feature normally
- Verify all original behaviors work
- Check that swizzling doesn't break anything

## 📊 Example Integration Flow

### Example: Shopping Cart Feature

**Files created (all non-intrusive):**

```
YourApp/
├── AppDelegate.swift                          (original - unchanged)
├── AppDelegate+QCBugPlugin.swift              (new - app setup)
├── Features/
│   └── ShoppingCart/
│       ├── CartViewController.swift           (original - unchanged)
│       ├── CartViewController+QCBugPlugin.swift   (new - screen tracking)
│       ├── CartViewModel.swift                (original - minimal changes)
│       └── CartViewModel+QCBugPlugin.swift    (new - business logic tracking)
```

**What gets tracked:**

1. **App Level:** User ID, app version, environment
2. **Screen Level:** Current cart items count, total amount, selected shipping
3. **Business Logic:** Add to cart, remove from cart, checkout attempts, payment results

**Trigger methods:**

- Shake gesture on any screen
- Debug button in cart screen
- Floating button anywhere

## 🎨 Customization Examples

### Add Custom Swizzling Points

You can swizzle additional methods as needed:

```swift
// Swizzle custom method
private static func swizzleYourCustomMethod() {
    let originalSelector = #selector(yourCustomMethod)
    let swizzledSelector = #selector(qcBugPlugin_yourCustomMethod)
    swizzleMethod(original: originalSelector, swizzled: swizzledSelector)
}

@objc private func qcBugPlugin_yourCustomMethod() {
    qcBugPlugin_yourCustomMethod() // Call original
    
    // Your tracking logic
    QCBugPlugin.setCustomData(["customAction": "performed"])
}
```

### Add Custom Tracking Events

```swift
// In your ViewModel extension
func trackCustomEvent(name: String, data: [String: Any]) {
    var trackingData = data
    trackingData["eventName"] = name
    trackingData["timestamp"] = Date().timeIntervalSince1970
    
    QCBugPlugin.setCustomData(trackingData)
}
```

## ⚠️ Common Pitfalls

### 1. Forgetting to Call Original Method

```swift
❌ WRONG:
@objc private func qcBugPlugin_viewDidLoad() {
    // Original not called - will break functionality!
    setupQCBugReporting()
}

✅ CORRECT:
@objc private func qcBugPlugin_viewDidLoad() {
    qcBugPlugin_viewDidLoad() // Call original first!
    setupQCBugReporting()
}
```

### 2. Tracking Sensitive Data

```swift
❌ WRONG:
QCBugPlugin.setCustomData([
    "password": passwordField.text,
    "creditCard": cardField.text
])

✅ CORRECT:
QCBugPlugin.setCustomData([
    "hasPassword": !passwordField.text.isEmpty,
    "hasPaymentMethod": selectedPaymentMethod != nil
])
```

### 3. Missing Conditional Compilation

```swift
❌ WRONG:
extension MyViewController {
    // No #if DEBUG wrapper - will compile in production!
}

✅ CORRECT:
#if DEBUG || STAGING
extension MyViewController {
    // Safe - only in debug/staging builds
}
#endif
```

## 📞 Support

For questions or issues:
1. Check the main README.md
2. Review the inline comments in templates
3. Test with webhook.site before production integration
4. Verify original functionality remains unchanged

## 🎓 Learning Resources

- [Main README](../README.md) - Framework overview
- [STRUCTURE.md](../STRUCTURE.md) - Architecture details
- [SPM_PUBLIC_API.md](../SPM_PUBLIC_API.md) - Public API reference
- [SAMPLE_IMPLEMENT.md](../SAMPLE_IMPLEMENT.md) - Real-world example

---

**Happy Bug Tracking! 🐛**

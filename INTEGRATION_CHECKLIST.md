# QCBugPlugin Integration Checklist

Use this checklist to ensure proper integration of QCBugPlugin into your iOS app features.

## ✅ Pre-Integration Checklist

### Framework Setup
- [ ] QCBugPlugin added via Swift Package Manager
- [ ] Framework imports successfully in DEBUG/STAGING builds
- [ ] No import errors or missing dependencies
- [ ] Verified iOS 12+ deployment target

### Webhook Configuration
- [ ] Webhook endpoint URL obtained (e.g., webhook.site for testing)
- [ ] Webhook tested and receiving requests
- [ ] API key configured (if webhook requires authentication)
- [ ] HTTPS endpoint (recommended for production staging)

### Build Configuration
- [ ] DEBUG build configuration exists
- [ ] STAGING build configuration exists (if applicable)
- [ ] Conditional compilation flags set correctly (`#if DEBUG || STAGING`)
- [ ] Production builds exclude QCBugPlugin (verified in build settings)

## ✅ App-Level Integration

### AppDelegate Setup
- [ ] Copied `Templates/AppDelegate+QCBugPlugin.swift` to project
- [ ] Customized webhook URL
- [ ] Configured API key (if needed)
- [ ] Customized app-level custom data
- [ ] Set appropriate `maxActionHistoryCount` (default: 100)
- [ ] Configured `enableFloatingButton` preference
- [ ] Tested app launch - verified console log: "🐛 QCBugPlugin configured"
- [ ] Verified original AppDelegate functionality unchanged

### Global Shake Gesture
- [ ] Global shake gesture working from any screen
- [ ] Bug report UI presents correctly
- [ ] App-level custom data appears in bug reports

## ✅ Feature-Specific Integration

Complete this section for EACH feature being integrated.

### Feature: _____________________ (fill in feature name)

#### ViewController Integration
- [ ] Copied `Templates/YourViewController+QCBugPlugin.swift`
- [ ] Renamed file to `{YourViewController}+QCBugPlugin.swift`
- [ ] Replaced all instances of `YourViewController` with actual class name
- [ ] Replaced `YourFeatureName` with actual feature name
- [ ] Customized `setInitialContext()` with feature-specific data
- [ ] Implemented `updateBugReportContext()` with dynamic data
- [ ] Implemented `collectFormData()` (if applicable)
- [ ] Sanitized all sensitive data (no passwords, PINs, full card numbers)
- [ ] Debug button (🐛) appears in navigation bar
- [ ] Debug button triggers bug report
- [ ] Shake gesture works with feature context
- [ ] Verified original ViewController functionality unchanged

#### ViewModel Integration (Optional)
- [ ] Copied `Templates/YourViewModel+QCBugPlugin.swift`
- [ ] Renamed file to `{YourViewModel}+QCBugPlugin.swift`
- [ ] Replaced all instances of `YourViewModel` with actual class name
- [ ] Replaced `YourFeatureName` with actual feature name
- [ ] Added `trackOperationStarted()` calls to key operations
- [ ] Added `trackOperationSuccess()` calls for successful outcomes
- [ ] Added `trackOperationFailure()` calls to error handlers
- [ ] Added `trackUserSelection()` calls for important selections
- [ ] Customized `sanitizeParameters()` for feature-specific sensitive data
- [ ] Verified original ViewModel functionality unchanged

#### Context Data Verification
- [ ] Feature name tracked correctly
- [ ] Screen name tracked correctly
- [ ] User selections tracked (sanitized)
- [ ] Form data tracked (sanitized, presence flags only for sensitive fields)
- [ ] Business operation outcomes tracked
- [ ] Network requests/responses tracked (if applicable)
- [ ] No sensitive data in tracking (verified)

## ✅ Security Checklist

### Conditional Compilation
- [ ] All QCBugPlugin code wrapped in `#if DEBUG || STAGING`
- [ ] No QCBugPlugin imports in production code
- [ ] Verified QCBugPlugin completely removed from Release builds
- [ ] No performance impact in production builds

### Data Sanitization
- [ ] No passwords tracked
- [ ] No PINs tracked
- [ ] No authentication tokens tracked
- [ ] No API keys tracked
- [ ] No full credit card numbers tracked
- [ ] No CVV codes tracked
- [ ] No social security numbers or national IDs tracked
- [ ] Personal data anonymized or flagged only (not full values)
- [ ] Sensitive form fields tracked as presence flags only

### Network Security
- [ ] Webhook URL uses HTTPS (recommended)
- [ ] API key not hardcoded (use configuration)
- [ ] Webhook endpoint validates requests
- [ ] Rate limiting considered for webhook

## ✅ Testing Checklist

### Functional Testing
- [ ] App launches successfully with QCBugPlugin
- [ ] Original app functionality unchanged
- [ ] No crashes or errors in console
- [ ] Swizzling logs appear in console
- [ ] Bug report UI presents correctly
- [ ] Bug report UI dismisses correctly

### Trigger Testing
- [ ] Shake gesture triggers bug report
- [ ] Debug button (🐛) triggers bug report
- [ ] Floating button triggers bug report (if enabled)
- [ ] All triggers work from target screen
- [ ] Context data updates correctly before presenting

### Data Collection Testing
- [ ] User actions tracked automatically
- [ ] Screen transitions tracked
- [ ] Button taps tracked
- [ ] Text field interactions tracked
- [ ] Custom feature data collected
- [ ] Business logic outcomes tracked
- [ ] Error states tracked

### Bug Report Submission
- [ ] Bug report submits successfully
- [ ] Webhook receives request
- [ ] JSON data structure valid
- [ ] All expected data present in webhook
- [ ] Screen recording included (if used)
- [ ] No sensitive data in submission
- [ ] Multipart form data formatted correctly

### Screen Recording
- [ ] Screen recording permission requested
- [ ] Recording starts successfully
- [ ] Recording stops successfully
- [ ] Video file created
- [ ] Video included in submission
- [ ] Video playable and clear
- [ ] Recording doesn't crash app

### Context Data Validation
- [ ] App-level data present (app name, version, environment)
- [ ] Feature-level data present (feature name, screen name)
- [ ] User action history present
- [ ] Device information present
- [ ] Custom data present and accurate
- [ ] Timestamp data accurate
- [ ] No duplicate or conflicting data

## ✅ Performance Checklist

### Memory
- [ ] No memory leaks detected (Instruments)
- [ ] Action history limit working (configured max count)
- [ ] Screen recordings cleaned up after submission
- [ ] Weak delegate references used

### CPU
- [ ] No significant CPU impact from tracking
- [ ] Swizzling overhead minimal
- [ ] Action processing on background queue
- [ ] UI remains responsive

### Storage
- [ ] Temporary files cleaned up
- [ ] Screen recordings deleted after submission
- [ ] No excessive disk space usage
- [ ] Old bug report data cleared

## ✅ Documentation Checklist

### Code Documentation
- [ ] Extension files include header comments
- [ ] Feature name documented in code
- [ ] Customization points marked with TODO
- [ ] Security considerations documented
- [ ] Usage examples included

### Team Documentation
- [ ] Integration documented in team wiki/docs
- [ ] Webhook URL shared with team
- [ ] QC team trained on using bug reporting
- [ ] Developers aware of new tracking
- [ ] Security team notified of data collection

### User Documentation
- [ ] QC testers know how to trigger bug reports
- [ ] Testing team aware of shake gesture
- [ ] Debug button usage documented
- [ ] Screen recording usage explained

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] All tests passing
- [ ] Code review completed
- [ ] Security review completed
- [ ] Performance acceptable
- [ ] Documentation complete

### Staging Deployment
- [ ] Deployed to STAGING environment
- [ ] Webhook receiving STAGING reports
- [ ] QC team testing in STAGING
- [ ] Bug reports verified in STAGING

### Production Protection
- [ ] Verified QCBugPlugin excluded from PRODUCTION builds
- [ ] No DEBUG symbols in PRODUCTION
- [ ] No test webhooks in PRODUCTION config
- [ ] Build configurations verified

## ✅ Maintenance Checklist

### Regular Checks
- [ ] Webhook endpoint still active
- [ ] Bug reports being received
- [ ] No breaking changes in framework updates
- [ ] Action history limit appropriate
- [ ] Disk space usage acceptable

### Updates
- [ ] QCBugPlugin framework version tracked
- [ ] Breaking changes reviewed before updating
- [ ] Integration templates updated if needed
- [ ] Team notified of changes

## 📊 Integration Completion

### Summary
- Total features integrated: _____
- Integration date: _____
- Integrated by: _____
- Reviewed by: _____

### Sign-off
- [ ] Developer sign-off
- [ ] QC team sign-off
- [ ] Security team sign-off (if required)
- [ ] Product owner sign-off (if required)

---

## 🎯 Quick Reference

### Must-Have for Every Integration:
1. ✅ Conditional compilation (#if DEBUG || STAGING)
2. ✅ Original code unchanged
3. ✅ Sensitive data sanitized
4. ✅ Multiple trigger methods (shake, button)
5. ✅ Context data customized
6. ✅ Tested thoroughly

### Common Issues:
- Forgot to call original method in swizzled implementation
- Tracked sensitive data (passwords, cards)
- Missing conditional compilation
- Webhook URL not configured
- Original functionality broken

### Quick Test:
1. Launch app ➜ Check console for setup log
2. Navigate to feature ➜ Check debug button appears
3. Shake device ➜ Bug report should present
4. Fill report ➜ Submit and verify webhook

---

**Integration Complete!** 🎉

Once all items are checked, your QCBugPlugin integration is ready for QC testing!

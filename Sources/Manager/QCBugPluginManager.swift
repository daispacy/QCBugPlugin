//
//  QCBugPluginManager.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import UIKit
import QuickLook

/// Internal custom window that detects shake gestures
private class QCInternalShakeDetectingWindow: UIWindow {
    var shakeHandler: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Make sure the window doesn't intercept touches
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)

        if motion == .motionShake {
            shakeHandler?()
        }
    }
}

private final class SingleAttachmentPreviewDataSource: NSObject, QLPreviewControllerDataSource {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return url as NSURL
    }
}

private enum AttachmentPreviewMode {
    case none
    case recordingEditor
    case attachmentViewer
}

/// Main manager class for the QC Bug Plugin
final class QCBugPluginManager: NSObject {

    // MARK: - Singleton
    static let shared = QCBugPluginManager()

    // MARK: - Private Properties
    private var configuration: QCBugPluginConfig?
    private weak var hostWindow: UIWindow?
    private var internalShakeWindow: QCInternalShakeDetectingWindow?
    private var screenRecorder: ScreenRecordingProtocol?
    private var screenCapture: ScreenCaptureProtocol?
    private var bugReportService: BugReportProtocol?
    private var gitLabAuthService: GitLabAuthProviding?
    private var crashDetectionService: CrashDetectionProtocol?
    private var crashAlertController: QCCrashReportAlertController?
    private var isConfigured: Bool = false
    private var floatingActionButtons: QCFloatingActionButtons?
    private var sessionMediaAttachments: [MediaAttachment] = []
    private var shouldAutoPresentForm: Bool = false
    private var sessionBugReportViewController: QCBugReportViewController?
    private var sessionBugDescription: String = ""
    private var sessionBugPriority: String = ""
    private var sessionBugStage: String = BugStage.product.rawValue
    private var sessionWebhookURL: String?
    private var sessionAssigneeUsername: String?
    private var sessionIssueNumber: Int?
    private var pendingScreenshotCompletion: ((Result<URL, Error>) -> Void)?
    private var pendingScreenshotOriginalURL: URL?
    private var pendingRecordingURL: URL?
    private var pendingRecordingCompletion: ((Result<URL, Error>) -> Void)?
    private var previewDataSource: SingleAttachmentPreviewDataSource?
    private var activePreviewController: QLPreviewController?
    private var isFloatingUISuspended = false
    private var pendingFloatingUIResumeReason: String?
    private var activePreviewMode: AttachmentPreviewMode = .none
    private var submissionTimeoutWorkItem: DispatchWorkItem?
    private weak var recordingPreviewPresenter: UIViewController?

    // MARK: - Testing helpers
    /// Test helper to directly invoke confirmation flow (fallback path)
    internal func test_invokeShowRecordingConfirmationFallback(recordingURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        // Force fallback behavior by clearing any presenter
        self.recordingPreviewPresenter = nil
        self.showRecordingConfirmation(recordingURL: recordingURL, completion: completion)
    }

    internal func test_getSessionMediaCount() -> Int {
        return sessionMediaAttachments.count
    }

    // MARK: - Delegate
    weak var delegate: QCBugPluginDelegate?
    
    func setDelegate(_ delegate: QCBugPluginDelegate?) {
        self.delegate = delegate
    }
    // MARK: - Helper Methods
    private func resolvedWebhookURL() -> String {
        if let override = sessionWebhookURL?.trimmingCharacters(in: .whitespacesAndNewlines), !override.isEmpty {
            return override
        }
        return configuration?.webhookURL ?? ""
    }

    private func refreshBugReportService() {
        let webhook = resolvedWebhookURL()
        guard !webhook.isEmpty else {
            bugReportService = nil
            return
        }
        bugReportService = BugReportAPIService(
            webhookURL: webhook,
            apiKey: configuration?.apiKey,
            gitLabAuthProvider: gitLabAuthService
        )
    }

    // MARK: - Initialization
    private override init() {
        super.init()
        setupNotificationObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Configuration

    func configure(using window: UIWindow, configuration config: QCBugPluginConfig) {
        self.hostWindow = window
        self.configuration = config
        self.sessionWebhookURL = nil
        self.sessionAssigneeUsername = nil
        self.sessionIssueNumber = nil

        // Initialize services
        if config.isScreenRecordingEnabled {
            self.screenRecorder = ScreenRecordingService()
        } else {
            self.screenRecorder = nil
        }

        // Initialize screen capture service
        self.screenCapture = ScreenCaptureService()

        if let gitLabConfig = config.gitLabAppConfig {
            self.gitLabAuthService = GitLabAuthService(configuration: gitLabConfig)
        } else {
            self.gitLabAuthService = nil
        }

        // Initialize crash detection service
        if config.enableCrashReporting {
            let crashService = CrashDetectionService()
            self.crashDetectionService = crashService
            crashService.startMonitoring()

            // Check for pending crash reports
            checkForPendingCrashReports()
        } else {
            self.crashDetectionService?.stopMonitoring()
            self.crashDetectionService = nil
        }

        refreshBugReportService()

        // Setup floating action buttons and shake detection if enabled
        if config.enableFloatingButton {
            setupFloatingActionButtons()
            setupInternalShakeDetection()
        } else {
            teardownFloatingActionButtons()
            teardownShakeDetection()
        }

        self.isConfigured = true

        print("✅ QCBugPlugin configured successfully")
    }
    
    func invalidateGitLabSession() {
        gitLabAuthService?.clearCache()

        if let apiService = bugReportService as? BugReportAPIService {
            apiService.resetGitLabSession()
        }
    }
    
    func presentBugReport() {
        guard isConfigured else {
            print("❌ QCBugPlugin: Plugin not configured. Call configure() first.")
            return
        }

        // Check delegate permission
        if let shouldPresent = delegate?.bugPluginShouldPresentBugReport(),
           !shouldPresent {
            return
        }
        let actionHistory: [UserAction] = []

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Reuse existing ViewController if available, otherwise create new one
            let bugReportVC: QCBugReportViewController
            if let existingVC = self.sessionBugReportViewController {
                bugReportVC = existingVC
                // Update action history in case new actions were recorded
                bugReportVC.updateActionHistory(actionHistory)
            } else {
                bugReportVC = QCBugReportViewController(
                    actionHistory: actionHistory,
                    screenRecorder: self.screenRecorder,
                    configuration: self.configuration,
                    gitLabAuthProvider: self.gitLabAuthService
                )
                bugReportVC.delegate = self
                self.sessionBugReportViewController = bugReportVC
                
                // Add all session media attachments
                for attachment in self.sessionMediaAttachments {
                    bugReportVC.addMediaAttachment(attachment)
                }
            }

            // Ensure session form state is restored
            bugReportVC.restoreSessionState(
                description: self.sessionBugDescription,
                priority: self.sessionBugPriority,
                stage: self.sessionBugStage,
                webhookURL: self.resolvedWebhookURL(),
                assigneeUsername: self.sessionAssigneeUsername,
                issueNumber: self.sessionIssueNumber
            )

            // Hide floating buttons while bug report is presented
            self.floatingActionButtons?.isHidden = true

            // Present modally
            if let topViewController = UIApplication.shared.topViewController() {
                let navController = UINavigationController(rootViewController: bugReportVC)
                navController.modalPresentationStyle = .formSheet
                if #available(iOS 13.0, *) {
                    navController.isModalInPresentation = true
                }
                if #available(iOS 15.0, *) {
                    if let sheet = navController.sheetPresentationController {
                        sheet.detents = [.medium(), .large()]
                    }
                }
                topViewController.present(navController, animated: true)
            }
        }
    }
    
    func setCustomData(_ data: [String: Any]) {
        guard let config = configuration else { return }

        // Update configuration with new custom data
        let newConfig = QCBugPluginConfig(
            webhookURL: config.webhookURL,
            apiKey: config.apiKey,
            customData: data,
            isScreenRecordingEnabled: config.isScreenRecordingEnabled,
            enableFloatingButton: config.enableFloatingButton,
            gitLabAppConfig: config.gitLabAppConfig,
            enableCrashReporting: config.enableCrashReporting
        )

        self.configuration = newConfig
    }

    func setScreenRecordingEnabled(_ enabled: Bool) {
        guard let config = configuration else { return }

        let newConfig = QCBugPluginConfig(
            webhookURL: config.webhookURL,
            apiKey: config.apiKey,
            customData: config.customData,
            isScreenRecordingEnabled: enabled,
            enableFloatingButton: config.enableFloatingButton,
            gitLabAppConfig: config.gitLabAppConfig,
            enableCrashReporting: config.enableCrashReporting
        )

        self.configuration = newConfig

        if enabled && screenRecorder == nil {
            screenRecorder = ScreenRecordingService()
        } else if !enabled {
            screenRecorder = nil
        }
    }

    func startScreenRecording(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let recorder = screenRecorder else {
            let error = NSError(
                domain: "com.qcbugplugin",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Screen recording is not enabled"]
            )
            completion(.failure(error))
            return
        }

        recorder.startRecording { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                // Notify delegate
                self.delegate?.bugPluginDidStartRecording()
                print("🎥 QCBugPlugin: Screen recording started")
                completion(.success(()))

            case .failure(let error):
                // Notify delegate
                self.delegate?.bugPluginDidFailRecording(error)
                completion(.failure(error))
            }
        }
    }

    func stopScreenRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard let recorder = screenRecorder else {
            let error = NSError(
                domain: "com.qcbugplugin",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Screen recording is not enabled"]
            )
            completion(.failure(error))
            return
        }

        recorder.stopRecording { [weak self] result in
            guard let self = self else { return }

            // Update floating button state first
            self.floatingActionButtons?.updateRecordingState(isRecording: false)

            switch result {
            case .success(let url):
                print("🎬 QCBugPlugin: Screen recording stopped successfully")
                print("📁 QCBugPlugin: Recording saved to: \(url.path)")

                // Verify file exists
                if !FileManager.default.fileExists(atPath: url.path) {
                    print("❌ QCBugPlugin: Recording file missing at path: \(url.path)")
                    let error = NSError(
                        domain: "com.qcbugplugin",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "Recording file not found"]
                    )
                    completion(.failure(error))
                    return
                }

                // Notify delegate
                self.delegate?.bugPlugin(didStopRecordingWith: url)

                // Show preview first, then confirmation
                DispatchQueue.main.async {
                    self.showRecordingPreview(recordingURL: url, completion: completion)
                }

            case .failure(let error):
                print("❌ QCBugPlugin: Screen recording failed: \(error.localizedDescription)")

                // Notify delegate
                self.delegate?.bugPluginDidFailRecording(error)
                completion(.failure(error))
            }
        }
    }

    func isScreenRecording() -> Bool {
        return screenRecorder?.isRecording ?? false
    }

    func isScreenRecordingOwnedByPlugin() -> Bool {
        return screenRecorder?.isRecordingOwnedByService ?? false
    }

    private func showRecordingPreview(recordingURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        print("🎬 QCBugPlugin: Showing recording preview for \(recordingURL.lastPathComponent)")

        sessionBugReportViewController?.beginChildPresentation()
        suspendFloatingUI(for: "recordingPreview")
        activePreviewMode = .recordingEditor

        let previewController = QLPreviewController()
        self.previewDataSource = SingleAttachmentPreviewDataSource(url: recordingURL)
        previewController.dataSource = self.previewDataSource
        previewController.delegate = self
        previewController.currentPreviewItemIndex = 0
        self.activePreviewController = previewController
        print("🎬 QCBugPlugin: Preview controller configured")

        guard let presenter = UIApplication.shared.topViewController() else {
            print("⚠️ QCBugPlugin: No top view controller for preview")
            self.previewDataSource = nil
            self.activePreviewController = nil
            self.activePreviewMode = .none
            self.sessionBugReportViewController?.endChildPresentation()
            // Skip preview and go directly to confirmation
            self.showRecordingConfirmation(recordingURL: recordingURL, completion: completion)
            return
        }

        print("🎬 QCBugPlugin: Presenting preview on \(type(of: presenter))")

        // Store completion for after preview dismisses
        self.pendingRecordingURL = recordingURL
        self.pendingRecordingCompletion = completion
        self.recordingPreviewPresenter = presenter

        presenter.present(previewController, animated: true) {
            print("✅ QCBugPlugin: Recording preview presentation completed")
        }
    }

    private func showRecordingConfirmation(recordingURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        print("🎬 QCBugPlugin: Showing recording confirmation dialog")
        // Prefer using the original presenter that presented the preview (stable),
        // otherwise fallback to the bug report VC or top VC. If none are available,
        // auto-add the recording to the session.
        guard let presenter = resolveRecordingConfirmationPresenter() else {
            print("⚠️ QCBugPlugin: No top view controller, auto-adding recording")
            // Fallback: auto-add if no presenter found
            recordingPreviewPresenter = nil
            self.addRecordingToSession(recordingURL: recordingURL, completion: completion)
            return
        }

        print("📱 QCBugPlugin: Presenting recording confirmation alert on \(type(of: presenter))")

        // Ensure floating UI is visible and on top while the confirmation is presented
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.floatingActionButtons?.isHidden = false
            self.bringFloatingButtonsToFront()
        }

        let alert = UIAlertController(
            title: "Add Recording",
            message: "Do you want to add this screen recording to the bug report?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            print("🗑️ QCBugPlugin: User chose to discard recording")
            // Clean up the recording file
            try? FileManager.default.removeItem(at: recordingURL)

            self?.resumeFloatingUIIfNeeded(reason: "recordingDiscarded")

            let error = NSError(
                domain: "com.qcbugplugin",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Recording discarded by user"]
            )
            completion(.failure(error))
        })

        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            print("✅ QCBugPlugin: User chose to add recording")
            self?.addRecordingToSession(recordingURL: recordingURL, completion: completion)
        })

        // Present the alert on the stable presenter. If the presenter is currently
        // in the process of being dismissed, presenting from it can fail. In that
        // case, fall back to the top view controller.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let stablePresenter: UIViewController
            if presenter.viewIfLoaded?.window != nil {
                stablePresenter = presenter
            } else if let bugVC = self.sessionBugReportViewController, bugVC.viewIfLoaded?.window != nil {
                stablePresenter = bugVC
            } else if let top = UIApplication.shared.topViewController() {
                stablePresenter = top
            } else {
                // Last resort: auto-add
                print("⚠️ QCBugPlugin: No stable presenter available; auto-adding recording")
                self.recordingPreviewPresenter = nil
                self.addRecordingToSession(recordingURL: recordingURL, completion: completion)
                return
            }

            stablePresenter.present(alert, animated: true) {
                print("✅ QCBugPlugin: Recording confirmation alert presented")
            }
            // Clear stored presenter reference now that we've used it
            self.recordingPreviewPresenter = nil
        }
    }

    private func addRecordingToSession(recordingURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        resumeFloatingUIIfNeeded(reason: "recordingAdded")

        // Create media attachment
        let attachment = MediaAttachment(type: .screenRecording, fileURL: recordingURL)
        self.sessionMediaAttachments.append(attachment)
        self.sessionBugReportViewController?.addMediaAttachment(attachment)

        // Auto-present bug report form if enabled
        let isBugReportVisible = self.sessionBugReportViewController?.viewIfLoaded?.window != nil
        if !isBugReportVisible && self.shouldAutoPresentForm {
            self.shouldAutoPresentForm = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.presentBugReport()
            }
        } else {
            // Show floating button if bug report won't be presented or is already visible
            self.floatingActionButtons?.isHidden = false
        }

        completion(.success(recordingURL))
    }

    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // Listen for window becoming key (handles rootViewController changes)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: UIWindow.didBecomeKeyNotification,
            object: nil
        )

        // Listen for window becoming visible
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeVisible),
            name: UIWindow.didBecomeVisibleNotification,
            object: nil
        )

        // Listen for view controller presentations (modals)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viewControllerDidPresent),
            name: NSNotification.Name("UIViewControllerShowDetailTargetDidChangeNotification"),
            object: nil
        )
    }

    // MARK: - Crash Detection

    private func checkForPendingCrashReports() {
        guard let crashService = crashDetectionService else { return }

        // Check after a short delay to allow UI to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            let crashReports = crashService.getPendingCrashReports()

            if crashReports.isEmpty {
                return
            }

            print("💥 QCBugPlugin: Found \(crashReports.count) pending crash report(s)")

            // Notify delegate
            self.delegate?.bugPluginDidDetectCrashes(crashReports)

            // Present crash report alert
            self.presentCrashReportAlert(crashReports: crashReports)
        }
    }

    private func presentCrashReportAlert(crashReports: [CrashReport]) {
        guard let topViewController = UIApplication.shared.topViewController() else {
            print("⚠️ QCBugPlugin: Cannot present crash alert - no top view controller")
            return
        }

        let alertController = QCCrashReportAlertController()
        alertController.delegate = self
        self.crashAlertController = alertController

        if crashReports.count == 1 {
            alertController.presentCrashReportAlert(for: crashReports[0], from: topViewController)
        } else {
            alertController.presentMultipleCrashReportsAlert(crashReports: crashReports, from: topViewController)
        }
    }

    private func reportCrash(_ crashReport: CrashReport) {
        // Create crash log attachment
        let logURL = URL(fileURLWithPath: crashReport.logFilePath)
        guard FileManager.default.fileExists(atPath: logURL.path) else {
            print("⚠️ QCBugPlugin: Crash log file not found at \(logURL.path)")
            crashDetectionService?.deleteCrashReport(crashReport)
            return
        }

        // Add crash log as attachment
        let attachment = MediaAttachment(type: .other, fileURL: logURL)
        sessionMediaAttachments.append(attachment)

        // Set crash-specific session data
        sessionBugPriority = "priority::critical"

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let timeString = formatter.string(from: crashReport.timestamp)

        var description = "**Crash Report**\n\n"
        description += "**Time:** \(timeString)\n"
        description += "**Type:** \(crashReport.crashType.rawValue)\n"

        if let exceptionName = crashReport.exceptionName {
            description += "**Exception:** \(exceptionName)\n"
        }

        if let reason = crashReport.exceptionReason {
            description += "**Reason:** \(reason)\n"
        }

        description += "\n**Device Info:**\n"
        description += "- Model: \(crashReport.deviceInfo.model)\n"
        description += "- System: \(crashReport.deviceInfo.systemName) \(crashReport.deviceInfo.systemVersion)\n"

        description += "\n**App Info:**\n"
        description += "- Bundle ID: \(crashReport.appInfo.bundleIdentifier)\n"
        description += "- Version: \(crashReport.appInfo.version) (\(crashReport.appInfo.buildNumber))\n"

        description += "\nPlease see attached crash log for full details."

        sessionBugDescription = description

        // Mark crash as handled
        crashDetectionService?.markCrashReportAsHandled(crashReport)

        // Present bug report form
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.presentBugReport()
        }
    }
    
    private func setupFloatingActionButtons() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Don't setup or re-add during preview
            if self.previewDataSource != nil {
                return
            }

            // Get the key window
            let window: UIWindow?
            if #available(iOS 13.0, *) {
                window = UIApplication.shared.windows.first { $0.isKeyWindow } ?? self.hostWindow
            } else {
                window = UIApplication.shared.keyWindow ?? self.hostWindow
            }

            guard let window = window else {
                print("⚠️ QCBugPlugin: Cannot attach floating controls without a window.")
                return
            }

            if let controls = self.floatingActionButtons {
                // Only re-add if superview is different AND buttons are not hidden
                // (Don't interfere during modal presentations like QLPreviewController)
                if controls.superview !== window && !controls.isHidden {
                    controls.removeFromSuperview()
                    window.addSubview(controls)
                    window.bringSubviewToFront(controls)
                }
                return
            }

            let controls = QCFloatingActionButtons()
            controls.delegate = self
            window.addSubview(controls)
            window.bringSubviewToFront(controls)
            self.floatingActionButtons = controls
        }
    }

    private func teardownFloatingActionButtons() {
        DispatchQueue.main.async { [weak self] in
            self?.floatingActionButtons?.removeFromSuperview()
            self?.floatingActionButtons = nil
        }
    }

    // MARK: - Shake Detection

    private func setupInternalShakeDetection() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Create internal shake-detecting window if needed
            if self.internalShakeWindow == nil {
                let shakeWindow = QCInternalShakeDetectingWindow(frame: UIScreen.main.bounds)
                shakeWindow.windowLevel = .normal - 1 // Behind everything
                shakeWindow.backgroundColor = .clear // Transparent background
                shakeWindow.isHidden = false
                shakeWindow.rootViewController = UIViewController() // Needed for shake to work
                shakeWindow.rootViewController?.view.backgroundColor = .clear
                shakeWindow.shakeHandler = { [weak self] in
                    self?.handleShakeGesture()
                }
                self.internalShakeWindow = shakeWindow
                print("✅ QCBugPlugin: Shake detection enabled for floating button backdoor")
            }
        }
    }

    private func teardownShakeDetection() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.internalShakeWindow?.shakeHandler = nil
            self.internalShakeWindow?.isHidden = true
            self.internalShakeWindow = nil
        }
    }

    private func handleShakeGesture() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let floatingButton = self.floatingActionButtons else {
                return
            }

            // Only show floating button if it's currently hidden
            if floatingButton.isHidden || floatingButton.alpha < 0.1 || floatingButton.superview == nil {
                print("🔓 QCBugPlugin: Shake detected! Showing hidden floating button (backdoor)")

                // Use haptic feedback for user confirmation
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)

                // Show the floating button
                self.showFloatingButton()
            }
        }
    }

    // MARK: - Public Floating Button Control

    func showFloatingButton() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let floatingButton = self.floatingActionButtons else {
                return
            }

            floatingButton.show(animated: true)
            floatingButton.isHidden = false
        }
    }

    // MARK: - Error Alert

    private func showErrorAlert(message: String) {
        DispatchQueue.main.async {
            guard let topViewController = UIApplication.shared.topViewController() else {
                print("⚠️ QCBugPlugin: Cannot show error alert - no top view controller")
                return
            }

            let alert = UIAlertController(
                title: "Submission Error",
                message: message,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default))

            topViewController.present(alert, animated: true)
        }
    }

    @objc private func appDidEnterBackground() {
        // Stop screen recording when app goes to background (only if owned by this service)
        if screenRecorder?.isRecordingOwnedByService == true {
            screenRecorder?.stopRecording { _ in }
        }
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        if let reason = floatingUIBlockingReason() {
            print("🪟 QCBugPlugin: Window became key - ignoring (\(reason))")
            return
        }
        print("🪟 QCBugPlugin: Window became key, preview active: \(previewDataSource != nil)")
        // Ensure floating buttons stay on top when window becomes key
        bringFloatingButtonsToFront()
    }

    @objc private func windowDidBecomeVisible(_ notification: Notification) {
        if let reason = floatingUIBlockingReason() {
            print("🪟 QCBugPlugin: Window became visible - ignoring (\(reason))")
            return
        }
        print("🪟 QCBugPlugin: Window became visible, preview active: \(previewDataSource != nil)")
        // Ensure floating buttons stay on top when window becomes visible
        bringFloatingButtonsToFront()
    }

    @objc private func viewControllerDidPresent(_ notification: Notification) {
        if let reason = floatingUIBlockingReason() {
            print("🪟 QCBugPlugin: View controller presented - ignoring (\(reason))")
            return
        }
        print("🪟 QCBugPlugin: View controller presented, preview active: \(previewDataSource != nil)")
        // Ensure floating buttons stay on top when view controllers are presented
        bringFloatingButtonsToFront()
    }

    private func floatingUIBlockingReason() -> String? {
        if isFloatingUISuspended {
            return "floatingUI-suspended"
        }

        // Ignore if preview is active
        if previewDataSource != nil {
            return "preview-active"
        }

        // Ignore if bug report form is visible
        if let bugReportVC = sessionBugReportViewController,
           bugReportVC.viewIfLoaded?.window != nil {
            let top = UIApplication.shared.topViewController().map { String(describing: type(of: $0)) } ?? "nil"
            return "bugReport-visible(top=\(top))"
        }

        // Ignore if any of our internal view controllers are presented
        guard let topVC = UIApplication.shared.topViewController() else {
            return nil
        }

        // Check if it's one of our internal view controllers
        if isInternalController(topVC) {
            return "topVC=\(String(describing: type(of: topVC)))"
        }

        // Check if it's presented by our view controllers
        if let presentingVC = topVC.presentingViewController {
            if presentingVC is QCBugReportViewController ||
               presentingVC is QCScreenshotAnnotationViewController {
                return "presentedBy=\(String(describing: type(of: presentingVC)))"
            }
        }

        return nil
    }

    private func isInternalController(_ controller: UIViewController) -> Bool {
        if controller is QCBugReportViewController ||
            controller is QCScreenshotAnnotationViewController ||
            controller is QLPreviewController ||
            controller is UIAlertController { // QCCrashReportAlertController is UIAlertController
            return true
        }

        if let nav = controller as? UINavigationController,
           let root = nav.viewControllers.first,
           isInternalController(root) {
            return true
        }

        if let presenting = controller.presentingViewController,
           isInternalController(presenting) {
            return true
        }

        return false
    }

    private func bringFloatingButtonsToFront() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let controls = self.floatingActionButtons,
                  let superview = controls.superview else {
                print("🔧 QCBugPlugin: bringFloatingButtonsToFront - no controls or superview")
                return
            }

            // Don't manipulate if buttons are hidden (e.g., during preview)
            if controls.isHidden {
                print("🔧 QCBugPlugin: bringFloatingButtonsToFront - skipped (buttons hidden)")
                return
            }

            // Don't manipulate if a preview is active
            if self.previewDataSource != nil {
                print("🔧 QCBugPlugin: bringFloatingButtonsToFront - skipped (preview active)")
                return
            }

            if self.isFloatingUISuspended {
                print("🔧 QCBugPlugin: bringFloatingButtonsToFront - skipped (UI suspended)")
                return
            }

            // Bring to front if not already the topmost subview
            if superview.subviews.last !== controls {
                print("🔧 QCBugPlugin: bringFloatingButtonsToFront - bringing to front")
                superview.bringSubviewToFront(controls)
            } else {
                print("🔧 QCBugPlugin: bringFloatingButtonsToFront - already at front")
            }
        }
    }

    private func resolveRecordingConfirmationPresenter() -> UIViewController? {
        if let presenter = recordingPreviewPresenter, presenter.viewIfLoaded?.window != nil {
            return presenter
        }

        if let bugReportVC = sessionBugReportViewController,
           bugReportVC.viewIfLoaded?.window != nil {
            return bugReportVC
        }

        if let top = UIApplication.shared.topViewController(), top.viewIfLoaded?.window != nil {
            return top
        }

        return nil
    }

    private func suspendFloatingUI(for reason: String) {
        guard !isFloatingUISuspended else { return }
        isFloatingUISuspended = true
        floatingActionButtons?.setSuspended(true)
        floatingActionButtons?.isHidden = true
        internalShakeWindow?.isHidden = true
        print("🛑 QCBugPlugin: Suspended floating UI (\(reason))")
    }

    private func resumeFloatingUIIfNeeded(reason: String? = nil) {
        let wasSuspended = isFloatingUISuspended
        isFloatingUISuspended = false
        floatingActionButtons?.setSuspended(false)

        if let reason {
            if wasSuspended {
                print("▶️ QCBugPlugin: Resumed floating UI (\(reason))")
            } else {
                print("▶️ QCBugPlugin: Evaluating floating UI visibility (\(reason))")
            }
        } else if wasSuspended {
            print("▶️ QCBugPlugin: Resumed floating UI")
        }

        evaluateFloatingUIVisibility()
    }

    private func evaluateFloatingUIVisibility(retryCount: Int = 0) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let reason = self.floatingUIBlockingReason() {
                print("🔧 QCBugPlugin: Evaluating floating UI - keeping hidden (\(reason))")
                self.floatingActionButtons?.isHidden = true
                self.internalShakeWindow?.isHidden = true
                if retryCount < 10 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                        self?.evaluateFloatingUIVisibility(retryCount: retryCount + 1)
                    }
                }
                return
            }

            self.floatingActionButtons?.isHidden = false
            self.internalShakeWindow?.isHidden = false

            if let reason = self.floatingUIBlockingReason() {
                print("🔧 QCBugPlugin: Floating UI should hide (\(reason)) - scheduling retry")
                self.floatingActionButtons?.isHidden = true
                self.internalShakeWindow?.isHidden = true
                if retryCount < 10 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.evaluateFloatingUIVisibility(retryCount: retryCount + 1)
                    }
                }
            } else {
                self.floatingActionButtons?.show(animated: false)
                self.bringFloatingButtonsToFront()
            }
        }
    }


    // MARK: - Screenshot Capture

    func captureScreenshot(completion: @escaping (Result<URL, Error>) -> Void) {
        guard let capture = screenCapture else {
            let error = NSError(
                domain: "com.qcbugplugin",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Screen capture is not available"]
            )
            completion(.failure(error))
            return
        }

        capture.captureScreen { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let url):
                DispatchQueue.main.async {
                    self.presentScreenshotAnnotationEditor(screenshotURL: url, completion: completion)
                }

            case .failure(let error):
                DispatchQueue.main.async {
                    print("❌ QCBugPlugin: Screenshot capture failed - \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func presentScreenshotAnnotationEditor(screenshotURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        if pendingScreenshotCompletion != nil {
            cleanupScreenshot(at: screenshotURL)
            print("⚠️ QCBugPlugin: Screenshot annotation already in progress")
            completion(.failure(ScreenshotAnnotationError.annotationInProgress))
            return
        }

        guard let image = UIImage(contentsOfFile: screenshotURL.path) else {
            cleanupScreenshot(at: screenshotURL)
            print("❌ QCBugPlugin: Failed to load screenshot image for annotation")
            completion(.failure(ScreenshotAnnotationError.failedToLoadImage))
            return
        }

        guard let presenter = UIApplication.shared.topViewController() else {
            cleanupScreenshot(at: screenshotURL)
            print("❌ QCBugPlugin: Unable to locate presenter for screenshot annotation")
            completion(.failure(ScreenshotAnnotationError.presentationFailed))
            return
        }

        pendingScreenshotCompletion = completion
        pendingScreenshotOriginalURL = screenshotURL

    sessionBugReportViewController?.beginChildPresentation()

        // Hide floating button before presenting annotation
        floatingActionButtons?.isHidden = true

        let annotationController = QCScreenshotAnnotationViewController(
            image: image,
            originalURL: screenshotURL
        ) { [weak self] result in
            self?.handleScreenshotAnnotationResult(result)
        }

        let navController = UINavigationController(rootViewController: annotationController)
        navController.modalPresentationStyle = .fullScreen
        presenter.present(navController, animated: true)
    }

    private func handleScreenshotAnnotationResult(_ result: Result<URL, Error>) {
        DispatchQueue.main.async {
            self.sessionBugReportViewController?.endChildPresentation()

            let completion = self.pendingScreenshotCompletion
            let originalURL = self.pendingScreenshotOriginalURL

            self.pendingScreenshotCompletion = nil
            self.pendingScreenshotOriginalURL = nil

            guard let completion else { return }

            switch result {
            case .success(let annotatedURL):
                if let originalURL,
                   originalURL != annotatedURL,
                   FileManager.default.fileExists(atPath: originalURL.path) {
                    try? FileManager.default.removeItem(at: originalURL)
                }

                let attachment = MediaAttachment(type: .screenshot, fileURL: annotatedURL)
                self.sessionMediaAttachments.append(attachment)

                self.sessionBugReportViewController?.addMediaAttachment(attachment)

                let isBugReportVisible = self.sessionBugReportViewController?.viewIfLoaded?.window != nil
                if !isBugReportVisible {
                    self.shouldAutoPresentForm = true
                    // Short delay to ensure UI is ready after dismissal
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.shouldAutoPresentForm = false
                        self.presentBugReport()
                    }
                } else {
                    // Show floating button if bug report is already visible
                    self.floatingActionButtons?.isHidden = false
                }

                print("🖍️ QCBugPlugin: Screenshot annotated and saved - \(annotatedURL)")
                completion(.success(annotatedURL))

            case .failure(let error):
                if let originalURL,
                   FileManager.default.fileExists(atPath: originalURL.path) {
                    try? FileManager.default.removeItem(at: originalURL)
                }

                // Show floating button on cancellation/failure
                self.floatingActionButtons?.isHidden = false

                print("❌ QCBugPlugin: Screenshot annotation failed - \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    private func cleanupScreenshot(at url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func presentNativeAttachmentPreview(for url: URL) {
        print("📂 QCBugPlugin: Requesting native preview for URL: \(url)")
        if !url.isFileURL {
            DispatchQueue.main.async {
                print("🌐 QCBugPlugin: Opening non-file URL in external app")
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ QCBugPlugin: Attachment preview failed - file missing at \(url.path)")
            return
        }

        DispatchQueue.main.async {
            self.sessionBugReportViewController?.beginChildPresentation()
            self.suspendFloatingUI(for: "attachmentPreview")
            print("📂 QCBugPlugin: Preparing QLPreviewController for \(url.lastPathComponent)")

            let previewController = QLPreviewController()
            self.previewDataSource = SingleAttachmentPreviewDataSource(url: url)
            previewController.dataSource = self.previewDataSource
            previewController.delegate = self
            previewController.currentPreviewItemIndex = 0
            self.activePreviewController = previewController
            self.activePreviewMode = .attachmentViewer

            guard let presenter = UIApplication.shared.topViewController() else {
                print("❌ QCBugPlugin: Unable to present attachment preview controller")
                self.previewDataSource = nil
                self.activePreviewController = nil
                self.activePreviewMode = .none
                self.sessionBugReportViewController?.endChildPresentation()
                self.resumeFloatingUIIfNeeded(reason: "attachmentPreviewNoPresenter")
                return
            }

            print("📂 QCBugPlugin: Presenting QLPreviewController on \(type(of: presenter))")
            presenter.present(previewController, animated: true) {
                let top = UIApplication.shared.topViewController().map { String(describing: type(of: $0)) } ?? "nil"
                print("📂 QCBugPlugin: QLPreviewController presented, top VC is \(top)")
            }
        }
    }
    
    // MARK: - Session Management
    
    /// Get the current session media attachments count
    func getSessionMediaCount() -> Int {
        return sessionMediaAttachments.count
    }
    
    /// Get all media attachments in the current session
    func getSessionMediaAttachments() -> [MediaAttachment] {
        return sessionMediaAttachments
    }
    
    /// Clear all media attachments in the current session
    func clearSession() {
        let count = sessionMediaAttachments.count
        sessionMediaAttachments.forEach { attachment in
            if let url = URL(string: attachment.fileURL), url.isFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        sessionMediaAttachments.removeAll()
        
        // Clear session UI state
        sessionBugDescription = ""
        sessionBugPriority = ""
        sessionBugStage = BugStage.product.rawValue
        sessionWebhookURL = nil
        sessionAssigneeUsername = nil
        sessionIssueNumber = nil

        DispatchQueue.main.async {
            self.sessionBugReportViewController?.clearMediaAttachments()
            self.sessionBugReportViewController?.restoreSessionState(
                description: "",
                priority: "",
                stage: BugStage.product.rawValue,
                webhookURL: self.resolvedWebhookURL(),
                assigneeUsername: nil,
                issueNumber: nil
            )
        }

        refreshBugReportService()
        
        // Notify delegate
        delegate?.bugPluginDidClearSession()
        
        print("🗑️ QCBugPlugin: Session cleared - \(count) media attachments removed")
    }
    
    /// Remove a specific media attachment from session by index
    func removeSessionMedia(at index: Int) {
        guard index >= 0 && index < sessionMediaAttachments.count else { return }
        let fileURL = sessionMediaAttachments[index].fileURL
        _ = removeSessionMedia(withFileURL: fileURL, updatePresentedView: true)
    }

    /// Remove a specific media attachment from session by file URL
    @discardableResult
    func removeSessionMedia(withFileURL fileURL: String, updatePresentedView: Bool = true) -> Bool {
        guard let index = sessionMediaAttachments.firstIndex(where: { $0.fileURL == fileURL }) else {
            return false
        }
        let removed = sessionMediaAttachments.remove(at: index)

        if let url = URL(string: removed.fileURL), url.isFileURL {
            try? FileManager.default.removeItem(at: url)
        }

        if updatePresentedView {
            DispatchQueue.main.async {
                self.sessionBugReportViewController?.removeMediaAttachment(withFileURL: fileURL)
            }
        }

        print("🗑️ QCBugPlugin: Removed media attachment - \(removed.fileName)")
        return true
    }
}

// MARK: - QCCrashReportAlertDelegate

extension QCBugPluginManager: QCCrashReportAlertDelegate {
    func crashReportAlertDidSelectReport(_ crashReport: CrashReport) {
        print("📝 QCBugPlugin: User selected to report crash")
        reportCrash(crashReport)
    }

    func crashReportAlertDidSelectDismiss(_ crashReport: CrashReport) {
        print("🚫 QCBugPlugin: User dismissed crash report")
        crashDetectionService?.deleteCrashReport(crashReport)

        // Notify delegate
        delegate?.bugPluginDidDismissCrash(crashReport)
    }
}

// MARK: - QCFloatingActionButtonsDelegate

extension QCBugPluginManager: QCFloatingActionButtonsDelegate {

    func floatingButtonsDidTapRecord() {
        guard let recorder = screenRecorder else {
            print("❌ QCBugPlugin: Screen recording not enabled")
            return
        }

        if recorder.isRecording {
            // Stop recording via record button
            floatingButtonsDidTapStopRecording()
        } else {
            // Start recording
            startScreenRecording { [weak self] result in
                switch result {
                case .success:
                    self?.floatingActionButtons?.updateRecordingState(isRecording: true)
                case .failure(let error):
                    print("❌ Failed to start recording: \(error)")
                }
            }
        }
    }

    func floatingButtonsDidTapStopRecording() {
        guard let recorder = screenRecorder else {
            print("❌ QCBugPlugin: Screen recording not enabled")
            return
        }

        guard recorder.isRecording else {
            print("⚠️ QCBugPlugin: No recording in progress")
            floatingActionButtons?.updateRecordingState(isRecording: false)
            return
        }

        // Stop recording and show confirmation
        shouldAutoPresentForm = true
        stopScreenRecording { [weak self] result in
            switch result {
            case .success(let url):
                print("✅ Recording stopped: \(url)")
            case .failure(let error):
                print("❌ Failed to stop recording: \(error)")
                // Reset button state on error
                self?.floatingActionButtons?.updateRecordingState(isRecording: false)
            }
        }
    }

    func floatingButtonsDidTapScreenshot() {
        captureScreenshot { result in
            switch result {
            case .success(let url):
                print("✅ Screenshot captured: \(url)")
            case .failure(let error):
                print("❌ Failed to capture screenshot: \(error)")
            }
        }
    }

    func floatingButtonsDidTapBugReport() {
        presentBugReport()
    }

    func floatingButtonsDidTapClearSession() {
        clearSession()
    }
}

// MARK: - QCBugReportViewControllerDelegate

extension QCBugPluginManager: QCBugReportViewControllerDelegate {
    func bugReportViewController(_ controller: QCBugReportViewController, didSubmitReport report: BugReport) {
        // Capture session state before submission
        self.sessionBugDescription = report.description
        self.sessionBugPriority = report.priority
        self.sessionBugStage = report.stage
        self.sessionAssigneeUsername = report.assigneeUsername
        self.sessionIssueNumber = report.issueNumber
        let userWebhookInput = controller.getSessionWebhookURL().trimmingCharacters(in: .whitespacesAndNewlines)
        if userWebhookInput.isEmpty || userWebhookInput == configuration?.webhookURL {
            self.sessionWebhookURL = nil
        } else {
            self.sessionWebhookURL = userWebhookInput
        }

        refreshBugReportService()

        guard let bugReportService = bugReportService else {
            print("❌ QCBugPlugin: No webhook URL configured. Cannot submit bug report.")
            submissionTimeoutWorkItem?.cancel()
            submissionTimeoutWorkItem = nil
            controller.dismiss(animated: true) { [weak self] in
                // Show floating buttons after dismissal
                self?.floatingActionButtons?.isHidden = false
                self?.floatingActionButtons?.hideSubmissionProgress()

                // Show error alert
                self?.showErrorAlert(message: "No webhook URL configured. Please configure the plugin with a valid webhook URL.")
            }
            return
        }

        floatingActionButtons?.showSubmissionProgress()
        submissionTimeoutWorkItem?.cancel()
        submissionTimeoutWorkItem = nil

        // Dismiss form immediately
        controller.dismiss(animated: true) { [weak self] in
            // Show floating buttons after dismissal
            self?.floatingActionButtons?.isHidden = false
        }

        // Submit in background
        let submissionTimeout: TimeInterval = 5 * 60 // 5 minutes

        bugReportService.submitBugReport(report) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.submissionTimeoutWorkItem?.cancel()
                self.submissionTimeoutWorkItem = nil
                self.floatingActionButtons?.hideSubmissionProgress()

                switch result {
                case .success(let reportId):
                    self.delegate?.bugPluginDidSubmitReport(reportId)
                    print("✅ QCBugPlugin: Bug report submitted successfully with ID: \(reportId)")

                case .failure(let error):
                    self.delegate?.bugPluginDidFailToSubmitReport(error)
                    print("❌ QCBugPlugin: Failed to submit bug report: \(error.localizedDescription)")

                    // Show error alert to user
                    self.showErrorAlert(message: "Failed to submit bug report: \(error.localizedDescription)")
                }
            }
        }

        let timeoutItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            print("⏱️ QCBugPlugin: Submission timeout reached (\(submissionTimeout) seconds)")
            self.floatingActionButtons?.hideSubmissionProgress()
            self.showErrorAlert(message: "Submission is taking longer than expected. Please try again.")
        }

        self.submissionTimeoutWorkItem = timeoutItem

        DispatchQueue.main.asyncAfter(deadline: .now() + submissionTimeout, execute: timeoutItem)
    }
    
    func bugReportViewControllerDidCancel(_ controller: QCBugReportViewController) {
        // Capture session state even on cancel so it can be restored later
        self.sessionBugDescription = controller.getSessionDescription()
        self.sessionBugPriority = controller.getSessionPriority()
        self.sessionBugStage = controller.getSessionStage()
        self.sessionAssigneeUsername = controller.getSessionAssigneeUsername()
        self.sessionIssueNumber = controller.getSessionIssueNumber()
        let userWebhookInput = controller.getSessionWebhookURL().trimmingCharacters(in: .whitespacesAndNewlines)
        if userWebhookInput.isEmpty || userWebhookInput == configuration?.webhookURL {
            self.sessionWebhookURL = nil
        } else {
            self.sessionWebhookURL = userWebhookInput
        }

        controller.dismiss(animated: true) { [weak self] in
            // Show floating buttons after dismissal
            self?.floatingActionButtons?.isHidden = false
            self?.floatingActionButtons?.hideSubmissionProgress()
            self?.submissionTimeoutWorkItem?.cancel()
            self?.submissionTimeoutWorkItem = nil
        }
    }

    func bugReportViewController(_ controller: QCBugReportViewController, requestNativePreviewFor url: URL) {
        presentNativeAttachmentPreview(for: url)
    }
}

// MARK: - QLPreviewControllerDelegate

extension QCBugPluginManager: QLPreviewControllerDelegate {
    @available(iOS 13.0, *)
    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        switch activePreviewMode {
        case .recordingEditor:
            return .updateContents
        case .attachmentViewer, .none:
            return .disabled
        }
    }

    func previewControllerWillDismiss(_ controller: QLPreviewController) {
        print("📱 QCBugPlugin: Preview controller will dismiss")

        // DON'T clear previewDataSource yet - keep it to prevent window notifications from interfering
        // We'll clear it after showing the confirmation dialog

        switch activePreviewMode {
        case .recordingEditor:
            // Check if this was a recording preview and handle it here
            // (willDismiss is more reliable than didDismiss when swiping to dismiss)
            if let recordingURL = pendingRecordingURL, let completion = pendingRecordingCompletion {
                print("🎬 QCBugPlugin: Recording preview will dismiss, preparing confirmation")

                // Clear pending recording data
                pendingRecordingURL = nil
                pendingRecordingCompletion = nil

                // Show confirmation dialog after dismissal completes
                // Keep previewDataSource set until then to prevent window notification interference
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }

                    // Now clear previewDataSource before showing confirmation
                    self.previewDataSource = nil
                    print("📱 QCBugPlugin: Cleared preview data source, showing confirmation")

                    self.showRecordingConfirmation(recordingURL: recordingURL, completion: completion)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                        self?.resumeFloatingUIIfNeeded(reason: "recordingConfirmationPresented")
                    }
                }
            } else {
                print("⚠️ QCBugPlugin: Recording preview dismissing without pending completion")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self else { return }
                    self.previewDataSource = nil
                    print("📱 QCBugPlugin: No pending completion; resuming floating UI")
                    self.resumeFloatingUIIfNeeded(reason: "recordingPreviewDismissed")
                }
            }

        case .attachmentViewer, .none:
            // Regular preview (not recording) - clear data source and show floating button
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }

                self.previewDataSource = nil
                let reason = "attachmentPreviewDismissed"
                self.pendingFloatingUIResumeReason = reason

                if self.activePreviewController !== controller {
                    print("📱 QCBugPlugin: Preview already dismissed; resuming floating UI")
                    self.pendingFloatingUIResumeReason = nil
                    self.resumeFloatingUIIfNeeded(reason: reason)
                }
            }
        }
    }

    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        print("📱 QCBugPlugin: Preview controller did dismiss")
        if activePreviewController === controller {
            activePreviewController = nil
        }

        // Note: DON'T clear previewDataSource here - it's handled in willDismiss with proper delay
        // This prevents race conditions with window notifications

        // Note: Recording confirmation is already handled in willDismiss
        // This method is just for additional cleanup and logging
        print("📱 QCBugPlugin: Preview dismissal complete")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            var handledRecordingConfirmation = false

            if self.activePreviewMode == .recordingEditor,
               let recordingURL = self.pendingRecordingURL,
               let completion = self.pendingRecordingCompletion {
                print("🎬 QCBugPlugin: Recording preview dismissal fallback triggered")
                self.pendingRecordingURL = nil
                self.pendingRecordingCompletion = nil
                self.previewDataSource = nil
                self.showRecordingConfirmation(recordingURL: recordingURL, completion: completion)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.resumeFloatingUIIfNeeded(reason: "recordingConfirmationPresentedFallback")
                }
                handledRecordingConfirmation = true
            }

            if let reason = self.pendingFloatingUIResumeReason {
                self.pendingFloatingUIResumeReason = nil
                print("📱 QCBugPlugin: Completing deferred UI resume (\(reason))")
                self.resumeFloatingUIIfNeeded(reason: reason)
            } else if !handledRecordingConfirmation, !self.isFloatingUISuspended {
                let top = UIApplication.shared.topViewController()
                let summary = top.map { String(describing: type(of: $0)) } ?? "none"
                print("📱 QCBugPlugin: Preview dismissal complete - top VC: \(summary)")

                if let top, self.isInternalController(top) {
                    print("📱 QCBugPlugin: Top controller internal; evaluating visibility")
                    self.evaluateFloatingUIVisibility()
                } else {
                    print("📱 QCBugPlugin: Top controller external; resuming floating UI")
                    self.resumeFloatingUIIfNeeded(reason: "previewDismissed")
                }
            }

            self.activePreviewMode = .none
            self.sessionBugReportViewController?.endChildPresentation()
        }
    }
}

// MARK: - UIApplication Extension

private extension UIApplication {
    func topViewController() -> UIViewController? {
        // iOS 12 compatible keyWindow access
        let keyWindow: UIWindow?
        if #available(iOS 13.0, *) {
            keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
        } else {
            keyWindow = UIApplication.shared.keyWindow
        }
        
        var topViewController = keyWindow?.rootViewController
        
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        
        if let navigationController = topViewController as? UINavigationController {
            topViewController = navigationController.topViewController
        }
        
        if let tabBarController = topViewController as? UITabBarController {
            topViewController = tabBarController.selectedViewController
        }
        
        return topViewController
    }
}

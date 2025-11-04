//
//  QCBugPluginManager.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import UIKit

/// Main manager class for the QC Bug Plugin
public final class QCBugPluginManager: QCBugPluginProtocol {
    
    // MARK: - Singleton
    public static let shared = QCBugPluginManager()
    
    // MARK: - Private Properties
    private var configuration: QCBugPluginConfig?
    private var uiTracker: UITrackingProtocol?
    private var screenRecorder: ScreenRecordingProtocol?
    private var screenCapture: ScreenCaptureProtocol?
    private var bugReportService: BugReportProtocol?
    private var isConfigured: Bool = false
    private var floatingButton: QCFloatingButton?
    private var floatingActionButtons: QCFloatingActionButtons?
    private var sessionMediaAttachments: [MediaAttachment] = []
    private var shouldAutoPresentForm: Bool = false
    private var sessionBugReportViewController: QCBugReportViewController?
    private var sessionBugDescription: String = ""
    private var sessionBugPriority: BugPriority = .medium
    private var sessionBugCategory: BugCategory = .other
    
    // MARK: - Public Properties
    public weak var delegate: QCBugPluginDelegate?
    
    // MARK: - Initialization
    private init() {
        setupNotificationObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - QCBugPluginProtocol Implementation
    
    public func configure(webhookURL: String, apiKey: String?) {
        let config = QCBugPluginConfig(
            webhookURL: webhookURL,
            apiKey: apiKey
        )
        configure(with: config)
    }
    
    public func configure(with config: QCBugPluginConfig) {
        self.configuration = config

        // Initialize services
        self.uiTracker = UITrackingService()
        self.uiTracker?.maxActionHistoryCount = config.maxActionHistoryCount

        if config.isScreenRecordingEnabled {
            self.screenRecorder = ScreenRecordingService()
        }

        // Initialize screen capture service
        self.screenCapture = ScreenCaptureService()

        self.bugReportService = BugReportAPIService(
            webhookURL: config.webhookURL,
            apiKey: config.apiKey
        )

        // Setup floating action buttons if enabled
        if config.enableFloatingButton {
            setupFloatingActionButtons()
        }

        self.isConfigured = true

        print("✅ QCBugPlugin configured successfully")
    }
    
    public func startTracking() {
        guard isConfigured else {
            print("❌ QCBugPlugin: Plugin not configured. Call configure() first.")
            return
        }
        
        uiTracker?.startTracking()
        
        NotificationCenter.default.post(
            name: .qcBugPluginDidStartTracking,
            object: self
        )
        
        delegate?.bugPluginDidStartTracking(self)
        
        print("🎯 QCBugPlugin: Started tracking user interactions")
    }
    
    public func stopTracking() {
        uiTracker?.stopTracking()

        // Stop screen recording if active and owned by this service
        if screenRecorder?.isRecordingOwnedByService == true {
            screenRecorder?.stopRecording { _ in }
        }

        NotificationCenter.default.post(
            name: .qcBugPluginDidStopTracking,
            object: self
        )

        delegate?.bugPluginDidStopTracking(self)

        print("⏹️ QCBugPlugin: Stopped tracking user interactions")
    }
    
    public func presentBugReport() {
        guard isConfigured else {
            print("❌ QCBugPlugin: Plugin not configured. Call configure() first.")
            return
        }

        // Check delegate permission
        if let shouldPresent = delegate?.bugPluginShouldPresentBugReport(self),
           !shouldPresent {
            return
        }

        let actionHistory = uiTracker?.getActionHistory() ?? []

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
                    configuration: self.configuration
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
                category: self.sessionBugCategory
            )

            // Present modally
            if let topViewController = UIApplication.shared.topViewController() {
                let navController = UINavigationController(rootViewController: bugReportVC)
                navController.modalPresentationStyle = .formSheet
                if #available(iOS 15.0, *) {
                    if let sheet = navController.sheetPresentationController {
                        sheet.detents = [.medium(), .large()]
                    }
                }
                topViewController.present(navController, animated: true)
            }
        }
    }
    
    public func isTrackingEnabled() -> Bool {
        return uiTracker?.isTracking ?? false
    }
    
    public func setCustomData(_ data: [String: Any]) {
        guard let config = configuration else { return }

        // Update configuration with new custom data
        let newConfig = QCBugPluginConfig(
            webhookURL: config.webhookURL,
            apiKey: config.apiKey,
            customData: data,
            isScreenRecordingEnabled: config.isScreenRecordingEnabled,
            maxActionHistoryCount: config.maxActionHistoryCount,
            enableFloatingButton: config.enableFloatingButton
        )
        
        self.configuration = newConfig
    }
    
    public func setScreenRecordingEnabled(_ enabled: Bool) {
        guard let config = configuration else { return }

        let newConfig = QCBugPluginConfig(
            webhookURL: config.webhookURL,
            apiKey: config.apiKey,
            customData: config.customData,
            isScreenRecordingEnabled: enabled,
            maxActionHistoryCount: config.maxActionHistoryCount,
            enableFloatingButton: config.enableFloatingButton
        )

        self.configuration = newConfig

        if enabled && screenRecorder == nil {
            screenRecorder = ScreenRecordingService()
        } else if !enabled {
            screenRecorder = nil
        }
    }

    public func startScreenRecording(completion: @escaping (Result<Void, Error>) -> Void) {
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
                // Notify delegate and post notification
                self.delegate?.bugPluginDidStartRecording(self)
                NotificationCenter.default.post(
                    name: .qcBugPluginDidStartRecording,
                    object: self
                )
                print("🎥 QCBugPlugin: Screen recording started")
                completion(.success(()))

            case .failure(let error):
                // Notify delegate and post notification
                self.delegate?.bugPlugin(self, didFailRecordingWithError: error)
                NotificationCenter.default.post(
                    name: .qcBugPluginDidFailRecording,
                    object: self,
                    userInfo: ["error": error]
                )
                completion(.failure(error))
            }
        }
    }

    public func stopScreenRecording(completion: @escaping (Result<URL, Error>) -> Void) {
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

            switch result {
            case .success(let url):
                // Create media attachment
                let attachment = MediaAttachment(type: .screenRecording, fileURL: url)
                self.sessionMediaAttachments.append(attachment)
                DispatchQueue.main.async {
                    self.sessionBugReportViewController?.addMediaAttachment(attachment)
                }

                // Update floating button state
                self.floatingActionButtons?.updateRecordingState(isRecording: false)

                // Notify delegate and post notification
                self.delegate?.bugPlugin(self, didStopRecordingWithURL: url)
                NotificationCenter.default.post(
                    name: .qcBugPluginDidStopRecording,
                    object: self,
                    userInfo: ["url": url]
                )
                print("🎬 QCBugPlugin: Screen recording stopped - \(url)")

                // Auto-present bug report form if enabled
                if self.shouldAutoPresentForm {
                    self.shouldAutoPresentForm = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.presentBugReport()
                    }
                }

                completion(.success(url))

            case .failure(let error):
                // Notify delegate and post notification
                self.delegate?.bugPlugin(self, didFailRecordingWithError: error)
                NotificationCenter.default.post(
                    name: .qcBugPluginDidFailRecording,
                    object: self,
                    userInfo: ["error": error]
                )
                completion(.failure(error))
            }
        }
    }

    public func isScreenRecording() -> Bool {
        return screenRecorder?.isRecording ?? false
    }

    public func isScreenRecordingOwnedByPlugin() -> Bool {
        return screenRecorder?.isRecordingOwnedByService ?? false
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    private func setupFloatingButton() {
        #if DEBUG
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.floatingButton == nil {
                self.floatingButton = QCFloatingButton()
                self.floatingButton?.addTarget(
                    self,
                    action: #selector(self.floatingButtonTapped),
                    for: .touchUpInside
                )

                // iOS 12 compatible window access
                if #available(iOS 13.0, *) {
                    if let window = UIApplication.shared.windows.first {
                        window.addSubview(self.floatingButton!)
                    }
                } else {
                    if let window = UIApplication.shared.keyWindow {
                        window.addSubview(self.floatingButton!)
                    }
                }
            }
        }
        #endif
    }

    private func setupFloatingActionButtons() {
        #if DEBUG
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.floatingActionButtons == nil {
                self.floatingActionButtons = QCFloatingActionButtons()
                self.floatingActionButtons?.delegate = self

                // iOS 12 compatible window access
                if #available(iOS 13.0, *) {
                    if let window = UIApplication.shared.windows.first {
                        window.addSubview(self.floatingActionButtons!)
                    }
                } else {
                    if let window = UIApplication.shared.keyWindow {
                        window.addSubview(self.floatingActionButtons!)
                    }
                }
            }
        }
        #endif
    }

    @objc private func floatingButtonTapped() {
        presentBugReport()
    }
    
    @objc private func appDidEnterBackground() {
        // Stop screen recording when app goes to background (only if owned by this service)
        if screenRecorder?.isRecordingOwnedByService == true {
            screenRecorder?.stopRecording { _ in }
        }
    }

    @objc private func appWillEnterForeground() {
        // Resume tracking if it was enabled
        if let tracker = uiTracker, tracker.isTracking {
            // Tracking continues automatically
        }
    }

    // MARK: - Screenshot Capture

    public func captureScreenshot(completion: @escaping (Result<URL, Error>) -> Void) {
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
                // Create media attachment
                let attachment = MediaAttachment(type: .screenshot, fileURL: url)
                self.sessionMediaAttachments.append(attachment)
                DispatchQueue.main.async {
                    self.sessionBugReportViewController?.addMediaAttachment(attachment)
                }

                print("📸 QCBugPlugin: Screenshot captured - \(url)")

                // Auto-present bug report form
                self.shouldAutoPresentForm = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.shouldAutoPresentForm = false
                    self.presentBugReport()
                }

                completion(.success(url))

            case .failure(let error):
                print("❌ QCBugPlugin: Screenshot capture failed - \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Session Management
    
    /// Get the current session media attachments count
    public func getSessionMediaCount() -> Int {
        return sessionMediaAttachments.count
    }
    
    /// Get all media attachments in the current session
    public func getSessionMediaAttachments() -> [MediaAttachment] {
        return sessionMediaAttachments
    }
    
    /// Clear all media attachments in the current session
    public func clearSession() {
        let count = sessionMediaAttachments.count
        sessionMediaAttachments.forEach { attachment in
            if let url = URL(string: attachment.fileURL), url.isFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        sessionMediaAttachments.removeAll()
        
        // Clear session UI state
        sessionBugDescription = ""
        sessionBugPriority = .medium
        sessionBugCategory = .other
        
        DispatchQueue.main.async {
            self.sessionBugReportViewController?.clearMediaAttachments()
            self.sessionBugReportViewController?.restoreSessionState(
                description: "",
                priority: .medium,
                category: .other
            )
        }
        
        // Notify delegate
        delegate?.bugPluginDidClearSession(self)
        
        // Post notification
        NotificationCenter.default.post(
            name: .qcBugPluginDidClearSession,
            object: self,
            userInfo: ["count": count]
        )
        
        print("🗑️ QCBugPlugin: Session cleared - \(count) media attachments removed")
    }
    
    /// Remove a specific media attachment from session by index
    public func removeSessionMedia(at index: Int) {
        guard index >= 0 && index < sessionMediaAttachments.count else { return }
        let fileURL = sessionMediaAttachments[index].fileURL
        _ = removeSessionMedia(withFileURL: fileURL, updatePresentedView: true)
    }

    /// Remove a specific media attachment from session by file URL
    @discardableResult
    public func removeSessionMedia(withFileURL fileURL: String, updatePresentedView: Bool = true) -> Bool {
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

// MARK: - QCFloatingActionButtonsDelegate

extension QCBugPluginManager: QCFloatingActionButtonsDelegate {

    public func floatingButtonsDidTapRecord() {
        guard let recorder = screenRecorder else {
            print("❌ QCBugPlugin: Screen recording not enabled")
            return
        }

        if recorder.isRecording {
            // Stop recording
            shouldAutoPresentForm = true
            stopScreenRecording { result in
                switch result {
                case .success(let url):
                    print("✅ Recording stopped: \(url)")
                case .failure(let error):
                    print("❌ Failed to stop recording: \(error)")
                }
            }
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

    public func floatingButtonsDidTapScreenshot() {
        captureScreenshot { result in
            switch result {
            case .success(let url):
                print("✅ Screenshot captured: \(url)")
            case .failure(let error):
                print("❌ Failed to capture screenshot: \(error)")
            }
        }
    }

    public func floatingButtonsDidTapBugReport() {
        presentBugReport()
    }
    
    public func floatingButtonsDidTapClearSession() {
        clearSession()
    }
}

// MARK: - QCBugReportViewControllerDelegate

extension QCBugPluginManager: QCBugReportViewControllerDelegate {
    public func bugReportViewController(_ controller: QCBugReportViewController, didSubmitReport report: BugReport) {
        // Capture session state before submission
        self.sessionBugDescription = report.description
        self.sessionBugPriority = report.priority
        self.sessionBugCategory = report.category
        
        bugReportService?.submitBugReport(report) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let reportId):
                    self.delegate?.bugPlugin(self, didSubmitBugReport: reportId)
                    
                    NotificationCenter.default.post(
                        name: .qcBugPluginDidSubmitReport,
                        object: self,
                        userInfo: ["reportId": reportId]
                    )
                    
                    print("✅ QCBugPlugin: Bug report submitted successfully with ID: \(reportId)")
                    
                case .failure(let error):
                    self.delegate?.bugPlugin(self, didFailToSubmitBugReport: error)
                    
                    NotificationCenter.default.post(
                        name: .qcBugPluginDidFailToSubmitReport,
                        object: self,
                        userInfo: ["error": error]
                    )
                    
                    print("❌ QCBugPlugin: Failed to submit bug report: \(error.localizedDescription)")
                }
                
                controller.dismiss(animated: true)
            }
        }
    }
    
    public func bugReportViewControllerDidCancel(_ controller: QCBugReportViewController) {
        // Capture session state even on cancel so it can be restored later
        self.sessionBugDescription = controller.getSessionDescription()
        self.sessionBugPriority = controller.getSessionPriority()
        self.sessionBugCategory = controller.getSessionCategory()
        
        controller.dismiss(animated: true)
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

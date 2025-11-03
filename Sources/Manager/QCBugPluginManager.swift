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
    private var bugReportService: BugReportProtocol?
    private var isConfigured: Bool = false
    private var floatingButton: QCFloatingButton?
    
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
        
        self.bugReportService = BugReportAPIService(
            webhookURL: config.webhookURL,
            apiKey: config.apiKey
        )
        
        // Setup floating button if enabled
        if config.enableFloatingButton {
            setupFloatingButton()
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
        
        // Stop screen recording if active
        if screenRecorder?.isRecording == true {
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
            
            let bugReportVC = QCBugReportViewController(
                actionHistory: actionHistory,
                screenRecorder: self.screenRecorder,
                configuration: self.configuration
            )
            
            bugReportVC.delegate = self
            
            // Present modally
            if let topViewController = UIApplication.shared.topViewController() {
                let navController = UINavigationController(rootViewController: bugReportVC)
                navController.modalPresentationStyle = .fullScreen
                topViewController.present(navController, animated: true)
            }
        }
    }
    
    public func isTrackingEnabled() -> Bool {
        return uiTracker?.isTracking ?? false
    }
    
    public func setCustomData(_ data: [String: Any]) {
        guard var config = configuration else { return }
        
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
        guard var config = configuration else { return }
        
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
    
    @objc private func floatingButtonTapped() {
        presentBugReport()
    }
    
    @objc private func appDidEnterBackground() {
        // Stop screen recording when app goes to background
        if screenRecorder?.isRecording == true {
            screenRecorder?.stopRecording { _ in }
        }
    }
    
    @objc private func appWillEnterForeground() {
        // Resume tracking if it was enabled
        if let tracker = uiTracker, tracker.isTracking {
            // Tracking continues automatically
        }
    }
}

// MARK: - QCBugReportViewControllerDelegate

extension QCBugPluginManager: QCBugReportViewControllerDelegate {
    public func bugReportViewController(_ controller: QCBugReportViewController, didSubmitReport report: BugReport) {
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
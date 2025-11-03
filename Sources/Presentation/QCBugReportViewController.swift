//
//  QCBugReportViewController.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import UIKit
import WebKit

/// Delegate protocol for bug report view controller
public protocol QCBugReportViewControllerDelegate: AnyObject {
    func bugReportViewController(_ controller: QCBugReportViewController, didSubmitReport report: BugReport)
    func bugReportViewControllerDidCancel(_ controller: QCBugReportViewController)
}

/// View controller for displaying the bug report interface
public final class QCBugReportViewController: UIViewController {
    
    // MARK: - Properties
    public weak var delegate: QCBugReportViewControllerDelegate?
    
    private let actionHistory: [UserAction]
    private let screenRecorder: ScreenRecordingProtocol?
    private let configuration: QCBugPluginConfiguration?
    
    private var webView: WKWebView!
    private var isRecording = false
    private var recordingURL: URL?
    
    // Bug report data
    private var bugDescription = ""
    private var selectedPriority: BugPriority = .medium
    private var selectedCategory: BugCategory = .other
    private var shouldRecordScreen = false
    
    // MARK: - Initialization
    
    public init(
        actionHistory: [UserAction],
        screenRecorder: ScreenRecordingProtocol?,
        configuration: QCBugPluginConfiguration?
    ) {
        self.actionHistory = actionHistory
        self.screenRecorder = screenRecorder
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupWebView()
        loadBugReportInterface()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        // iOS 12 compatible background color
        if #available(iOS 13.0, *) {
            view.backgroundColor = UIColor.systemBackground
        } else {
            view.backgroundColor = UIColor.white
        }
        title = "Report Bug"
        
        // Navigation items
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Submit",
            style: .done,
            target: self,
            action: #selector(submitTapped)
        )
        navigationItem.rightBarButtonItem?.isEnabled = false
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        let userController = WKUserContentController()
        
        // Add message handlers for JS -> Native communication
        userController.add(self, name: "bugReportHandler")
        userController.add(self, name: "recordingHandler")
        
        configuration.userContentController = userController
        configuration.preferences.javaScriptEnabled = true
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadBugReportInterface() {
        let htmlContent = generateBugReportHTML()
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    // MARK: - Actions
    
    @objc private func cancelTapped() {
        delegate?.bugReportViewControllerDidCancel(self)
    }
    
    @objc private func submitTapped() {
        let report = createBugReport()
        delegate?.bugReportViewController(self, didSubmitReport: report)
    }
    
    // MARK: - Bug Report Creation
    
    private func createBugReport() -> BugReport {
        let deviceInfo = DeviceInfo()
        let appInfo = AppInfo()
        let customData = configuration?.customData.compactMapValues { "\($0)" } ?? [:]
        
        return BugReport(
            description: bugDescription,
            priority: selectedPriority,
            category: selectedCategory,
            userActions: actionHistory,
            deviceInfo: deviceInfo,
            appInfo: appInfo,
            screenRecordingURL: recordingURL?.absoluteString,
            customData: customData,
            currentScreen: getCurrentScreenName(),
            networkInfo: NetworkInfo(),
            memoryInfo: MemoryInfo()
        )
    }
    
    private func getCurrentScreenName() -> String? {
        return navigationController?.visibleViewController?.title ??
               navigationController?.visibleViewController?.navigationItem.title
    }
}

// MARK: - WKScriptMessageHandler

extension QCBugReportViewController: WKScriptMessageHandler {
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        switch message.name {
        case "bugReportHandler":
            handleBugReportMessage(message)
        case "recordingHandler":
            handleRecordingMessage(message)
        default:
            break
        }
    }
    
    private func handleBugReportMessage(_ message: WKScriptMessage) {
        guard let data = message.body as? [String: Any] else { return }
        
        let action = data["action"] as? String ?? ""
        
        switch action {
        case "updateDescription":
            bugDescription = data["description"] as? String ?? ""
            updateSubmitButtonState()
            
        case "updatePriority":
            if let priorityString = data["priority"] as? String,
               let priority = BugPriority(rawValue: priorityString) {
                selectedPriority = priority
            }
            
        case "updateCategory":
            if let categoryString = data["category"] as? String,
               let category = BugCategory(rawValue: categoryString) {
                selectedCategory = category
            }
            
        case "updateRecordingOption":
            shouldRecordScreen = data["enabled"] as? Bool ?? false
            
        default:
            break
        }
    }
    
    private func handleRecordingMessage(_ message: WKScriptMessage) {
        guard let data = message.body as? [String: Any],
              let action = data["action"] as? String else { return }
        
        switch action {
        case "startRecording":
            startScreenRecording()
        case "stopRecording":
            stopScreenRecording()
        default:
            break
        }
    }
    
    private func updateSubmitButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = !bugDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Screen Recording

extension QCBugReportViewController {
    
    private func startScreenRecording() {
        guard let recorder = screenRecorder else { return }

        // Check if already recording using the service's state
        guard !recorder.isRecording else {
            // If recording is already active, just update UI to reflect this
            isRecording = true
            updateRecordingState(isRecording: true)
            return
        }

        recorder.startRecording { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, let recorder = self.screenRecorder else { return }

                switch result {
                case .success:
                    // Sync local state with service state
                    self.isRecording = recorder.isRecordingOwnedByService
                    self.updateRecordingState(isRecording: self.isRecording)

                case .failure(let error):
                    self.showErrorAlert(message: "Failed to start recording: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func stopScreenRecording() {
        guard let recorder = screenRecorder, isRecording else { return }

        // Only attempt to stop if we own the recording
        guard recorder.isRecordingOwnedByService else {
            // Recording not owned by service, just update UI
            isRecording = false
            updateRecordingState(isRecording: false)
            showErrorAlert(message: "Cannot stop recording that was started externally")
            return
        }

        recorder.stopRecording { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                self.isRecording = false
                self.updateRecordingState(isRecording: false)

                switch result {
                case .success(let url):
                    self.recordingURL = url
                    self.updateRecordingURL(url.absoluteString)

                case .failure(let error):
                    self.showErrorAlert(message: "Failed to stop recording: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func updateRecordingState(isRecording: Bool) {
        let script = "updateRecordingState(\(isRecording))"
        webView.evaluateJavaScript(script)
    }
    
    private func updateRecordingURL(_ url: String) {
        let script = "updateRecordingURL('\(url)')"
        webView.evaluateJavaScript(script)
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate

extension QCBugReportViewController: WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Inject action history data
        injectActionHistory()
        
        // Configure recording availability
        injectRecordingAvailability()
    }
    
    private func injectActionHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(actionHistory)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            
            let script = "loadActionHistory(\(jsonString))"
            webView.evaluateJavaScript(script)
        } catch {
            print("Failed to inject action history: \(error)")
        }
    }
    
    private func injectRecordingAvailability() {
        let isAvailable = screenRecorder?.isAvailable ?? false
        let script = "setRecordingAvailability(\(isAvailable))"
        webView.evaluateJavaScript(script)
    }
}
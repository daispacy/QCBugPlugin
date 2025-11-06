//
//  QCBugReportViewController.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import UIKit
import WebKit

enum GitLabDefaults {
    static let jwtKey = "com.qcbugplugin.gitlab.jwt"
    static let userIdKey = "com.qcbugplugin.gitlab.userid"
}

/// Delegate protocol for bug report view controller
public protocol QCBugReportViewControllerDelegate: AnyObject {
    func bugReportViewController(_ controller: QCBugReportViewController, didSubmitReport report: BugReport)
    func bugReportViewControllerDidCancel(_ controller: QCBugReportViewController)
    func bugReportViewController(_ controller: QCBugReportViewController, requestNativePreviewFor url: URL)
}

/// View controller for displaying the bug report interface
public final class QCBugReportViewController: UIViewController {
    
    // MARK: - Properties
    public weak var delegate: QCBugReportViewControllerDelegate?
    
    private var actionHistory: [UserAction]
    private let screenRecorder: ScreenRecordingProtocol?
    private let configuration: QCBugPluginConfiguration?
    
    var webView: WKWebView!
    var mediaAttachments: [MediaAttachment] = []
    var isWebViewLoaded = false
    var gitLabAuthProvider: GitLabAuthProviding?
    var isFetchingGitLabCredentials = false
    var didInjectGitLabCredentials = false
    var pendingGitLabCredentialScript: String?
    var gitLabJWT: String?
    var gitLabUserId: Int?
    var isGitLabLoginInProgress = false
    var shouldSubmitAfterGitLabLogin = false
    
    // Bug report data
    private var bugDescription = ""
    private var selectedPriority: BugPriority = .medium
    private var selectedCategory: BugCategory = .other
    private var webhookURL: String
    
    // MARK: - Initialization
    
    public init(
        actionHistory: [UserAction],
        screenRecorder: ScreenRecordingProtocol?,
        configuration: QCBugPluginConfiguration?,
        gitLabAuthProvider: GitLabAuthProviding? = nil
    ) {
        self.actionHistory = actionHistory
        self.screenRecorder = screenRecorder
        self.configuration = configuration
        self.webhookURL = configuration?.webhookURL ?? ""
        let defaults = UserDefaults.standard
        self.gitLabJWT = defaults.string(forKey: GitLabDefaults.jwtKey)
        if let storedUserId = defaults.object(forKey: GitLabDefaults.userIdKey) as? Int {
            self.gitLabUserId = storedUserId
        }
        if let injectedProvider = gitLabAuthProvider {
            self.gitLabAuthProvider = injectedProvider
        } else if let gitLabConfig = configuration?.gitLabAppConfig {
            self.gitLabAuthProvider = GitLabAuthService(configuration: gitLabConfig)
        }
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
        isWebViewLoaded = false
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
        isWebViewLoaded = false
        didInjectGitLabCredentials = false
        isFetchingGitLabCredentials = false
        pendingGitLabCredentialScript = nil
        if let resource = bugReportHTMLResource() {
            webView.loadHTMLString(resource.html, baseURL: resource.baseURL)
        } else {
            webView.loadHTMLString(bugReportHTMLFallback(), baseURL: nil)
        }
    }
    
    // MARK: - Actions
    
    @objc private func cancelTapped() {
        delegate?.bugReportViewControllerDidCancel(self)
    }
    
    @objc private func submitTapped() {
        guard !isGitLabLoginInProgress else { return }

        if gitLabAuthProvider != nil && gitLabJWT == nil {
            shouldSubmitAfterGitLabLogin = true
            requestGitLabAuthentication(triggeredBySubmit: true)
            return
        }

        let report = createBugReport()
        delegate?.bugReportViewController(self, didSubmitReport: report)
    }
    
    // MARK: - Bug Report Creation
    
    private func createBugReport() -> BugReport {
        let deviceInfo = DeviceInfo()
        let appInfo = AppInfo()
        let customData = configuration?.customData.compactMapValues { "\($0)" } ?? [:]
        let gitLabCredentials: GitLabCredentials? = {
            guard let token = gitLabJWT else { return nil }
            return GitLabCredentials(pat: token)
        }()

        return BugReport(
            description: bugDescription,
            priority: selectedPriority,
            category: selectedCategory,
            userActions: actionHistory,
            deviceInfo: deviceInfo,
            appInfo: appInfo,
            customData: customData,
            currentScreen: getCurrentScreenName(),
            networkInfo: NetworkInfo(),
            memoryInfo: MemoryInfo(),
            mediaAttachments: mediaAttachments,
            gitLabCredentials: gitLabCredentials
        )
    }

    private func requestGitLabAuthentication(triggeredBySubmit: Bool = false) {
        guard let provider = gitLabAuthProvider else {
            if triggeredBySubmit {
                shouldSubmitAfterGitLabLogin = false
                let report = createBugReport()
                delegate?.bugReportViewController(self, didSubmitReport: report)
            }
            emitGitLabState(
                token: nil,
                header: nil,
                userId: nil,
                requiresLogin: false,
                isLoading: false,
                error: "GitLab integration is not configured."
            )
            return
        }

        guard !isGitLabLoginInProgress else { return }
        isGitLabLoginInProgress = true

        if triggeredBySubmit {
            shouldSubmitAfterGitLabLogin = true
        }

        emitGitLabState(
            token: gitLabJWT,
            header: gitLabJWT.map { "Bearer \($0)" },
            userId: gitLabUserId,
            requiresLogin: false,
            isLoading: true,
            error: nil
        )

        provider.authenticateInteractively(from: self) { [weak self] result in
            guard let self = self else { return }
            self.isGitLabLoginInProgress = false

            switch result {
            case .success(let authorization):
                self.gitLabJWT = authorization.jwt
                self.gitLabUserId = authorization.userId
                self.persistGitLabCredentials(
                    token: authorization.jwt,
                    userId: authorization.userId
                )
                self.didInjectGitLabCredentials = false
                self.emitGitLabState(
                    token: authorization.jwt,
                    header: authorization.authorizationHeader.trimmingCharacters(in: .whitespacesAndNewlines),
                    userId: authorization.userId,
                    requiresLogin: false,
                    isLoading: false,
                    error: nil
                )

                if self.shouldSubmitAfterGitLabLogin {
                    self.shouldSubmitAfterGitLabLogin = false
                    let report = self.createBugReport()
                    self.delegate?.bugReportViewController(self, didSubmitReport: report)
                }

            case .failure(let error):
                self.gitLabJWT = nil
                self.gitLabUserId = nil
                self.clearStoredGitLabCredentials()
                if triggeredBySubmit {
                    self.shouldSubmitAfterGitLabLogin = false
                }

                let requiresLogin: Bool
                let errorMessage: String?

                switch error {
                case .authenticationCancelled:
                    requiresLogin = true
                    errorMessage = nil
                case .userAuthenticationRequired:
                    requiresLogin = true
                    errorMessage = nil
                default:
                    requiresLogin = true
                    errorMessage = error.localizedDescription
                }

                self.emitGitLabState(
                    token: nil,
                    header: nil,
                    userId: nil,
                    requiresLogin: requiresLogin,
                    isLoading: false,
                    error: errorMessage
                )

                if triggeredBySubmit {
                    switch error {
                    case .authenticationCancelled:
                        break
                    default:
                        self.showGitLabAuthAlert(message: errorMessage ?? "Please sign in to GitLab to continue.")
                    }
                }
            }
        }
    }

    private func performGitLabLogout() {
        shouldSubmitAfterGitLabLogin = false
        isGitLabLoginInProgress = false

        gitLabAuthProvider?.clearCache()
        QCBugPluginManager.shared.invalidateGitLabSession()

        gitLabJWT = nil
        gitLabUserId = nil

        clearStoredGitLabCredentials()

        emitGitLabState(
            token: nil,
            header: nil,
            userId: nil,
            requiresLogin: true,
            isLoading: false,
            error: nil
        )
    }

    private func showGitLabAuthAlert(message: String) {
        let alert = UIAlertController(title: "GitLab Sign In Required", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Media Attachments

    internal func addMediaAttachment(_ attachment: MediaAttachment) {
        mediaAttachments.append(attachment)
        guard isViewLoaded else { return }
        let script = mediaAttachmentScript(for: attachment)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isWebViewLoaded else { return }
            self.webView.evaluateJavaScript(script)
        }
    }

    internal func removeMediaAttachment(withFileURL fileURL: String) {
        mediaAttachments.removeAll { $0.fileURL == fileURL }
    }
    
    internal func clearMediaAttachments() {
        mediaAttachments.removeAll()
        guard isViewLoaded else { return }
        let script = """
        if (typeof capturedMedia !== 'undefined' && Array.isArray(capturedMedia)) {
            capturedMedia.splice(0, capturedMedia.length);
            updateMediaList();
        }
        """
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isWebViewLoaded else { return }
            self.webView.evaluateJavaScript(script)
        }
    }
    
    // MARK: - Session State Management
    
    internal func updateActionHistory(_ newHistory: [UserAction]) {
        actionHistory = newHistory
        guard isViewLoaded else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isWebViewLoaded else { return }
            self.injectActionHistory()
        }
    }
    
    internal func restoreSessionState(
        description: String,
        priority: BugPriority,
        category: BugCategory,
        webhookURL: String? = nil
    ) {
        bugDescription = description
        selectedPriority = priority
        selectedCategory = category
        if let webhookURL = webhookURL {
            self.webhookURL = webhookURL
        }
        guard isViewLoaded else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isWebViewLoaded else { return }
            self.injectFormState()
        }
    }
    
    internal func getSessionDescription() -> String {
        return bugDescription
    }
    
    internal func getSessionPriority() -> BugPriority {
        return selectedPriority
    }
    
    internal func getSessionCategory() -> BugCategory {
        return selectedCategory
    }

    internal func getSessionWebhookURL() -> String {
        return webhookURL
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

        case "updateWebhookURL":
            let value = (data["webhookURL"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            webhookURL = value
        
        case "deleteMediaAttachment":
            if let fileURL = data["fileURL"] as? String {
                removeMediaAttachment(withFileURL: fileURL)
                QCBugPluginManager.shared.removeSessionMedia(withFileURL: fileURL, updatePresentedView: false)
            }

        case "previewAttachment":
            if let fileURLString = data["fileURL"] as? String,
               let url = URL(string: fileURLString) {
                delegate?.bugReportViewController(self, requestNativePreviewFor: url)
            }

        case "gitlabLogin":
            requestGitLabAuthentication(triggeredBySubmit: false)

        case "gitlabLogout":
            performGitLabLogout()
            
        default:
            break
        }
    }
    
    private func updateSubmitButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = !bugDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - WKNavigationDelegate

extension QCBugReportViewController: WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isWebViewLoaded = true
        // Inject action history data
        injectActionHistory()
        
        // Inject media attachments
        injectMediaAttachments()
        
        // Inject form state
        injectFormState()

        // Resolve GitLab credentials for embedded UI when needed
        injectGitLabAccessTokenIfNeeded()
        executePendingGitLabInjectionScriptIfNeeded()
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
    
    private func injectMediaAttachments() {
        guard !mediaAttachments.isEmpty else { return }
        
        for attachment in mediaAttachments {
            let script = mediaAttachmentScript(for: attachment)
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("Failed to inject media attachment: \(error)")
                }
            }
        }
    }
    
    private func injectFormState() {
        let escapedDescription = bugDescription
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        let escapedWebhookURL = webhookURL
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let script = """
        (function() {
            const descriptionField = document.getElementById('bugDescription');
            if (descriptionField) {
                descriptionField.value = '\(escapedDescription)';
            }
            const priorityField = document.getElementById('prioritySelect');
            if (priorityField) {
                priorityField.value = '\(selectedPriority.rawValue)';
            }
            const categoryField = document.getElementById('categorySelect');
            if (categoryField) {
                categoryField.value = '\(selectedCategory.rawValue)';
            }
            const webhookField = document.getElementById('webhookURL');
            if (webhookField) {
                webhookField.value = '\(escapedWebhookURL)';
            }
            if (typeof updateDescription === 'function') { updateDescription(); }
            if (typeof updatePriority === 'function') { updatePriority(); }
            if (typeof updateCategory === 'function') { updateCategory(); }
            if (typeof updateWebhookURL === 'function') { updateWebhookURL(); }
        })();
        """
        webView.evaluateJavaScript(script)
    }
    
    private func mediaAttachmentScript(for attachment: MediaAttachment) -> String {
        let mediaType: String
        switch attachment.type {
        case .screenRecording:
            mediaType = "screenRecording"
        case .screenshot:
            mediaType = "screenshot"
        }
        let fileName = attachment.fileName
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let fileURL = attachment.fileURL
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return """
        addMediaAttachment({
            type: '\(mediaType)',
            fileURL: '\(fileURL)',
            fileName: '\(fileName)'
        });
        """
    }
}
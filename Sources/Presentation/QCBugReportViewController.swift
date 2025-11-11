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

/// Delegate protocol for bug report view controller
protocol QCBugReportViewControllerDelegate: AnyObject {
    func bugReportViewController(_ controller: QCBugReportViewController, didSubmitReport report: BugReport)
    func bugReportViewControllerDidCancel(_ controller: QCBugReportViewController)
    func bugReportViewController(_ controller: QCBugReportViewController, requestNativePreviewFor url: URL)
}

/// View controller for displaying the bug report interface
final class QCBugReportViewController: UIViewController {
    
    // MARK: - Properties
    weak var delegate: QCBugReportViewControllerDelegate?
    
    private var actionHistory: [UserAction]
    private let screenRecorder: ScreenRecordingProtocol?
    let configuration: QCBugPluginConfig?
    
    var webView: WKWebView!
    var mediaAttachments: [MediaAttachment] = []
    var isWebViewLoaded = false
    var gitLabAuthProvider: GitLabAuthProviding?
    var isFetchingGitLabCredentials = false
    var didInjectGitLabCredentials = false
    var pendingGitLabCredentialScript: String?
    var gitLabJWT: String?
    var gitLabUsername: String?
    var isGitLabLoginInProgress = false
    var shouldSubmitAfterGitLabLogin = false

    // Track if view controller was explicitly dismissed (via cancel/submit)
    private var wasExplicitlyDismissed = false
    private var isPresentingChildController = false

    // Bug report data
    private var bugDescription = ""
    private var selectedPriority: String = ""
    private var selectedStage: String = BugStage.product.rawValue
    private var webhookURL: String
    private var selectedAssigneeUsername: String?
    private var issueNumber: Int?
    var gitLabProject: String?
    
    // MARK: - Initialization
    
    init(
        actionHistory: [UserAction],
        screenRecorder: ScreenRecordingProtocol?,
        configuration: QCBugPluginConfig?,
        gitLabAuthProvider: GitLabAuthProviding? = nil
    ) {
        self.actionHistory = actionHistory
        self.screenRecorder = screenRecorder
        self.configuration = configuration
    self.webhookURL = configuration?.webhookURL ?? ""
    self.gitLabProject = Self.normalizedGitLabProject(from: configuration?.gitLabAppConfig?.project)
    let sessionStore = GitLabSessionStore.shared
    self.gitLabJWT = sessionStore.currentJWT()
    self.gitLabUsername = sessionStore.currentUsername()
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupWebView()
        loadBugReportInterface()
        isWebViewLoaded = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Reset GitLab login state as safety measure
        // This handles edge cases where AWS session closes without calling completion
        if isGitLabLoginInProgress {
            print("⚠️ QCBugPlugin: Resetting stuck GitLab login state on view appear")
            isGitLabLoginInProgress = false
            emitGitLabState(
                token: gitLabJWT,
                header: gitLabJWT.map { "Bearer \($0)" },
                username: gitLabUsername,
                requiresLogin: gitLabJWT == nil,
                isLoading: false,
                error: nil
            )
        }

        // Reset dismissal flag when view appears
        wasExplicitlyDismissed = false
        // Clear child presentation flag once we're back on screen
        isPresentingChildController = false
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // If view was dismissed without explicit cancel/submit (e.g., by tapping outside),
        // notify delegate to restore floating button and save session state
        if isPresentingChildController {
            return
        }

        if !wasExplicitlyDismissed {
            delegate?.bugReportViewControllerDidCancel(self)
        }
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

    // MARK: - Child Presentation Management

    func beginChildPresentation() {
        isPresentingChildController = true
    }

    func endChildPresentation() {
        isPresentingChildController = false
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
        wasExplicitlyDismissed = true
        delegate?.bugReportViewControllerDidCancel(self)
    }
    
    @objc private func submitTapped() {
        showSubmitConfirmation()
    }

    private func showSubmitConfirmation() {
        let alert = UIAlertController(
            title: "Submit Bug Report",
            message: "Are you sure you want to submit this bug report?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Submit", style: .default) { [weak self] _ in
            self?.performSubmit()
        })

        present(alert, animated: true)
    }

    private func performSubmit() {
        if gitLabAuthProvider != nil && gitLabJWT == nil {
            shouldSubmitAfterGitLabLogin = true
            requestGitLabAuthentication(triggeredBySubmit: true)
            return
        }

        let report = createBugReport()
        wasExplicitlyDismissed = true
        delegate?.bugReportViewController(self, didSubmitReport: report)
    }

    // MARK: - Bug Report Creation
    
    private func createBugReport() -> BugReport {
        let deviceInfo = DeviceInfo()
        let appInfo = AppInfo()
        let customData = configuration?.customData.compactMapValues { "\($0)" } ?? [:]
        let gitLabCredentials: GitLabCredentials? = {
            guard let token = gitLabJWT else { return nil }
            return GitLabCredentials(pat: token, project: gitLabProject)
        }()

        return BugReport(
            description: bugDescription,
            priority: selectedPriority,
            stage: selectedStage,
            userActions: actionHistory,
            deviceInfo: deviceInfo,
            appInfo: appInfo,
            customData: customData,
            currentScreen: getCurrentScreenName(),
            networkInfo: NetworkInfo(),
            memoryInfo: MemoryInfo(),
            mediaAttachments: mediaAttachments,
            gitLabProject: gitLabProject,
            assigneeUsername: selectedAssigneeUsername,
            issueNumber: issueNumber,
            gitLabCredentials: gitLabCredentials
        )
    }

    private func requestGitLabAuthentication(triggeredBySubmit: Bool = false) {
        guard let provider = gitLabAuthProvider else {
            if triggeredBySubmit {
                shouldSubmitAfterGitLabLogin = false
                let report = createBugReport()
                wasExplicitlyDismissed = true
                delegate?.bugReportViewController(self, didSubmitReport: report)
            }
            emitGitLabState(
                token: nil,
                header: nil,
                username: nil,
                requiresLogin: false,
                isLoading: false,
                error: "GitLab integration is not configured."
            )
            return
        }

        // Allow retry if login was stuck or session closed unexpectedly
        // Reset state if already in progress to allow fresh login attempt
        if isGitLabLoginInProgress {
            print("⚠️ QCBugPlugin: Previous GitLab login still in progress, resetting state to allow retry")
        }
        isGitLabLoginInProgress = true

        if triggeredBySubmit {
            shouldSubmitAfterGitLabLogin = true
        }

        emitGitLabState(
            token: gitLabJWT,
            header: gitLabJWT.map { "Bearer \($0)" },
            username: gitLabUsername,
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
                self.gitLabUsername = authorization.username
                let trimmedHeader = authorization.authorizationHeader.trimmingCharacters(in: .whitespacesAndNewlines)
                if let project = Self.normalizedGitLabProject(from: authorization.project) {
                    self.gitLabProject = project
                } else if self.gitLabProject == nil {
                    self.gitLabProject = Self.normalizedGitLabProject(from: self.configuration?.gitLabAppConfig?.project)
                }
                self.didInjectGitLabCredentials = false
                self.emitGitLabState(
                    token: authorization.jwt,
                    header: trimmedHeader,
                    username: authorization.username,
                    requiresLogin: false,
                    isLoading: false,
                    error: nil
                )

                // Auto-fetch members after successful login
                if let project = self.gitLabProject {
                    self.fetchAndInjectGitLabMembers(project: project)
                }

                if self.shouldSubmitAfterGitLabLogin {
                    self.shouldSubmitAfterGitLabLogin = false
                    let report = self.createBugReport()
                    self.wasExplicitlyDismissed = true
                    self.delegate?.bugReportViewController(self, didSubmitReport: report)
                }

            case .failure(let error):
                self.gitLabJWT = nil
                self.gitLabUsername = nil
                self.clearStoredGitLabCredentials()
                self.gitLabAuthProvider?.clearCache()
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
                    username: nil,
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
        gitLabUsername = nil

        clearStoredGitLabCredentials()

        emitGitLabState(
            token: nil,
            header: nil,
            username: nil,
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

    private func fetchAndInjectGitLabMembers(project: String) {
        guard let provider = gitLabAuthProvider else { return }

        print("🔍 QCBugPlugin: Fetching GitLab members for project: \(project)")

        provider.fetchProjectMembers(project: project) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let members):
                    print("✅ QCBugPlugin: Fetched \(members.count) GitLab members")
                    self.injectGitLabMembers(members)
                    // Priority refetch is now handled automatically by emitGitLabState()

                case .failure(let error):
                    print("❌ QCBugPlugin: Failed to fetch GitLab members: \(error.localizedDescription)")
                }
            }
        }
    }

    internal func triggerPriorityRefetch() {
        let script = """
        (function() {
            if (typeof window.refetchPriorities === 'function') {
                window.refetchPriorities();
                console.log('✅ Triggered priority refetch');
            } else {
                console.warn('⚠️ window.refetchPriorities function not found');
            }
        })();
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("❌ QCBugPlugin: Failed to trigger priority refetch - \(error.localizedDescription)")
            } else {
                print("✅ QCBugPlugin: Triggered priority refetch")
            }
        }
    }

    private func injectGitLabMembers(_ members: [GitLabMember]) {
        let usernames = members.map { $0.username }
        let jsonData: [[String: String]] = members.map { member in
            return ["username": member.username, "name": member.name]
        }

        guard let jsonString = try? JSONSerialization.data(withJSONObject: jsonData, options: []),
              let escapedJSON = String(data: jsonString, encoding: .utf8) else {
            print("❌ QCBugPlugin: Failed to serialize GitLab members")
            return
        }

        let script = """
        (function() {
            if (typeof window.updateGitLabMembers === 'function') {
                window.updateGitLabMembers(\(escapedJSON));
                console.log('✅ Injected \(usernames.count) GitLab members');
            } else {
                console.warn('⚠️ window.updateGitLabMembers function not found');
            }
        })();
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("❌ QCBugPlugin: Failed to inject GitLab members - \(error.localizedDescription)")
            } else {
                print("✅ QCBugPlugin: Injected \(usernames.count) GitLab members into web view")
            }
        }
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
        priority: String,
        stage: String? = nil,
        webhookURL: String? = nil,
        assigneeUsername: String? = nil,
        issueNumber: Int? = nil
    ) {
        bugDescription = description
        selectedPriority = priority
        selectedStage = stage ?? BugStage.product.rawValue
        if let webhookURL = webhookURL {
            self.webhookURL = webhookURL
        }
        selectedAssigneeUsername = assigneeUsername
        self.issueNumber = issueNumber
        guard isViewLoaded else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isWebViewLoaded else { return }
            self.injectFormState()
        }
    }
    
    internal func getSessionDescription() -> String {
        return bugDescription
    }
    
    internal func getSessionPriority() -> String {
        return selectedPriority
    }

    internal func getSessionStage() -> String {
        return selectedStage
    }

    internal func getSessionWebhookURL() -> String {
        return webhookURL
    }

    internal func getSessionAssigneeUsername() -> String? {
        return selectedAssigneeUsername
    }

    internal func getSessionIssueNumber() -> Int? {
        return issueNumber
    }

    internal static func normalizedGitLabProject(from value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
    
    private func getCurrentScreenName() -> String? {
        return navigationController?.visibleViewController?.title ??
               navigationController?.visibleViewController?.navigationItem.title
    }
}

// MARK: - WKScriptMessageHandler

extension QCBugReportViewController: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
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
            if let priorityString = data["priority"] as? String {
                selectedPriority = priorityString
            }

        case "updateStage":
            if let stageString = data["stage"] as? String {
                selectedStage = stageString
            }

        case "updateWebhookURL":
            let value = (data["webhookURL"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            webhookURL = value

        case "updateAssignee":
            if let username = data["username"] as? String {
                let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
                selectedAssigneeUsername = trimmed.isEmpty ? nil : trimmed
            } else {
                selectedAssigneeUsername = nil
            }

        case "updateIssueNumber":
            if let number = data["issueNumber"] as? Int {
                issueNumber = number >= 0 ? number : nil
            } else if let stringValue = data["issueNumber"] as? String, let parsed = Int(stringValue) {
                issueNumber = parsed >= 0 ? parsed : nil
            } else {
                issueNumber = nil
            }
        
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

        case "logMessage":
            if let message = data["message"] as? String, !message.isEmpty {
                print("🪵 QCBugPlugin WebView: \(message)")
            }
            
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
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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
        let escapedAssignee = (selectedAssigneeUsername ?? "")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let issueNumberString = issueNumber.map(String.init) ?? ""
        let script = """
        (function() {
            const descriptionField = document.getElementById('bugDescription');
            if (descriptionField) {
                descriptionField.value = '\(escapedDescription)';
            }
            const webhookField = document.getElementById('webhookURL');
            if (webhookField) {
                webhookField.value = '\(escapedWebhookURL)';
            }
            if (typeof setInitialAssignee === 'function') { setInitialAssignee('\(escapedAssignee)'); }
            if (typeof setInitialPriority === 'function') { setInitialPriority('\(selectedPriority)'); }
            if (typeof setInitialStage === 'function') { setInitialStage('\(selectedStage)'); }
            if (typeof setInitialIssueNumber === 'function') { setInitialIssueNumber('\(issueNumberString)'); }
            if (typeof updateDescription === 'function') { updateDescription(); }
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
        case .other:
            mediaType = "other"
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

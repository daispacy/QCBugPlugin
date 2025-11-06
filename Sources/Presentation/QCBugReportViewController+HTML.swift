//
//  QCBugReportViewController+HTML.swift
//  QCBugPlugin
//
//  Created by GitHub Copilot on 11/5/25.
//

import Foundation

struct BugReportHTMLResource {
    let html: String
    let baseURL: URL
}

extension QCBugReportViewController {
    func bugReportHTMLResource() -> BugReportHTMLResource? {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: QCBugReportViewController.self)
        #endif

        guard let htmlURL = bundle.url(forResource: "bug_report", withExtension: "html") else {
            print("❌ QCBugPlugin: Missing bug_report.html resource")
            return nil
        }

        do {
            let html = try String(contentsOf: htmlURL, encoding: .utf8)
            return BugReportHTMLResource(html: html, baseURL: htmlURL.deletingLastPathComponent())
        } catch {
            print("❌ QCBugPlugin: Failed to load bug_report.html - \(error.localizedDescription)")
            return nil
        }
    }

    func bugReportHTMLFallback() -> String {
        return """
        <!DOCTYPE html>
        <html lang=\"en\">
        <head>
            <meta charset=\"UTF-8\">
            <title>Bug Report</title>
        </head>
        <body>
            <h1>Bug Report</h1>
            <p>Unable to load the bug report interface.</p>
        </body>
        </html>
        """
    }

    func injectGitLabAccessTokenIfNeeded() {
        if didInjectGitLabCredentials {
            executePendingGitLabInjectionScriptIfNeeded()
            return
        }

        if gitLabAuthProvider == nil {
            guard !didInjectGitLabCredentials else { return }
            guard let token = gitLabJWT else {
                emitGitLabState(
                    token: nil,
                    header: nil,
                    username: nil,
                    requiresLogin: false,
                    isLoading: false,
                    error: nil
                )
                return
            }
            let headerValue = "Bearer \(token)"
            emitGitLabState(
                token: token,
                header: headerValue,
                username: gitLabUsername,
                requiresLogin: false,
                isLoading: false,
                error: nil
            )
            return
        }

        guard !isFetchingGitLabCredentials else { return }
        guard let provider = gitLabAuthProvider else { return }

        isFetchingGitLabCredentials = true

        emitGitLabState(
            token: gitLabJWT,
            header: gitLabJWT.map { "Bearer \($0)" },
            username: gitLabUsername,
            requiresLogin: false,
            isLoading: true,
            error: nil
        )

        provider.fetchAuthorization { [weak self] result in
            guard let self = self else { return }
            self.isFetchingGitLabCredentials = false

            switch result {
            case .success(let authorization):
                let trimmedHeader = authorization.authorizationHeader.trimmingCharacters(in: .whitespacesAndNewlines)
                let jwt = authorization.jwt
                self.gitLabJWT = jwt
                self.gitLabUsername = authorization.username
                self.emitGitLabState(
                    token: jwt,
                    header: trimmedHeader,
                    username: authorization.username,
                    requiresLogin: false,
                    isLoading: false,
                    error: nil
                )

            case .failure(let error):
                self.gitLabJWT = nil
                self.gitLabUsername = nil
                self.clearStoredGitLabCredentials()
                self.gitLabAuthProvider?.clearCache()
                let requiresLogin: Bool
                switch error {
                case .userAuthenticationRequired:
                    requiresLogin = true
                default:
                    requiresLogin = true
                }
                let errorMessage = requiresLogin ? nil : error.localizedDescription
                self.emitGitLabState(
                    token: nil,
                    header: nil,
                    username: nil,
                    requiresLogin: requiresLogin,
                    isLoading: false,
                    error: errorMessage
                )
            }
        }
    }

    func executePendingGitLabInjectionScriptIfNeeded() {
        guard let script = pendingGitLabCredentialScript else { return }
        if isViewLoaded, isWebViewLoaded {
            pendingGitLabCredentialScript = nil
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("❌ QCBugPlugin: Failed to inject pending GitLab credentials - \(error.localizedDescription)")
                }
            }
        }
    }

    private func executeGitLabInjectionScript(_ script: String) {
        if isViewLoaded, isWebViewLoaded {
            pendingGitLabCredentialScript = nil
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("❌ QCBugPlugin: Failed to inject GitLab credentials - \(error.localizedDescription)")
                } else {
                    print("✅ QCBugPlugin: Injected GitLab credentials into web view")
                }
            }
        } else {
            pendingGitLabCredentialScript = script
        }
    }

    func emitGitLabState(
        token: String?,
        header: String?,
        username: String?,
        requiresLogin: Bool,
        isLoading: Bool,
        error: String?
    ) {
        let script = makeGitLabCredentialScript(
            token: token,
            header: header,
            username: username,
            error: error,
            requiresLogin: requiresLogin,
            isLoading: isLoading
        )
        didInjectGitLabCredentials = true
        executeGitLabInjectionScript(script)
    }

    private func makeGitLabCredentialScript(
        token: String?,
        header: String?,
        username: String?,
        error: String?,
        requiresLogin: Bool,
        isLoading: Bool
    ) -> String {
        let tokenValue = token.map { "'\(sanitizeForJavaScript($0))'" } ?? "null"
        let headerValue = header.map { "'\(sanitizeForJavaScript($0))'" } ?? "null"
        let usernameValue = username.map { "'\(sanitizeForJavaScript($0))'" } ?? "null"
        let errorValue = error.map { "'\(sanitizeForJavaScript($0))'" } ?? "null"
        let requiresLoginValue = requiresLogin ? "true" : "false"
        let isAuthenticatedValue = (!requiresLogin && token != nil) ? "true" : "false"
        let isLoadingValue = isLoading ? "true" : "false"

        return """
        (function() {
            window.qcBugGitLab = window.qcBugGitLab || {};
            window.qcBugGitLab.accessToken = \(tokenValue);
            window.qcBugGitLab.pat = \(tokenValue);
            window.qcBugGitLab.authorizationHeader = \(headerValue);
            window.qcBugGitLab.username = \(usernameValue);
            window.qcBugGitLab.error = \(errorValue);
            window.qcBugGitLab.requiresLogin = \(requiresLoginValue);
            window.qcBugGitLab.isAuthenticated = \(isAuthenticatedValue);
            window.qcBugGitLab.isLoading = \(isLoadingValue);
            if (typeof window.onGitLabAuthReady === 'function') {
                try {
                    window.onGitLabAuthReady(window.qcBugGitLab);
                } catch (callbackError) {
                    console.error('onGitLabAuthReady failed', callbackError);
                }
            }
        })();
        """
    }

    private func sanitizeForJavaScript(_ value: String) -> String {
        var escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "'", with: "\\'")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
        escaped = escaped.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
        escaped = escaped.replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return escaped
    }

    func clearStoredGitLabCredentials() {
        GitLabSessionStore.shared.clearAll()
    }
}

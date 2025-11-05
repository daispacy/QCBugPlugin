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

        guard !isFetchingGitLabCredentials else { return }
        guard let provider = gitLabAuthProvider else { return }

        isFetchingGitLabCredentials = true

        provider.fetchAuthorizationHeader { [weak self] result in
            guard let self = self else { return }
            self.isFetchingGitLabCredentials = false

            switch result {
            case .success(let header):
                let trimmedHeader = header.trimmingCharacters(in: .whitespacesAndNewlines)
                let token = self.extractToken(fromAuthorizationHeader: trimmedHeader)
                let script = self.makeGitLabCredentialScript(token: token, header: trimmedHeader, error: nil)
                self.didInjectGitLabCredentials = true
                self.executeGitLabInjectionScript(script)

            case .failure(let error):
                let script = self.makeGitLabCredentialScript(token: nil, header: nil, error: error.localizedDescription)
                self.didInjectGitLabCredentials = true
                self.executeGitLabInjectionScript(script)
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

    private func makeGitLabCredentialScript(token: String?, header: String?, error: String?) -> String {
        let tokenValue = token.map { "'\(sanitizeForJavaScript($0))'" } ?? "null"
        let headerValue = header.map { "'\(sanitizeForJavaScript($0))'" } ?? "null"
        let errorValue = error.map { "'\(sanitizeForJavaScript($0))'" } ?? "null"

        return """
        (function() {
            window.qcBugGitLab = window.qcBugGitLab || {};
            window.qcBugGitLab.accessToken = \(tokenValue);
            window.qcBugGitLab.authorizationHeader = \(headerValue);
            window.qcBugGitLab.error = \(errorValue);
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
        escaped = escaped.replacingOccurrences(of: "\u2028", with: "\\u2028")
        escaped = escaped.replacingOccurrences(of: "\u2029", with: "\\u2029")
        return escaped
    }

    private func extractToken(fromAuthorizationHeader header: String) -> String {
        let components = header.split(separator: " ")
        if components.count > 1, let lastComponent = components.last {
            return String(lastComponent)
        }
        return header
    }
}

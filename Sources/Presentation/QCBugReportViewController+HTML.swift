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
}

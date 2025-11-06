//
//  BugReportProtocol.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation

/// Protocol for bug report submission
protocol BugReportProtocol: AnyObject {
    /// Submit a bug report
    /// - Parameter report: The bug report to submit
    /// - Returns: Result with report ID or error
    func submitBugReport(_ report: BugReport, completion: @escaping (Result<String, BugReportError>) -> Void)
    
    /// Upload a file as part of bug report
    /// - Parameters:
    ///   - fileURL: Local file URL
    ///   - reportId: Associated report ID
    /// - Returns: Result with file ID or error
    func uploadFile(_ fileURL: URL, for reportId: String, completion: @escaping (Result<String, BugReportError>) -> Void)
}

/// Bug report specific errors
enum BugReportError: Error, LocalizedError {
    case invalidURL
    case invalidData
    case networkError(String)
    case serverError(Int, String)
    case fileUploadFailed(String)
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid webhook URL"
        case .invalidData:
            return "Invalid bug report data"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .fileUploadFailed(let message):
            return "File upload failed: \(message)"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}
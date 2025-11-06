//
//  ScreenCaptureProtocol.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/4/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import UIKit

/// Protocol for screen capture functionality
protocol ScreenCaptureProtocol: AnyObject {
    /// Capture current screen as image
    /// - Returns: Result with screenshot URL or error
    func captureScreen(completion: @escaping (Result<URL, ScreenCaptureError>) -> Void)

    /// Capture specific view as image
    /// - Parameters:
    ///   - view: The view to capture
    /// - Returns: Result with screenshot URL or error
    func captureView(_ view: UIView, completion: @escaping (Result<URL, ScreenCaptureError>) -> Void)

    /// Clean up old screenshot files
    func cleanupScreenshots()
}

/// Screen capture specific errors
enum ScreenCaptureError: Error, LocalizedError {
    case captureFailed(String)
    case savingFailed(String)
    case invalidView

    var errorDescription: String? {
        switch self {
        case .captureFailed(let message):
            return "Screen capture failed: \(message)"
        case .savingFailed(let message):
            return "Failed to save screenshot: \(message)"
        case .invalidView:
            return "Invalid view for capture"
        }
    }
}

//
//  ScreenshotAnnotationError.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/4/25.
//

import Foundation

/// Errors that can occur during screenshot annotation flow
enum ScreenshotAnnotationError: Error {
    case cancelled
    case failedToLoadImage
    case failedToSaveImage
    case presentationFailed
    case annotationInProgress
}

extension ScreenshotAnnotationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Screenshot annotation was cancelled."
        case .failedToLoadImage:
            return "Unable to load screenshot for annotation."
        case .failedToSaveImage:
            return "Failed to save annotated screenshot."
        case .presentationFailed:
            return "Unable to present the annotation interface."
        case .annotationInProgress:
            return "Another screenshot annotation is already in progress."
        }
    }
}

//
//  MediaAttachment.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/4/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation

/// Represents a media attachment (screenshot or video recording)
struct MediaAttachment: Codable {
    /// Type of media attachment
    let type: MediaType

    /// File URL of the media
    let fileURL: String

    /// File name
    let fileName: String

    /// Timestamp when the media was captured
    let timestamp: Date

    /// File size in bytes
    let fileSize: Int64?

    init(type: MediaType, fileURL: URL, fileSize: Int64? = nil) {
        self.type = type
        self.fileURL = fileURL.absoluteString
        self.fileName = fileURL.lastPathComponent
        self.timestamp = Date()
        self.fileSize = fileSize
    }
}

/// Types of media attachments
enum MediaType: String, Codable {
    case screenshot = "screenshot"
    case screenRecording = "screen_recording"
    case other = "other"

    var displayName: String {
        switch self {
        case .screenshot:
            return "Screenshot"
        case .screenRecording:
            return "Screen Recording"
        case .other:
            return "Attachment"
        }
    }

    var mimeType: String {
        switch self {
        case .screenshot:
            return "image/png"
        case .screenRecording:
            return "video/mp4"
        case .other:
            return "application/octet-stream"
        }
    }
}

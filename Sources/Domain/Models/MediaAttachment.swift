//
//  MediaAttachment.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/4/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation

/// Represents a media attachment (screenshot or video recording)
public struct MediaAttachment: Codable {
    /// Type of media attachment
    public let type: MediaType

    /// File URL of the media
    public let fileURL: String

    /// File name
    public let fileName: String

    /// Timestamp when the media was captured
    public let timestamp: Date

    /// File size in bytes
    public let fileSize: Int64?

    public init(type: MediaType, fileURL: URL, fileSize: Int64? = nil) {
        self.type = type
        self.fileURL = fileURL.absoluteString
        self.fileName = fileURL.lastPathComponent
        self.timestamp = Date()
        self.fileSize = fileSize
    }
}

/// Types of media attachments
public enum MediaType: String, Codable {
    case screenshot = "screenshot"
    case screenRecording = "screen_recording"

    public var displayName: String {
        switch self {
        case .screenshot:
            return "Screenshot"
        case .screenRecording:
            return "Screen Recording"
        }
    }

    public var mimeType: String {
        switch self {
        case .screenshot:
            return "image/png"
        case .screenRecording:
            return "video/mp4"
        }
    }
}

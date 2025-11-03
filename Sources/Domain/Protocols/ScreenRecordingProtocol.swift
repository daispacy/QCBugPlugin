//
//  ScreenRecordingProtocol.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation

/// Protocol for screen recording functionality
public protocol ScreenRecordingProtocol: AnyObject {
    /// Check if screen recording is available on the device
    var isAvailable: Bool { get }
    
    /// Check if currently recording
    var isRecording: Bool { get }

    /// Check if the current recording was started by this service instance
    /// Returns false if recording was started externally (e.g., Control Center)
    var isRecordingOwnedByService: Bool { get }

    /// Start screen recording
    /// - Returns: Result with success/failure
    func startRecording(completion: @escaping (Result<Void, ScreenRecordingError>) -> Void)
    
    /// Stop screen recording
    /// - Returns: Result with video URL or error
    func stopRecording(completion: @escaping (Result<URL, ScreenRecordingError>) -> Void)
    
    /// Request recording permission
    func requestPermission(completion: @escaping (Bool) -> Void)
}

/// Screen recording specific errors
public enum ScreenRecordingError: Error, LocalizedError {
    case notAvailable
    case alreadyRecording
    case notRecording
    case permissionDenied
    case recordingFailed(String)
    case savingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Screen recording is not available on this device"
        case .alreadyRecording:
            return "Screen recording is already in progress"
        case .notRecording:
            return "No screen recording in progress"
        case .permissionDenied:
            return "Screen recording permission denied"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .savingFailed(let message):
            return "Failed to save recording: \(message)"
        }
    }
}
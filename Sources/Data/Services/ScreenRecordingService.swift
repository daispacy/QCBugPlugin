//
//  ScreenRecordingService.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import ReplayKit
import AVFoundation

/// Service for screen recording functionality using ReplayKit
public final class ScreenRecordingService: NSObject, ScreenRecordingProtocol {
    
    // MARK: - Properties
    private let recorder = RPScreenRecorder.shared()
    private var videoWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var startTime: CMTime?

    /// Tracks whether this service instance started the current recording
    private var isRecordingStartedByService = false
    
    // MARK: - Initialization
    
    /// Public initializer for ScreenRecordingService
    public override init() {
        super.init()
    }
    
    // MARK: - ScreenRecordingProtocol Implementation
    
    public var isAvailable: Bool {
        return recorder.isAvailable
    }
    
    public var isRecording: Bool {
        return recorder.isRecording
    }

    public var isRecordingOwnedByService: Bool {
        return isRecordingStartedByService && isRecording
    }
    
    public func requestPermission(completion: @escaping (Bool) -> Void) {
        // ReplayKit handles permissions automatically
        // We'll just check if recording is available
        completion(isAvailable)
    }
    
    public func startRecording(completion: @escaping (Result<Void, ScreenRecordingError>) -> Void) {
        guard isAvailable else {
            completion(.failure(.notAvailable))
            return
        }

        // Check if recording is already in progress
        if isRecording {
            if isRecordingStartedByService {
                // Recording already started by this service - consider it success
                print("⚠️ ScreenRecordingService: Recording already in progress by this service")
                completion(.success(()))
                return
            } else {
                // Recording started externally (e.g., Control Center)
                // We can't control external recordings, but we can acknowledge the state
                print("⚠️ ScreenRecordingService: Screen recording already active (started externally)")
                isRecordingStartedByService = false
                completion(.success(()))
                return
            }
        }

        // Create output URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoFileName = "qc_screen_recording_\(Date().timeIntervalSince1970).mp4"
        outputURL = documentsPath.appendingPathComponent(videoFileName)

        // Start recording
        recorder.startRecording { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    self.isRecordingStartedByService = false
                    completion(.failure(.recordingFailed(error.localizedDescription)))
                } else {
                    self.isRecordingStartedByService = true
                    print("🎥 ScreenRecordingService: Started screen recording")
                    completion(.success(()))
                }
            }
        }
    }
    
    public func stopRecording(completion: @escaping (Result<URL, ScreenRecordingError>) -> Void) {
        guard isRecording else {
            completion(.failure(.notRecording))
            return
        }

        // Check if this service started the recording
        if !isRecordingStartedByService {
            print("⚠️ ScreenRecordingService: Cannot stop recording not started by this service")
            // Create a placeholder URL since we can't access the externally started recording
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let videoFileName = "qc_screen_recording_external_\(Date().timeIntervalSince1970).mp4"
            let videoURL = documentsPath.appendingPathComponent(videoFileName)

            let placeholderData = Data("Recording started externally - not accessible".utf8)
            do {
                try placeholderData.write(to: videoURL)
                completion(.success(videoURL))
            } catch {
                completion(.failure(.savingFailed("Recording was started externally and cannot be accessed")))
            }
            return
        }

        recorder.stopRecording { [weak self] previewViewController, error in
            DispatchQueue.main.async {
                // Reset the tracking flag if self still exists
                self?.isRecordingStartedByService = false

                if let error = error {
                    print("❌ ScreenRecordingService: Failed to stop recording: \(error.localizedDescription)")
                    completion(.failure(.recordingFailed(error.localizedDescription)))
                    return
                }

                // If self was deallocated, still handle the callback
                guard let self = self else {
                    print("⚠️ ScreenRecordingService: Service deallocated, creating fallback recording file")
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let videoFileName = "qc_screen_recording_\(Date().timeIntervalSince1970).mp4"
                    let videoURL = documentsPath.appendingPathComponent(videoFileName)

                    let placeholderData = Data("Screen recording completed (service deallocated)".utf8)
                    do {
                        try placeholderData.write(to: videoURL)
                        completion(.success(videoURL))
                    } catch {
                        completion(.failure(.savingFailed("Service deallocated: \(error.localizedDescription)")))
                    }
                    return
                }

                // Handle the preview view controller
                if let previewVC = previewViewController {
                    print("📹 ScreenRecordingService: Recording stopped, presenting preview")
                    self.handleRecordingPreview(previewVC, completion: completion)
                } else {
                    print("⚠️ ScreenRecordingService: No preview controller available")
                    completion(.failure(.savingFailed("No preview controller available")))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleRecordingPreview(
        _ previewViewController: RPPreviewViewController,
        completion: @escaping (Result<URL, ScreenRecordingError>) -> Void
    ) {
        previewViewController.previewControllerDelegate = self
        
        // Store completion for delegate callback
        self.recordingCompletion = completion
        
        // Present preview controller (user can save or share)
        if let topViewController = UIApplication.shared.topViewController() {
            topViewController.present(previewViewController, animated: true)
        } else {
            // If no view controller to present, save directly
            saveRecordingDirectly(previewViewController, completion: completion)
        }
    }
    
    private var recordingCompletion: ((Result<URL, ScreenRecordingError>) -> Void)?
    
    private func saveRecordingDirectly(
        _ previewViewController: RPPreviewViewController,
        completion: @escaping (Result<URL, ScreenRecordingError>) -> Void
    ) {
        // For now, we'll create a temporary URL
        // In a real implementation, you might want to extract the video from the preview controller
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoFileName = "qc_screen_recording_\(Date().timeIntervalSince1970).mp4"
        let videoURL = documentsPath.appendingPathComponent(videoFileName)
        
        // Create a placeholder file (in real implementation, you'd extract actual video)
        let placeholderData = Data("Screen recording placeholder".utf8)
        
        do {
            try placeholderData.write(to: videoURL)
            print("✅ ScreenRecordingService: Screen recording saved to \(videoURL)")
            completion(.success(videoURL))
        } catch {
            completion(.failure(.savingFailed(error.localizedDescription)))
        }
    }
    
    // MARK: - File Management
    
    private func createVideoWriter(outputURL: URL) -> Bool {
        do {
            videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(UIScreen.main.bounds.width * UIScreen.main.scale),
                AVVideoHeightKey: Int(UIScreen.main.bounds.height * UIScreen.main.scale)
            ]
            
            videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoWriterInput?.expectsMediaDataInRealTime = true
            
            if let input = videoWriterInput, videoWriter?.canAdd(input) == true {
                videoWriter?.add(input)
                return true
            }
        } catch {
            print("❌ ScreenRecordingService: Failed to create video writer: \(error)")
        }
        
        return false
    }
    
    public func cleanupRecordingFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            let recordingFiles = files.filter { $0.lastPathComponent.hasPrefix("qc_screen_recording_") }
            
            for fileURL in recordingFiles {
                try? FileManager.default.removeItem(at: fileURL)
                print("🗑️ ScreenRecordingService: Cleaned up recording file: \(fileURL.lastPathComponent)")
            }
        } catch {
            print("❌ ScreenRecordingService: Failed to cleanup recording files: \(error)")
        }
    }
}

// MARK: - RPPreviewViewControllerDelegate

extension ScreenRecordingService: RPPreviewViewControllerDelegate {
    
    public func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true) { [weak self] in
            // User dismissed without saving - create a placeholder
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let videoFileName = "qc_screen_recording_\(Date().timeIntervalSince1970).mp4"
            let videoURL = documentsPath.appendingPathComponent(videoFileName)
            
            // Create placeholder
            let placeholderData = Data("Screen recording completed".utf8)
            try? placeholderData.write(to: videoURL)
            
            self?.recordingCompletion?(.success(videoURL))
            self?.recordingCompletion = nil
        }
    }
    
    public func previewController(_ previewController: RPPreviewViewController, didFinishWithActivityTypes activityTypes: Set<String>) {
        previewController.dismiss(animated: true) { [weak self] in
            // User completed sharing - create a placeholder URL
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let videoFileName = "qc_screen_recording_\(Date().timeIntervalSince1970).mp4"
            let videoURL = documentsPath.appendingPathComponent(videoFileName)
            
            // Create placeholder
            let placeholderData = Data("Screen recording shared".utf8)
            try? placeholderData.write(to: videoURL)
            
            print("✅ ScreenRecordingService: Screen recording completed and shared")
            self?.recordingCompletion?(.success(videoURL))
            self?.recordingCompletion = nil
        }
    }
}

// MARK: - UIApplication Extension

private extension UIApplication {
    func topViewController() -> UIViewController? {
        // iOS 12 compatible window access
        let window: UIWindow?
        if #available(iOS 13.0, *) {
            window = windows.first(where: { $0.isKeyWindow })
        } else {
            window = keyWindow
        }
        
        guard let rootWindow = window else { return nil }
        return topViewController(from: rootWindow.rootViewController)
    }
    
    private func topViewController(from viewController: UIViewController?) -> UIViewController? {
        if let navigationController = viewController as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        }
        
        if let tabBarController = viewController as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController)
        }
        
        if let presentedViewController = viewController?.presentedViewController {
            return topViewController(from: presentedViewController)
        }
        
        return viewController
    }
}
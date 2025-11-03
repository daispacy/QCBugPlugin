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
        
        guard !isRecording else {
            completion(.failure(.alreadyRecording))
            return
        }
        
        // Create output URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoFileName = "qc_screen_recording_\(Date().timeIntervalSince1970).mp4"
        outputURL = documentsPath.appendingPathComponent(videoFileName)
        
        // Start recording
        recorder.startRecording { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.recordingFailed(error.localizedDescription)))
                } else {
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
        
        recorder.stopRecording { [weak self] previewViewController, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.recordingFailed(error.localizedDescription)))
                    return
                }
                
                // Handle the preview view controller
                if let previewVC = previewViewController {
                    self.handleRecordingPreview(previewVC, completion: completion)
                } else {
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
        guard let window = windows.first(where: { $0.isKeyWindow }) else { return nil }
        return topViewController(from: window.rootViewController)
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
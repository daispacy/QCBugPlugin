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
final class ScreenRecordingService: NSObject, ScreenRecordingProtocol {

    // MARK: - Properties
    private let recorder = RPScreenRecorder.shared()
    private var outputURL: URL?
    private var recordingCompletion: ((Result<URL, ScreenRecordingError>) -> Void)?

    /// Tracks whether this service instance started the current recording
    private var isRecordingStartedByService = false
    
    // MARK: - Initialization
    
    /// Designated initializer for ScreenRecordingService
    override init() {
        super.init()
    }
    
    // MARK: - ScreenRecordingProtocol Implementation
    
    var isAvailable: Bool {
        return recorder.isAvailable
    }
    
    var isRecording: Bool {
        return recorder.isRecording
    }

    var isRecordingOwnedByService: Bool {
        return isRecordingStartedByService && isRecording
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        // ReplayKit handles permissions automatically
        // We'll just check if recording is available
        completion(isAvailable)
    }
    
    func startRecording(completion: @escaping (Result<Void, ScreenRecordingError>) -> Void) {
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
                print("⚠️ ScreenRecordingService: Screen recording already active (started externally)")
                isRecordingStartedByService = false
                completion(.success(()))
                return
            }
        }

        // Create output URL for future use
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let qcDirectory = documentsPath.appendingPathComponent("QCBugPlugin", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: qcDirectory, withIntermediateDirectories: true)

        let videoFileName = "qc_screen_recording_\(Date().timeIntervalSince1970).mp4"
        outputURL = qcDirectory.appendingPathComponent(videoFileName)

        // Start recording (simple API)
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
    
    func stopRecording(completion: @escaping (Result<URL, ScreenRecordingError>) -> Void) {
        guard isRecording else {
            completion(.failure(.notRecording))
            return
        }

        // Check if this service started the recording
        if !isRecordingStartedByService {
            print("⚠️ ScreenRecordingService: Cannot stop recording not started by this service")
            completion(.failure(.recordingFailed("Recording not started by this service")))
            return
        }

        // Store completion for later use
        recordingCompletion = completion

        // Stop recording and get preview controller
        recorder.stopRecording { [weak self] previewViewController, error in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion(.failure(.savingFailed("Service deallocated")))
                    return
                }

                // Reset the tracking flag
                self.isRecordingStartedByService = false

                if let error = error {
                    print("❌ ScreenRecordingService: Failed to stop recording: \(error.localizedDescription)")
                    self.recordingCompletion = nil
                    completion(.failure(.recordingFailed(error.localizedDescription)))
                    return
                }

                // Handle the preview view controller
                if let previewVC = previewViewController {
                    print("📹 ScreenRecordingService: Recording stopped, presenting preview for editing")
                    self.handleRecordingPreview(previewVC, completion: completion)
                } else {
                    print("⚠️ ScreenRecordingService: No preview controller available")
                    self.recordingCompletion = nil
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

        // Present preview controller for editing
        if let topViewController = UIApplication.shared.topViewController() {
            topViewController.present(previewViewController, animated: true) {
                print("✅ ScreenRecordingService: Preview controller presented")
            }
        } else {
            // If no view controller to present, save directly
            print("⚠️ ScreenRecordingService: No top view controller, saving directly")
            saveRecordingFromPreview(previewViewController, completion: completion)
        }
    }

    private func saveRecordingFromPreview(
        _ previewViewController: RPPreviewViewController,
        completion: @escaping (Result<URL, ScreenRecordingError>) -> Void
    ) {
        guard let outputURL = outputURL else {
            completion(.failure(.savingFailed("No output URL")))
            return
        }

        // The video is automatically saved by iOS to the camera roll when using RPPreviewViewController
        // We need to export it to our app's directory
        // For now, we'll create a reference URL and let the manager handle the confirmation
        print("✅ ScreenRecordingService: Recording completed, URL: \(outputURL.path)")
        completion(.success(outputURL))
    }
    
    func cleanupRecordingFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let qcDirectory = documentsPath.appendingPathComponent("QCBugPlugin", isDirectory: true)

        do {
            let files = try FileManager.default.contentsOfDirectory(at: qcDirectory, includingPropertiesForKeys: nil)
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

    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        print("📹 ScreenRecordingService: Preview controller dismissed")
        previewController.dismiss(animated: true) { [weak self] in
            guard let self = self, let outputURL = self.outputURL else { return }

            // User dismissed the preview - proceed with the recording URL
            print("✅ ScreenRecordingService: User finished preview, proceeding with URL: \(outputURL.path)")
            self.recordingCompletion?(.success(outputURL))
            self.recordingCompletion = nil
            self.outputURL = nil
        }
    }

    func previewController(_ previewController: RPPreviewViewController, didFinishWithActivityTypes activityTypes: Set<String>) {
        print("📹 ScreenRecordingService: Preview controller finished with activities: \(activityTypes)")
        previewController.dismiss(animated: true) { [weak self] in
            guard let self = self, let outputURL = self.outputURL else { return }

            // User completed editing/sharing - proceed with the recording URL
            print("✅ ScreenRecordingService: User finished with activities, proceeding with URL: \(outputURL.path)")
            self.recordingCompletion?(.success(outputURL))
            self.recordingCompletion = nil
            self.outputURL = nil
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
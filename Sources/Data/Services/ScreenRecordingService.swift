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
    private var videoWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var startTime: CMTime?
    private var isWritingStarted = false

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

        // Create output URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let qcDirectory = documentsPath.appendingPathComponent("QCBugPlugin", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: qcDirectory, withIntermediateDirectories: true)

        let videoFileName = "qc_screen_recording_\(Date().timeIntervalSince1970).mp4"
        outputURL = qcDirectory.appendingPathComponent(videoFileName)

        guard let outputURL = outputURL else {
            completion(.failure(.savingFailed("Failed to create output URL")))
            return
        }

        // Setup video writer
        guard createVideoWriter(outputURL: outputURL) else {
            completion(.failure(.savingFailed("Failed to create video writer")))
            return
        }

        // Start capture with handler
        recorder.startCapture(handler: { [weak self] sampleBuffer, bufferType, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ ScreenRecordingService: Capture error: \(error.localizedDescription)")
                return
            }

            self.processSampleBuffer(sampleBuffer, of: bufferType)

        }) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    self.isRecordingStartedByService = false
                    self.cleanupWriter()
                    completion(.failure(.recordingFailed(error.localizedDescription)))
                } else {
                    self.isRecordingStartedByService = true
                    print("🎥 ScreenRecordingService: Started screen recording with capture")
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

        // Stop capture
        recorder.stopCapture { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion(.failure(.savingFailed("Service deallocated")))
                    return
                }

                self.isRecordingStartedByService = false

                if let error = error {
                    print("❌ ScreenRecordingService: Failed to stop capture: \(error.localizedDescription)")
                    self.cleanupWriter()
                    completion(.failure(.recordingFailed(error.localizedDescription)))
                    return
                }

                // Finalize the video file
                self.finalizeRecording(completion: completion)
            }
        }
    }
    
    // MARK: - Private Methods

    private func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, of type: RPSampleBufferType) {
        guard let videoWriter = videoWriter else { return }

        // Start writing session if not started
        if !isWritingStarted {
            if videoWriter.status == .unknown {
                videoWriter.startWriting()
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                videoWriter.startSession(atSourceTime: timestamp)
                isWritingStarted = true
                print("🎬 ScreenRecordingService: Started writing session")
            }
        }

        guard videoWriter.status == .writing else {
            print("⚠️ ScreenRecordingService: Writer not ready, status: \(videoWriter.status.rawValue)")
            return
        }

        switch type {
        case .video:
            if let input = videoWriterInput, input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }

        case .audioApp, .audioMic:
            if let input = audioWriterInput, input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }

        @unknown default:
            break
        }
    }

    private func finalizeRecording(completion: @escaping (Result<URL, ScreenRecordingError>) -> Void) {
        guard let videoWriter = videoWriter, let outputURL = outputURL else {
            completion(.failure(.savingFailed("No video writer or output URL")))
            return
        }

        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()

        videoWriter.finishWriting { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion(.failure(.savingFailed("Service deallocated")))
                    return
                }

                if videoWriter.status == .completed {
                    print("✅ ScreenRecordingService: Recording saved to \(outputURL.path)")
                    self.cleanupWriter()
                    completion(.success(outputURL))
                } else {
                    let error = videoWriter.error?.localizedDescription ?? "Unknown error"
                    print("❌ ScreenRecordingService: Failed to finalize recording: \(error)")
                    self.cleanupWriter()
                    completion(.failure(.savingFailed(error)))
                }
            }
        }
    }

    private func cleanupWriter() {
        videoWriter = nil
        videoWriterInput = nil
        audioWriterInput = nil
        isWritingStarted = false
        outputURL = nil
    }
    
    // MARK: - File Management

    private func createVideoWriter(outputURL: URL) -> Bool {
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }

            videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

            // Video settings
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(UIScreen.main.bounds.width * UIScreen.main.scale),
                AVVideoHeightKey: Int(UIScreen.main.bounds.height * UIScreen.main.scale),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 6000000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]

            videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoWriterInput?.expectsMediaDataInRealTime = true

            // Audio settings
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000
            ]

            audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioWriterInput?.expectsMediaDataInRealTime = true

            // Add inputs to writer
            if let videoInput = videoWriterInput, videoWriter?.canAdd(videoInput) == true {
                videoWriter?.add(videoInput)
            } else {
                print("❌ ScreenRecordingService: Cannot add video input")
                return false
            }

            if let audioInput = audioWriterInput, videoWriter?.canAdd(audioInput) == true {
                videoWriter?.add(audioInput)
            }

            print("✅ ScreenRecordingService: Video writer created successfully")
            return true

        } catch {
            print("❌ ScreenRecordingService: Failed to create video writer: \(error)")
            return false
        }
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
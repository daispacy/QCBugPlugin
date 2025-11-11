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
    private var isWritingStarted = false
    private var videoBufferCount = 0
    private var audioBufferCount = 0

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
        print("🚨🚨🚨 ScreenRecordingService: START RECORDING - NEW CODE VERSION 2024-11-11 🚨🚨🚨")

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

        // Reset counters for new recording
        videoBufferCount = 0
        audioBufferCount = 0
        print("🎬 ScreenRecordingService: Starting new recording, counters reset")

        // Create output URL with validation
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        print("📁 ScreenRecordingService: Documents path: \(documentsPath.path)")

        let qcDirectory = documentsPath.appendingPathComponent("QCBugPlugin", isDirectory: true)
        print("📁 ScreenRecordingService: QC directory: \(qcDirectory.path)")

        // Create directory if needed and verify
        do {
            try FileManager.default.createDirectory(at: qcDirectory, withIntermediateDirectories: true, attributes: nil)
            print("✅ ScreenRecordingService: Directory created/verified successfully")

            // Verify directory is writable
            let testFilePath = qcDirectory.appendingPathComponent(".test_write").path
            let testData = "test".data(using: .utf8)!
            if FileManager.default.createFile(atPath: testFilePath, contents: testData, attributes: nil) {
                try? FileManager.default.removeItem(atPath: testFilePath)
                print("✅ ScreenRecordingService: Directory is writable")
            } else {
                print("❌ ScreenRecordingService: Directory is NOT writable!")
            }
        } catch {
            print("❌ ScreenRecordingService: Failed to create directory: \(error.localizedDescription)")
        }

        let videoFileName = "qc_screen_recording_\(Date().timeIntervalSince1970).mp4"
        outputURL = qcDirectory.appendingPathComponent(videoFileName)
        print("🎬 ScreenRecordingService: Output URL will be: \(outputURL!.path)")

        guard let outputURL = outputURL else {
            completion(.failure(.savingFailed("Failed to create output URL")))
            return
        }

        // Setup video writer
        guard createVideoWriter(outputURL: outputURL) else {
            completion(.failure(.savingFailed("Failed to create video writer")))
            return
        }

        // Start capture with handler to save video data
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
        print("🚨🚨🚨 ScreenRecordingService: STOP RECORDING - NEW CODE VERSION 2024-11-11 🚨🚨🚨")
        print("🎬 ScreenRecordingService: stopRecording called")

        guard isRecording else {
            print("❌ ScreenRecordingService: Not currently recording")
            completion(.failure(.notRecording))
            return
        }

        // Check if this service started the recording
        if !isRecordingStartedByService {
            print("⚠️ ScreenRecordingService: Cannot stop recording not started by this service")
            completion(.failure(.recordingFailed("Recording not started by this service")))
            return
        }

        print("🎬 ScreenRecordingService: Stopping capture, writing started: \(isWritingStarted)")
        print("🎬 ScreenRecordingService: Buffers written - Video: \(videoBufferCount), Audio: \(audioBufferCount)")

        // Stop capture
        recorder.stopCapture { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else {
                    print("❌ ScreenRecordingService: Service deallocated during stop")
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

                print("✅ ScreenRecordingService: Capture stopped successfully, finalizing video...")

                // Finalize the video file
                self.finalizeRecording(completion: completion)
            }
        }
    }
    
    // MARK: - Private Methods

    private func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, of type: RPSampleBufferType) {
        guard let videoWriter = videoWriter else {
            print("⚠️ ScreenRecordingService: No video writer available")
            return
        }

        // Start writing session if not started
        if !isWritingStarted {
            if videoWriter.status == .unknown {
                print("🎬 ScreenRecordingService: Starting writing session...")
                videoWriter.startWriting()
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                videoWriter.startSession(atSourceTime: timestamp)
                isWritingStarted = true
                print("🎬 ScreenRecordingService: Writing session started successfully")
            }
        }

        guard videoWriter.status == .writing else {
            if videoWriter.status == .failed {
                if let error = videoWriter.error {
                    print("⚠️ ScreenRecordingService: Writer failed: \(error.localizedDescription)")
                }
            } else {
                print("⚠️ ScreenRecordingService: Writer status: \(videoWriter.status.rawValue)")
            }
            return
        }

        switch type {
        case .video:
            if let input = videoWriterInput, input.isReadyForMoreMediaData {
                let success = input.append(sampleBuffer)
                if success {
                    videoBufferCount += 1
                    if videoBufferCount == 1 {
                        print("🎬 ScreenRecordingService: First video buffer written")
                    }
                } else {
                    print("⚠️ ScreenRecordingService: Failed to append video buffer")
                }
            } else {
                print("⚠️ ScreenRecordingService: Video input not ready for data")
            }

        case .audioApp, .audioMic:
            if let input = audioWriterInput, input.isReadyForMoreMediaData {
                let success = input.append(sampleBuffer)
                if success {
                    audioBufferCount += 1
                    if audioBufferCount == 1 {
                        print("🎬 ScreenRecordingService: First audio buffer written")
                    }
                } else {
                    print("⚠️ ScreenRecordingService: Failed to append audio buffer")
                }
            }

        @unknown default:
            break
        }
    }

    private func finalizeRecording(completion: @escaping (Result<URL, ScreenRecordingError>) -> Void) {
        print("🚨🚨🚨 ScreenRecordingService: FINALIZE RECORDING - NEW CODE VERSION 2024-11-11 🚨🚨🚨")
        print("🎬 ScreenRecordingService: finalizeRecording called")

        guard let videoWriter = videoWriter, let outputURL = outputURL else {
            print("❌ ScreenRecordingService: No video writer or output URL")
            completion(.failure(.savingFailed("No video writer or output URL")))
            return
        }

        print("🎬 ScreenRecordingService: Writer status before finalize: \(videoWriter.status.rawValue)")
        print("🎬 ScreenRecordingService: Writing started: \(isWritingStarted)")
        print("🎬 ScreenRecordingService: Buffers received - Video: \(videoBufferCount), Audio: \(audioBufferCount)")
        print("🎬 ScreenRecordingService: Output URL: \(outputURL.path)")

        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()
        print("🎬 ScreenRecordingService: Marked inputs as finished, calling finishWriting...")

        videoWriter.finishWriting { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else {
                    print("❌ ScreenRecordingService: Service deallocated during finishWriting")
                    completion(.failure(.savingFailed("Service deallocated")))
                    return
                }

                print("🎬 ScreenRecordingService: finishWriting completed, status: \(videoWriter.status.rawValue)")

                if videoWriter.status == .completed {
                    print("✅ ScreenRecordingService: Recording saved to \(outputURL.path)")

                    // Verify file exists and has size
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
                            let fileSize = attributes[.size] as? Int64 ?? 0
                            print("📁 ScreenRecordingService: File size: \(fileSize) bytes")
                        } catch {
                            print("⚠️ ScreenRecordingService: Could not get file attributes: \(error)")
                        }
                    } else {
                        print("⚠️ ScreenRecordingService: File does not exist at path!")
                    }

                    self.cleanupWriter()
                    completion(.success(outputURL))
                } else {
                    let error = videoWriter.error?.localizedDescription ?? "Unknown error"
                    print("❌ ScreenRecordingService: Failed to finalize recording")
                    print("❌ ScreenRecordingService: Writer status: \(videoWriter.status.rawValue)")
                    print("❌ ScreenRecordingService: Error: \(error)")
                    if let writerError = videoWriter.error {
                        print("❌ ScreenRecordingService: Error code: \((writerError as NSError).code)")
                        print("❌ ScreenRecordingService: Error domain: \((writerError as NSError).domain)")
                    }
                    self.cleanupWriter()
                    completion(.failure(.savingFailed(error)))
                }
            }
        }
    }

    private func createVideoWriter(outputURL: URL) -> Bool {
        print("🎬 ScreenRecordingService: createVideoWriter called for: \(outputURL.path)")

        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: outputURL.path) {
                print("⚠️ ScreenRecordingService: File already exists, removing...")
                try FileManager.default.removeItem(at: outputURL)
                print("✅ ScreenRecordingService: Existing file removed")
            }

            // Verify parent directory exists and is writable
            let parentDir = outputURL.deletingLastPathComponent()
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: parentDir.path, isDirectory: &isDirectory) {
                print("✅ ScreenRecordingService: Parent directory exists, isDirectory: \(isDirectory.boolValue)")
            } else {
                print("❌ ScreenRecordingService: Parent directory does NOT exist!")
                return false
            }

            print("🎬 ScreenRecordingService: Creating AVAssetWriter...")
            videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            print("✅ ScreenRecordingService: AVAssetWriter created successfully")

            // Video settings
            let width = Int(UIScreen.main.bounds.width * UIScreen.main.scale)
            let height = Int(UIScreen.main.bounds.height * UIScreen.main.scale)
            print("🎬 ScreenRecordingService: Video dimensions: \(width)x\(height)")

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 6000000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]

            videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoWriterInput?.expectsMediaDataInRealTime = true
            print("✅ ScreenRecordingService: Video input created")

            // Audio settings
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000
            ]

            audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioWriterInput?.expectsMediaDataInRealTime = true
            print("✅ ScreenRecordingService: Audio input created")

            // Add inputs to writer
            if let videoInput = videoWriterInput, videoWriter?.canAdd(videoInput) == true {
                videoWriter?.add(videoInput)
                print("✅ ScreenRecordingService: Video input added to writer")
            } else {
                print("❌ ScreenRecordingService: Cannot add video input")
                print("❌ ScreenRecordingService: Writer status: \(videoWriter?.status.rawValue ?? -1)")
                return false
            }

            if let audioInput = audioWriterInput, videoWriter?.canAdd(audioInput) == true {
                videoWriter?.add(audioInput)
                print("✅ ScreenRecordingService: Audio input added to writer")
            } else {
                print("⚠️ ScreenRecordingService: Cannot add audio input (will record video only)")
            }

            print("✅ ScreenRecordingService: Video writer created successfully")
            return true

        } catch {
            print("❌ ScreenRecordingService: Failed to create video writer: \(error.localizedDescription)")
            print("❌ ScreenRecordingService: Error domain: \((error as NSError).domain)")
            print("❌ ScreenRecordingService: Error code: \((error as NSError).code)")
            if let underlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError {
                print("❌ ScreenRecordingService: Underlying error: \(underlyingError.localizedDescription)")
            }
            return false
        }
    }

    private func cleanupWriter() {
        videoWriter = nil
        videoWriterInput = nil
        audioWriterInput = nil
        isWritingStarted = false
        videoBufferCount = 0
        audioBufferCount = 0
        outputURL = nil
        print("🧹 ScreenRecordingService: Cleaned up writer and reset counters")
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

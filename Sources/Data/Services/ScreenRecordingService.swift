//
//  ScreenRecordingService.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import UIKit
import ReplayKit
import AVFoundation
import CoreMedia

extension CMSampleBuffer: @retroactive @unchecked Sendable {}

/// Service for screen recording functionality using ReplayKit
final class ScreenRecordingService: NSObject, ScreenRecordingProtocol {

    // MARK: - Properties
    private let recorder = RPScreenRecorder.shared()
    private let writerQueue = DispatchQueue(label: "com.qcbugplugin.screenrecording.writer")

    private var videoWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var isWritingStarted = false
    private var videoBufferCount = 0
    private var audioBufferCount = 0
    private var firstVideoTimestamp: CMTime?
    private var isStoppingCapture = false

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

        // Check if running on simulator
        #if targetEnvironment(simulator)
        print("⚠️ ScreenRecordingService: Running on simulator - ReplayKit has limited support")
        print("⚠️ ScreenRecordingService: Screen recording may not work properly on simulator")
        #else
        print("✅ ScreenRecordingService: Running on physical device")
        #endif

        guard isAvailable else {
            print("❌ ScreenRecordingService: Recorder not available")
            completion(.failure(.notAvailable))
            return
        }

        print("✅ ScreenRecordingService: Recorder is available")

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

        // Reset counters and writer state on the serial queue to avoid races
        writerQueue.sync {
            self.cleanupWriterLocked()
            self.videoBufferCount = 0
            self.audioBufferCount = 0
            self.firstVideoTimestamp = nil
            self.isStoppingCapture = false
        }

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
        let destinationURL = qcDirectory.appendingPathComponent(videoFileName)
        print("🎬 ScreenRecordingService: Output URL will be: \(destinationURL.path)")

        var writerConfigured = false
        let screenBounds = UIScreen.main.bounds
        let videoSize = CGSize(width: screenBounds.width * UIScreen.main.scale,
                               height: screenBounds.height * UIScreen.main.scale)

        writerQueue.sync {
            self.outputURL = destinationURL
            writerConfigured = self.configureVideoWriterLocked(outputURL: destinationURL, videoSize: videoSize)
            if !writerConfigured {
                self.cleanupWriterLocked()
            }
        }

        guard writerConfigured else {
            completion(.failure(.savingFailed("Failed to create video writer")))
            return
        }

        // Enable microphone for audio capture
        // Note: ReplayKit might not capture ANY buffers if microphone is disabled
        print("🎬 ScreenRecordingService: Checking microphone availability...")
        print("🎬 ScreenRecordingService: Current microphone state: \(recorder.isMicrophoneEnabled)")

        // Try enabling microphone to ensure we get video buffers
        recorder.isMicrophoneEnabled = true
        print("🎬 ScreenRecordingService: Enabled microphone for capture")
        print("🎬 ScreenRecordingService: New microphone state: \(recorder.isMicrophoneEnabled)")

        // Log additional recorder state
        print("🎬 ScreenRecordingService: Recorder isAvailable: \(recorder.isAvailable)")
        print("🎬 ScreenRecordingService: Recorder isRecording: \(recorder.isRecording)")

        // Start capture with handler to save video data
        print("🎬 ScreenRecordingService: Calling startCapture with handler...")

        // Add a flag to detect if handler is ever called
        var handlerCalled = false

        recorder.startCapture(handler: { [weak self] sampleBuffer, bufferType, error in
            guard let self = self else { return }

            if !handlerCalled {
                handlerCalled = true
                print("✅ ScreenRecordingService: Capture handler CALLED for first time!")
            }

            if let error = error {
                print("❌ ScreenRecordingService: Capture handler error: \(error.localizedDescription)")
                return
            }

            // Log buffer type for debugging
            let bufferTypeStr: String
            switch bufferType {
            case .video:
                bufferTypeStr = "video"
            case .audioApp:
                bufferTypeStr = "audioApp"
            case .audioMic:
                bufferTypeStr = "audioMic"
            @unknown default:
                bufferTypeStr = "unknown"
            }

            // Only log first few buffers to avoid spam
            if self.videoBufferCount < 5 || self.audioBufferCount < 5 {
                print("📦 ScreenRecordingService: Received \(bufferTypeStr) buffer")
            }

            self.writerQueue.async { [weak self] in
                guard let self = self else { return }

                autoreleasepool {
                    self.processSampleBufferLocked(sampleBuffer, of: bufferType)
                }
            }

        }) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    self.isRecordingStartedByService = false
                    self.writerQueue.async {
                        self.cleanupWriterLocked()
                    }
                    completion(.failure(.recordingFailed(error.localizedDescription)))
                } else {
                    self.isRecordingStartedByService = true
                    print("🎥 ScreenRecordingService: Started screen recording with capture")

                    // Add a timeout check to detect if buffers are being received
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        guard let self = self else { return }
                        if self.videoBufferCount == 0 {
                            print("⚠️ ScreenRecordingService: WARNING - No video buffers received after 3 seconds!")
                            print("⚠️ ScreenRecordingService: This might indicate:")
                            print("   - Running on simulator (limited ReplayKit support)")
                            print("   - App window is not visible")
                            print("   - ReplayKit permissions issue")
                            print("   - Overlay window blocking capture")
                        } else {
                            print("✅ ScreenRecordingService: Recording is working - \(self.videoBufferCount) video buffers received")
                        }
                    }

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

        recorder.stopCapture { [weak self] error in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(.savingFailed("Service deallocated")))
                }
                return
            }

            if let error = error {
                print("❌ ScreenRecordingService: Failed to stop capture: \(error.localizedDescription)")
                self.writerQueue.async {
                    self.cleanupWriterLocked()
                }
                DispatchQueue.main.async {
                    self.isRecordingStartedByService = false
                    completion(.failure(.recordingFailed(error.localizedDescription)))
                }
                return
            }

            self.writerQueue.async {
                self.isStoppingCapture = true
                self.finalizeRecordingLocked { result in
                    DispatchQueue.main.async {
                        self.isRecordingStartedByService = false
                        completion(result)
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods

    private func processSampleBufferLocked(_ sampleBuffer: CMSampleBuffer, of type: RPSampleBufferType) {
        guard !isStoppingCapture else { return }
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("⚠️ ScreenRecordingService: Sample buffer not ready")
            return
        }
        guard let videoWriter = videoWriter else {
            print("⚠️ ScreenRecordingService: No video writer available")
            return
        }

        switch type {
        case .video:
            startSessionIfNeededLocked(with: sampleBuffer, writer: videoWriter)

            guard videoWriter.status == .writing else {
                if videoWriter.status == .failed, let error = videoWriter.error {
                    print("⚠️ ScreenRecordingService: Writer failed: \(error.localizedDescription)")
                } else {
                    print("⚠️ ScreenRecordingService: Writer status: \(videoWriter.status.rawValue)")
                }
                return
            }

            guard let input = videoWriterInput else {
                print("⚠️ ScreenRecordingService: Missing video input")
                return
            }

            if input.isReadyForMoreMediaData {
                if input.append(sampleBuffer) {
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
            guard isWritingStarted else {
                // Drop audio frames until we have video to anchor the session
                return
            }

            guard let input = audioWriterInput else { return }
            if input.isReadyForMoreMediaData {
                if input.append(sampleBuffer) {
                    audioBufferCount += 1
                    if audioBufferCount == 1 {
                        print("🎬 ScreenRecordingService: First audio buffer written")
                    }
                } else {
                    print("⚠️ ScreenRecordingService: Failed to append audio buffer")
                }
            } else {
                print("⚠️ ScreenRecordingService: Audio input not ready for data")
            }

        @unknown default:
            break
        }
    }

    private func startSessionIfNeededLocked(with sampleBuffer: CMSampleBuffer, writer: AVAssetWriter) {
        guard !isWritingStarted else { return }
        guard writer.status == .unknown else { return }

        print("🎬 ScreenRecordingService: Starting writing session...")
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        writer.startWriting()
        writer.startSession(atSourceTime: timestamp)
        firstVideoTimestamp = timestamp
        isWritingStarted = true
        print("🎬 ScreenRecordingService: Writing session started successfully at \(timestamp)")
    }

    private func finalizeRecordingLocked(completion: @escaping (Result<URL, ScreenRecordingError>) -> Void) {
        print("🚨🚨🚨 ScreenRecordingService: FINALIZE RECORDING - NEW CODE VERSION 2024-11-11 🚨🚨🚨")
        print("🎬 ScreenRecordingService: finalizeRecording called")

        guard let writer = videoWriter, let outputURL = outputURL else {
            print("❌ ScreenRecordingService: No video writer or output URL")
            completion(.failure(.savingFailed("No video writer or output URL")))
            return
        }

        print("🎬 ScreenRecordingService: Writer status before finalize: \(writer.status.rawValue)")
        print("🎬 ScreenRecordingService: Writing started: \(isWritingStarted)")
        print("🎬 ScreenRecordingService: Buffers received - Video: \(videoBufferCount), Audio: \(audioBufferCount)")
        print("🎬 ScreenRecordingService: Output URL: \(outputURL.path)")

        guard isWritingStarted, videoBufferCount > 0 else {
            print("❌ ScreenRecordingService: No video frames captured; aborting save")
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            cleanupWriterLocked()
            completion(.failure(.recordingFailed("Screen recording did not capture any video frames")))
            return
        }

        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()
        print("🎬 ScreenRecordingService: Marked inputs as finished, calling finishWriting...")

        let finalURL = outputURL
        writer.finishWriting { [weak self] in
            guard let self = self else { return }

            self.writerQueue.async {
                let statusValue = writer.status.rawValue
                print("🎬 ScreenRecordingService: finishWriting completed, status: \(statusValue)")

                if writer.status == .completed {
                    print("✅ ScreenRecordingService: Recording saved to \(finalURL.path)")
                    if FileManager.default.fileExists(atPath: finalURL.path) {
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: finalURL.path)
                            let fileSize = attributes[.size] as? Int64 ?? 0
                            print("📁 ScreenRecordingService: File size: \(fileSize) bytes")
                        } catch {
                            print("⚠️ ScreenRecordingService: Could not get file attributes: \(error)")
                        }
                    } else {
                        print("⚠️ ScreenRecordingService: File does not exist at path!")
                    }

                    self.cleanupWriterLocked()
                    completion(.success(finalURL))
                } else {
                    let errorMessage = writer.error?.localizedDescription ?? "Unknown error"
                    print("❌ ScreenRecordingService: Failed to finalize recording")
                    print("❌ ScreenRecordingService: Writer status: \(statusValue)")
                    print("❌ ScreenRecordingService: Error: \(errorMessage)")
                    if let writerError = writer.error {
                        print("❌ ScreenRecordingService: Error code: \((writerError as NSError).code)")
                        print("❌ ScreenRecordingService: Error domain: \((writerError as NSError).domain)")
                    }

                    if FileManager.default.fileExists(atPath: finalURL.path) {
                        try? FileManager.default.removeItem(at: finalURL)
                    }
                    self.cleanupWriterLocked()
                    completion(.failure(.savingFailed(errorMessage)))
                }
            }
        }
    }

    private func configureVideoWriterLocked(outputURL: URL, videoSize: CGSize) -> Bool {
        print("🎬 ScreenRecordingService: configureVideoWriterLocked called for: \(outputURL.path)")

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
            let width = Int(videoSize.width.rounded())
            let height = Int(videoSize.height.rounded())
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

    private func cleanupWriterLocked() {
        videoWriter = nil
        videoWriterInput = nil
        audioWriterInput = nil
        isWritingStarted = false
        videoBufferCount = 0
        audioBufferCount = 0
        outputURL = nil
        firstVideoTimestamp = nil
        isStoppingCapture = false
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

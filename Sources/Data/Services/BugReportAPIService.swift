//
//  BugReportAPIService.swift
//  QCBugPlugin
//
//  Created by GitHub Copilot on 11/5/25.
//

import AVFoundation
import Foundation
import UIKit

/// Service for submitting bug reports via webhook API
final class BugReportAPIService: BugReportProtocol {

    // MARK: - Nested Types

    private struct AttachmentPayload: Encodable {
        let type: String
        let fileName: String
        let mimeType: String
        let timestamp: String
        let size: Int
        let width: Int?
        let height: Int?
        let duration: Double?
        let data: String
    }

    private struct BugReportPayload: Encodable {
        let whtype: String

        struct MediaAttachmentDTO: Encodable {
            let type: MediaType
            let fileName: String
            let timestamp: Date
            let fileSize: Int64?
        }

        struct ReportDTO: Encodable {
            let id: String
            let timestamp: Date
            let description: String
            let priority: String
            let userActions: [UserAction]
            let deviceInfo: DeviceInfo
            let appInfo: AppInfo
            let screenshots: [String]
            let screenRecordingURL: String?
            let mediaAttachments: [MediaAttachmentDTO]
            let customData: [String: String]
            let currentScreen: String?
            let networkInfo: NetworkInfo?
            let memoryInfo: MemoryInfo?
            let gitLabProject: String?
            let assigneeUsername: String?
            let issueNumber: Int?
        }

        struct GitLabPayload: Encodable {
            let pat: String
            let project: String?

            init(credentials: GitLabCredentials) {
                self.pat = credentials.pat
                self.project = credentials.project
            }
        }

        struct MetadataPayload: Encodable {
            let gitlab: GitLabPayload

            init(gitlab: GitLabPayload) {
                self.gitlab = gitlab
            }
        }

        let report: ReportDTO
        let attachments: [AttachmentPayload]
        let metadata: MetadataPayload?

        init(report: BugReport, attachments: [AttachmentPayload], gitLabCredentials: GitLabCredentials?) {
            self.whtype = report.whtype
            let mediaDTO = report.mediaAttachments.map { attachment in
                MediaAttachmentDTO(
                    type: attachment.type,
                    fileName: attachment.fileName,
                    timestamp: attachment.timestamp,
                    fileSize: attachment.fileSize
                )
            }

            self.report = ReportDTO(
                id: report.id,
                timestamp: report.timestamp,
                description: report.description,
                priority: report.priority,
                userActions: report.userActions,
                deviceInfo: report.deviceInfo,
                appInfo: report.appInfo,
                screenshots: report.screenshots,
                screenRecordingURL: report.screenRecordingURL,
                mediaAttachments: mediaDTO,
                customData: report.customData,
                currentScreen: report.currentScreen,
                networkInfo: report.networkInfo,
                memoryInfo: report.memoryInfo,
                gitLabProject: report.gitLabProject,
                assigneeUsername: report.assigneeUsername,
                issueNumber: report.issueNumber ?? -1
            )
            self.attachments = attachments
            self.metadata = gitLabCredentials.map { MetadataPayload(gitlab: GitLabPayload(credentials: $0)) }
        }
    }

    private struct FileUploadPayload: Encodable {
        let whtype: String
        let reportId: String
        let attachment: AttachmentPayload
        let gitlab: BugReportPayload.GitLabPayload?

        init(whtype: String, reportId: String, attachment: AttachmentPayload, gitLabCredentials: GitLabCredentials?) {
            self.whtype = whtype
            self.reportId = reportId
            self.attachment = attachment
            self.gitlab = gitLabCredentials.map { BugReportPayload.GitLabPayload(credentials: $0) }
        }
    }

    private enum AttachmentLimits {
        static let maxImageBytes = 320 * 1024
        static let maxVideoBytes = 5 * 1024 * 1024
        static let minImageDimension: CGFloat = 60
        static let minVideoDimension: CGFloat = 120
    }

    private struct VideoCompressionOption {
        let targetSize: CGSize?
        let presetName: String
    }

    // MARK: - Properties

    private let webhookURL: String
    private let apiKey: String?
    private let gitLabAuthProvider: GitLabAuthProviding?
    private let session: URLSession
    private let jsonEncoder: JSONEncoder
    private let isoFormatter: ISO8601DateFormatter
    private let processingQueue = DispatchQueue(label: "com.qcbugplugin.report-processing", qos: .userInitiated)
    private let screenSize: CGSize
    private var cachedGitLabCredentialsForSession: GitLabCredentials?

    // MARK: - Initialization

    init(webhookURL: String, apiKey: String? = nil, gitLabAuthProvider: GitLabAuthProviding? = nil) {
        self.webhookURL = webhookURL
        self.apiKey = apiKey
        self.gitLabAuthProvider = gitLabAuthProvider

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601

        self.isoFormatter = ISO8601DateFormatter()
        self.isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if Thread.isMainThread {
            self.screenSize = UIScreen.main.bounds.size
        } else {
            var resolved = CGSize(width: 1280, height: 720)
            DispatchQueue.main.sync {
                resolved = UIScreen.main.bounds.size
            }
            self.screenSize = resolved
        }
    }

    func resetGitLabSession() {
        cachedGitLabCredentialsForSession = nil
    }

    // MARK: - BugReportProtocol Implementation

    func submitBugReport(_ report: BugReport, completion: @escaping (Result<String, BugReportError>) -> Void) {
        guard !webhookURL.isEmpty, let endpointURL = URL(string: webhookURL) else {
            DispatchQueue.main.async {
                completion(.failure(.invalidURL))
            }
            return
        }

        cachedGitLabCredentialsForSession = nil

        resolveGitLabAuthorization { [weak self] authResult in
            guard let self = self else { return }

            switch authResult {
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }

            case .success(let authorization):
                let gitLabCredentials = self.mergedGitLabCredentials(report: report, authorization: authorization)
                self.cachedGitLabCredentialsForSession = gitLabCredentials

                self.preparePayload(for: report, gitLabCredentials: gitLabCredentials) { result in
                    switch result {
                    case .failure(let error):
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }

                    case .success(let payloadData):
                        self.performSubmit(
                            url: endpointURL,
                            payloadData: payloadData,
                            authorization: authorization,
                            completion: completion
                        )
                    }
                }
            }
        }
    }

    func uploadFile(_ fileURL: URL, for reportId: String, completion: @escaping (Result<String, BugReportError>) -> Void) {
        guard !webhookURL.isEmpty, let endpointURL = URL(string: webhookURL + "/upload") else {
            DispatchQueue.main.async {
                completion(.failure(.invalidURL))
            }
            return
        }

        guard let type = inferMediaType(from: fileURL) else {
            DispatchQueue.main.async {
                completion(.failure(.invalidData))
            }
            return
        }

        resolveGitLabAuthorization { [weak self] authResult in
            guard let self = self else { return }

            switch authResult {
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }

            case .success(let authorization):
                let attachment = MediaAttachment(type: type, fileURL: fileURL)
                self.processAttachment(attachment) { result in
                    switch result {
                    case .failure(let error):
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }

                    case .success(let payload):
                        let gitLabCredentials = authorization.map {
                            let project = $0.project ?? self.cachedGitLabCredentialsForSession?.project
                            return GitLabCredentials(pat: $0.jwt, project: project)
                        } ?? self.cachedGitLabCredentialsForSession
                        if let credentials = gitLabCredentials {
                            self.cachedGitLabCredentialsForSession = credentials
                        }
                        self.performUpload(
                            url: endpointURL,
                            payload: payload,
                            reportId: reportId,
                            authorization: authorization,
                            gitLabCredentials: gitLabCredentials,
                            completion: completion
                        )
                    }
                }
            }
        }
    }

    // MARK: - Payload Preparation

    private func performSubmit(
        url: URL,
        payloadData: Data,
        authorization: GitLabAuthorization?,
        completion: @escaping (Result<String, BugReportError>) -> Void
    ) {
        var request = createJSONRequest(url: url, authorizationHeader: authorization?.authorizationHeader)
        request.httpBody = payloadData

        print("📤 BugReportAPIService: Submitting bug report JSON to \(webhookURL)")

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.handleResponse(data: data, response: response, error: error, completion: completion)
            }
        }.resume()
    }

    private func performUpload(
        url: URL,
        payload: AttachmentPayload,
        reportId: String,
        authorization: GitLabAuthorization?,
        gitLabCredentials: GitLabCredentials?,
        completion: @escaping (Result<String, BugReportError>) -> Void
    ) {
        let uploadPayload = FileUploadPayload(
            whtype: "report_issue",
            reportId: reportId,
            attachment: payload,
            gitLabCredentials: gitLabCredentials
        )

        do {
            let payloadData = try jsonEncoder.encode(uploadPayload)
            var request = createJSONRequest(url: url, authorizationHeader: authorization?.authorizationHeader)
            request.httpBody = payloadData

            print("📤 BugReportAPIService: Uploading attachment for report \(reportId) via JSON")

            session.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.handleResponse(data: data, response: response, error: error, completion: completion)
                }
            }.resume()
        } catch {
            DispatchQueue.main.async {
                completion(.failure(.invalidData))
            }
        }
    }

    private func resolveGitLabAuthorization(
        completion: @escaping (Result<GitLabAuthorization?, BugReportError>) -> Void
    ) {
        guard let provider = gitLabAuthProvider else {
            DispatchQueue.main.async {
                completion(.success(nil))
            }
            return
        }

        provider.fetchAuthorization { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let authorization):
                    completion(.success(authorization))
                case .failure(let error):
                    completion(.failure(self.mapGitLabError(error)))
                }
            }
        }
    }

    private func mapGitLabError(_ error: GitLabAuthError) -> BugReportError {
        switch error {
        case .invalidConfiguration:
            return .invalidData
        case .networkError(let message):
            return .networkError(message)
        case .invalidResponse:
            return .networkError("GitLab invalid response")
        case .tokenGenerationFailed:
            return .networkError("GitLab token generation failed")
        case .jwtGenerationFailed(let message):
            return .networkError(message)
        case .userAuthenticationRequired:
            return .authenticationFailed
        case .authenticationCancelled:
            return .authenticationFailed
        case .notAuthenticated:
            return .authenticationFailed
        }
    }

    private func mergedGitLabCredentials(
        report: BugReport,
        authorization: GitLabAuthorization?
    ) -> GitLabCredentials? {
        if let credentials = report.gitLabCredentials {
            return credentials
        }

        guard let authorization = authorization else {
            return nil
        }

        let project = report.gitLabProject ?? authorization.project
        return GitLabCredentials(pat: authorization.jwt, project: project)
    }

    private func preparePayload(
        for report: BugReport,
        gitLabCredentials: GitLabCredentials?,
        completion: @escaping (Result<Data, BugReportError>) -> Void
    ) {
        processingQueue.async {
            if report.mediaAttachments.isEmpty {
                do {
                    let payload = BugReportPayload(report: report, attachments: [], gitLabCredentials: gitLabCredentials)
                    let data = try self.jsonEncoder.encode(payload)
                    completion(.success(data))
                } catch {
                    completion(.failure(.invalidData))
                }
                return
            }

            var attachments = Array<AttachmentPayload?>(repeating: nil, count: report.mediaAttachments.count)
            var processingError: BugReportError?
            let group = DispatchGroup()
            let lock = NSLock()

            for (index, attachment) in report.mediaAttachments.enumerated() {
                group.enter()
                self.processAttachment(attachment) { result in
                    lock.lock()
                    defer { lock.unlock() }

                    switch result {
                    case .success(let payload):
                        attachments[index] = payload
                    case .failure(let error):
                        processingError = error
                    }
                    group.leave()
                }
            }

            group.notify(queue: self.processingQueue) {
                if let error = processingError {
                    completion(.failure(error))
                    return
                }

                let flattened = attachments.compactMap { $0 }

                do {
                    let payload = BugReportPayload(report: report, attachments: flattened, gitLabCredentials: gitLabCredentials)
                    let data = try self.jsonEncoder.encode(payload)
                    completion(.success(data))
                } catch {
                    completion(.failure(.invalidData))
                }
            }
        }
    }

    private func processAttachment(_ attachment: MediaAttachment, completion: @escaping (Result<AttachmentPayload, BugReportError>) -> Void) {
        guard let url = URL(string: attachment.fileURL) else {
            completion(.failure(.invalidData))
            return
        }

        switch attachment.type {
        case .screenshot:
            processImageAttachment(url: url, attachment: attachment, completion: completion)
        case .screenRecording:
            processVideoAttachment(url: url, attachment: attachment, completion: completion)
        case .other:
            processRawFileAttachment(url: url, attachment: attachment, completion: completion)
        }
    }

    private func processImageAttachment(
        url: URL,
        attachment: MediaAttachment,
        completion: @escaping (Result<AttachmentPayload, BugReportError>) -> Void
    ) {
        processingQueue.async {
            guard let image = UIImage(contentsOfFile: url.path) else {
                completion(.failure(.fileUploadFailed("Unable to load image at \(url.path)")))
                return
            }

            guard let result = self.compressImageForUpload(image) else {
                completion(.failure(.fileUploadFailed("Screenshot exceeds maximum size of 320 KB")))
                return
            }

            let (finalImage, jpegData) = result

            let baseName = (attachment.fileName as NSString).deletingPathExtension
            let recompressedName = baseName.isEmpty ? "attachment.jpg" : baseName + ".jpg"

            let payload = AttachmentPayload(
                type: attachment.type.rawValue,
                fileName: recompressedName,
                mimeType: "image/jpeg",
                timestamp: self.isoFormatter.string(from: attachment.timestamp),
                size: jpegData.count,
                width: Int(finalImage.size.width),
                height: Int(finalImage.size.height),
                duration: nil,
                data: jpegData.base64EncodedString()
            )

            completion(.success(payload))
        }
    }

    private func processVideoAttachment(
        url: URL,
        attachment: MediaAttachment,
        completion: @escaping (Result<AttachmentPayload, BugReportError>) -> Void
    ) {
        let asset = AVURLAsset(url: url)
        guard asset.isReadable else {
            completion(.failure(.fileUploadFailed("Unable to read video asset")))
            return
        }

        let options = videoCompressionOptions(for: asset)
        attemptVideoExport(asset: asset, attachment: attachment, options: options, index: 0, completion: completion)
    }

    private func attemptVideoExport(
        asset: AVAsset,
        attachment: MediaAttachment,
        options: [VideoCompressionOption],
        index: Int,
        completion: @escaping (Result<AttachmentPayload, BugReportError>) -> Void
    ) {
        guard index < options.count else {
            completion(.failure(.fileUploadFailed("Screen recording exceeds maximum size of 5 MB")))
            return
        }

        let option = options[index]
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)

        guard compatiblePresets.contains(option.presetName),
              let exportSession = AVAssetExportSession(asset: asset, presetName: option.presetName) else {
            attemptVideoExport(asset: asset, attachment: attachment, options: options, index: index + 1, completion: completion)
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        if let targetSize = option.targetSize,
           let composition = videoComposition(for: asset, targetSize: targetSize) {
            exportSession.videoComposition = composition
        } else {
            exportSession.videoComposition = nil
        }

        if #available(iOS 13.0, *) {
            exportSession.fileLengthLimit = Int64(AttachmentLimits.maxVideoBytes)
        }

        exportSession.exportAsynchronously { [weak self] in
            guard let self = self else { return }

            defer { try? FileManager.default.removeItem(at: tempURL) }

            switch exportSession.status {
            case .completed:
                do {
                    let videoData = try Data(contentsOf: tempURL)
                    if videoData.count > AttachmentLimits.maxVideoBytes {
                        self.attemptVideoExport(
                            asset: asset,
                            attachment: attachment,
                            options: options,
                            index: index + 1,
                            completion: completion
                        )
                        return
                    }

                    let duration = CMTimeGetSeconds(asset.duration)
                    let dimensions = self.outputDimensions(for: exportSession, asset: asset)

                    let payload = AttachmentPayload(
                        type: attachment.type.rawValue,
                        fileName: attachment.fileName,
                        mimeType: "video/mp4",
                        timestamp: self.isoFormatter.string(from: attachment.timestamp),
                        size: videoData.count,
                        width: dimensions.width,
                        height: dimensions.height,
                        duration: duration.isFinite ? duration : nil,
                        data: videoData.base64EncodedString()
                    )

                    completion(.success(payload))
                } catch {
                    completion(.failure(.fileUploadFailed(error.localizedDescription)))
                }

            case .failed, .cancelled:
                if index + 1 < options.count {
                    self.attemptVideoExport(
                        asset: asset,
                        attachment: attachment,
                        options: options,
                        index: index + 1,
                        completion: completion
                    )
                } else {
                    let message = exportSession.error?.localizedDescription ?? "Unknown export failure"
                    completion(.failure(.fileUploadFailed(message)))
                }

            default:
                break
            }
        }
    }

    private func processRawFileAttachment(
        url: URL,
        attachment: MediaAttachment,
        completion: @escaping (Result<AttachmentPayload, BugReportError>) -> Void
    ) {
        processingQueue.async {
            do {
                let fileData = try Data(contentsOf: url)

                let payload = AttachmentPayload(
                    type: attachment.type.rawValue,
                    fileName: attachment.fileName,
                    mimeType: attachment.type.mimeType,
                    timestamp: self.isoFormatter.string(from: attachment.timestamp),
                    size: fileData.count,
                    width: nil,
                    height: nil,
                    duration: nil,
                    data: fileData.base64EncodedString()
                )

                completion(.success(payload))
            } catch {
                completion(.failure(.fileUploadFailed("Unable to load file at \(url.path): \(error.localizedDescription)")))
            }
        }
    }

    private func videoCompressionOptions(for asset: AVAsset) -> [VideoCompressionOption] {
        let naturalSize = assetNaturalSize(for: asset)
        let baseSize = CGSize(
            width: min(screenSize.width, naturalSize.width),
            height: min(screenSize.height, naturalSize.height)
        )

        let scaleFactors: [CGFloat] = [1.0, 0.75, 0.6, 0.45, 0.35]
        var options: [VideoCompressionOption] = scaleFactors.compactMap { factor in
            let scaledSize = CGSize(width: baseSize.width * factor, height: baseSize.height * factor)
            guard scaledSize.width >= AttachmentLimits.minVideoDimension,
                  scaledSize.height >= AttachmentLimits.minVideoDimension else {
                return nil
            }
            return VideoCompressionOption(targetSize: scaledSize, presetName: exportPreset(for: scaledSize))
        }

        options.append(VideoCompressionOption(targetSize: nil, presetName: AVAssetExportPresetMediumQuality))
        options.append(VideoCompressionOption(targetSize: nil, presetName: AVAssetExportPresetLowQuality))

        if options.isEmpty {
            options.append(VideoCompressionOption(targetSize: nil, presetName: AVAssetExportPresetLowQuality))
        }

        return options
    }

    private func assetNaturalSize(for asset: AVAsset) -> CGSize {
        guard let track = asset.tracks(withMediaType: .video).first else {
            return screenSize
        }

        let naturalRect = CGRect(origin: .zero, size: track.naturalSize).applying(track.preferredTransform)
        return CGSize(width: abs(naturalRect.width), height: abs(naturalRect.height))
    }

    // MARK: - Request Helpers

    private func createJSONRequest(url: URL, authorizationHeader: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let authorizationHeader = authorizationHeader {
            request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        } else if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("QCBugPlugin/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        return request
    }

    // MARK: - Utility

    private func scaledImage(_ image: UIImage, toFit targetSize: CGSize) -> UIImage {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return image }

        let widthScale = targetSize.width / sourceSize.width
        let heightScale = targetSize.height / sourceSize.height
        let scale = min(widthScale, heightScale, 1.0)

        guard scale < 1.0 else { return image }

        let newSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func compressImageForUpload(_ image: UIImage) -> (UIImage, Data)? {
        var currentImage = scaledImage(image, toFit: screenSize)
        var compression: CGFloat = 0.9
        let minCompression: CGFloat = 0.35
        let scaleStep: CGFloat = 0.85

        guard let initialData = currentImage.jpegData(compressionQuality: compression) else {
            return nil
        }

        var currentData = initialData

        while currentData.count > AttachmentLimits.maxImageBytes {
            if compression > minCompression {
                compression = max(compression * 0.8, minCompression)
                if let recompressed = currentImage.jpegData(compressionQuality: compression) {
                    currentData = recompressed
                    continue
                } else {
                    return nil
                }
            }

            let newWidth = currentImage.size.width * scaleStep
            let newHeight = currentImage.size.height * scaleStep

            if newWidth < AttachmentLimits.minImageDimension || newHeight < AttachmentLimits.minImageDimension {
                return nil
            }

            currentImage = redrawImage(currentImage, to: CGSize(width: newWidth, height: newHeight))
            compression = 0.9

            guard let resizedData = currentImage.jpegData(compressionQuality: compression) else {
                return nil
            }
            currentData = resizedData
        }

        return (currentImage, currentData)
    }

    private func redrawImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func exportPreset(for targetSize: CGSize) -> String {
        let maxDimension = max(targetSize.width, targetSize.height)

        if maxDimension <= 720 {
            return AVAssetExportPreset640x480
        } else if maxDimension <= 1080 {
            return AVAssetExportPreset1280x720
        } else if maxDimension <= 1920 {
            return AVAssetExportPreset1920x1080
        } else {
            return AVAssetExportPresetHighestQuality
        }
    }

    private func videoComposition(for asset: AVAsset, targetSize: CGSize) -> AVMutableVideoComposition? {
        guard let track = asset.tracks(withMediaType: .video).first else { return nil }

        let naturalRect = CGRect(origin: .zero, size: track.naturalSize).applying(track.preferredTransform)
        let videoWidth = abs(naturalRect.width)
        let videoHeight = abs(naturalRect.height)

        let widthScale = targetSize.width / videoWidth
        let heightScale = targetSize.height / videoHeight
        let scale = min(widthScale, heightScale, 1.0)

        guard scale < 1.0 else { return nil }

        let composition = AVMutableVideoComposition()
        composition.renderSize = CGSize(width: videoWidth * scale, height: videoHeight * scale)
        composition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        var transform = track.preferredTransform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        let scaledRect = naturalRect.applying(CGAffineTransform(scaleX: scale, y: scale))
        transform = transform.concatenating(CGAffineTransform(translationX: -scaledRect.origin.x, y: -scaledRect.origin.y))
        layerInstruction.setTransform(transform, at: .zero)

        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]
        return composition
    }

    private func outputDimensions(for exportSession: AVAssetExportSession, asset: AVAsset) -> (width: Int?, height: Int?) {
        if let composition = exportSession.videoComposition {
            return (Int(composition.renderSize.width), Int(composition.renderSize.height))
        }

        guard let track = asset.tracks(withMediaType: .video).first else {
            return (nil, nil)
        }

        let naturalRect = CGRect(origin: .zero, size: track.naturalSize).applying(track.preferredTransform)
        return (Int(abs(naturalRect.width)), Int(abs(naturalRect.height)))
    }

    private func inferMediaType(from url: URL) -> MediaType? {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "heic", "heif":
            return .screenshot
        case "mp4", "mov", "m4v":
            return .screenRecording
        default:
            return nil
        }
    }

    private func handleResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        completion: @escaping (Result<String, BugReportError>) -> Void
    ) {
        if let error = error {
            print("❌ BugReportAPIService: Network error: \(error.localizedDescription)")
            completion(.failure(.networkError(error.localizedDescription)))
            return
        }

        guard let data = data,
              let responseObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            completion(.failure(.networkError("Invalid response")))
            return
        }

        let code = responseObject["code"] as? Int ?? -1
        let message = (responseObject["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let codeMessage = message?.isEmpty == false ? message! : "Unexpected response"

        if code == 200 {
            if let dataField = responseObject["data"] {
                if let reportId = dataField as? String {
                    print("✅ BugReportAPIService: Bug report submitted successfully with ID: \(reportId)")
                    completion(.success(reportId))
                    return
                } else if let dataDict = dataField as? [String: Any],
                          let reportId = dataDict["id"] as? String ?? dataDict["report_id"] as? String {
                    print("✅ BugReportAPIService: Bug report submitted successfully with ID: \(reportId)")
                    completion(.success(reportId))
                    return
                }
            }

            let reportId = UUID().uuidString
            print("✅ BugReportAPIService: Bug report submitted successfully (generated ID: \(reportId))")
            completion(.success(reportId))
            return
        }

        if code == 401 {
            print("❌ BugReportAPIService: Authentication failed (code 401)")
            completion(.failure(.authenticationFailed))
            return
        }

        let finalMessage = extractErrorMessage(from: data) ?? codeMessage
        let errorCode = code <= 0 ? 500 : code

        if errorCode >= 400 && errorCode < 500 {
            print("❌ BugReportAPIService: Client error (code \(errorCode)): \(finalMessage)")
            completion(.failure(.serverError(errorCode, finalMessage)))
        } else {
            print("❌ BugReportAPIService: Server error (code \(errorCode)): \(finalMessage)")
            completion(.failure(.serverError(errorCode, finalMessage)))
        }
    }

    private func extractErrorMessage(from data: Data?) -> String? {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json["error"] as? String ??
            json["message"] as? String ??
            json["detail"] as? String ??
            json["description"] as? String
    }
}

// MARK: - Mock Implementation for Testing

final class MockBugReportAPIService: BugReportProtocol {

    var shouldSucceed: Bool = true
    var mockReportId: String = "mock-report-123"
    var mockError: BugReportError = .networkError("Mock network error")
    var delay: TimeInterval = 1.0

    init() {}

    func submitBugReport(_ report: BugReport, completion: @escaping (Result<String, BugReportError>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            DispatchQueue.main.async {
                if self.shouldSucceed {
                    print("✅ MockBugReportAPIService: Mock bug report submitted with ID: \(self.mockReportId)")
                    completion(.success(self.mockReportId))
                } else {
                    print("❌ MockBugReportAPIService: Mock submission failed: \(self.mockError.localizedDescription)")
                    completion(.failure(self.mockError))
                }
            }
        }
    }

    func uploadFile(_ fileURL: URL, for reportId: String, completion: @escaping (Result<String, BugReportError>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            DispatchQueue.main.async {
                if self.shouldSucceed {
                    let fileId = "mock-file-\(UUID().uuidString)"
                    print("✅ MockBugReportAPIService: Mock file upload completed with ID: \(fileId)")
                    completion(.success(fileId))
                } else {
                    print("❌ MockBugReportAPIService: Mock file upload failed: \(self.mockError.localizedDescription)")
                    completion(.failure(self.mockError))
                }
            }
        }
    }
}

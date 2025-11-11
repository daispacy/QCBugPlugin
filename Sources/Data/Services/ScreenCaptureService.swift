//
//  ScreenCaptureService.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/4/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import UIKit

/// Service for screen capture functionality
final class ScreenCaptureService: NSObject, ScreenCaptureProtocol {

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - ScreenCaptureProtocol Implementation

    func captureScreen(completion: @escaping (Result<URL, ScreenCaptureError>) -> Void) {
        DispatchQueue.main.async {
            // Get the key window
            let window: UIWindow?
            if #available(iOS 13.0, *) {
                window = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
            } else {
                window = UIApplication.shared.keyWindow
            }

            guard let captureWindow = window else {
                completion(.failure(.captureFailed("No window available")))
                return
            }

            self.captureView(captureWindow) { result in
                completion(result)
            }
        }
    }

    func captureView(_ view: UIView, completion: @escaping (Result<URL, ScreenCaptureError>) -> Void) {
        DispatchQueue.main.async {
            guard view.bounds.width > 0, view.bounds.height > 0 else {
                completion(.failure(.invalidView))
                return
            }

            // Create image context
            let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
            let image = renderer.image { context in
                view.layer.render(in: context.cgContext)
            }

            // Save to file
            self.saveImage(image) { result in
                completion(result)
            }
        }
    }

    func cleanupScreenshots() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let qcDirectory = documentsPath.appendingPathComponent("QCBugPlugin", isDirectory: true)

        let directoriesToCheck: [URL] = [qcDirectory, documentsPath]

        for directory in directoriesToCheck {
            guard FileManager.default.fileExists(atPath: directory.path) else { continue }

            do {
                let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                let screenshotFiles = files.filter { $0.lastPathComponent.hasPrefix("qc_screenshot_") }

                for fileURL in screenshotFiles {
                    try? FileManager.default.removeItem(at: fileURL)
                    print("🗑️ ScreenCaptureService: Cleaned up screenshot: \(fileURL.lastPathComponent)")
                }
            } catch {
                print("❌ ScreenCaptureService: Failed to cleanup screenshots in \(directory.lastPathComponent): \(error)")
            }
        }
    }

    // MARK: - Private Methods

    private func saveImage(_ image: UIImage, completion: @escaping (Result<URL, ScreenCaptureError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let qcDirectory = documentsPath.appendingPathComponent("QCBugPlugin", isDirectory: true)
            let fileName = "qc_screenshot_\(Date().timeIntervalSince1970).png"
            do {
                try FileManager.default.createDirectory(at: qcDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.savingFailed("Failed to create screenshot directory")))
                }
                return
            }

            let fileURL = qcDirectory.appendingPathComponent(fileName)

            guard let pngData = image.pngData() else {
                DispatchQueue.main.async {
                    completion(.failure(.captureFailed("Failed to convert image to PNG")))
                }
                return
            }

            do {
                try pngData.write(to: fileURL, options: .atomic)
                print("📸 ScreenCaptureService: Screenshot saved to \(fileURL)")

                DispatchQueue.main.async {
                    completion(.success(fileURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.savingFailed(error.localizedDescription)))
                }
            }
        }
    }
}

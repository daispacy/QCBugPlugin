//
//  BugReportAPIService.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation

/// Service for submitting bug reports via webhook API
public final class BugReportAPIService: BugReportProtocol {
    
    // MARK: - Properties
    private let webhookURL: String
    private let apiKey: String?
    private let session: URLSession
    private let jsonEncoder: JSONEncoder
    
    // MARK: - Initialization
    
    public init(webhookURL: String, apiKey: String? = nil) {
        self.webhookURL = webhookURL
        self.apiKey = apiKey
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - BugReportProtocol Implementation
    
    public func submitBugReport(_ report: BugReport, completion: @escaping (Result<String, BugReportError>) -> Void) {
        guard let url = URL(string: webhookURL) else {
            completion(.failure(.invalidURL))
            return
        }
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = createMultipartRequest(url: url, boundary: boundary)
        
        do {
            let reportData = try jsonEncoder.encode(report)
            let bodyData = createMultipartBody(
                report: reportData,
                screenRecordingURL: report.screenRecordingURL.flatMap { URL(string: $0) },
                boundary: boundary
            )
            
            request.httpBody = bodyData
            
            print("📤 BugReportAPIService: Submitting bug report to \(webhookURL)")
            
            session.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.handleResponse(data: data, response: response, error: error, completion: completion)
                }
            }.resume()
            
        } catch {
            completion(.failure(.invalidData))
        }
    }
    
    public func uploadFile(_ fileURL: URL, for reportId: String, completion: @escaping (Result<String, BugReportError>) -> Void) {
        guard let url = URL(string: webhookURL + "/upload") else {
            completion(.failure(.invalidURL))
            return
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = createMultipartRequest(url: url, boundary: boundary)
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            let bodyData = createFileUploadBody(
                fileData: fileData,
                fileName: fileURL.lastPathComponent,
                reportId: reportId,
                boundary: boundary
            )
            
            request.httpBody = bodyData
            
            print("📤 BugReportAPIService: Uploading file \(fileURL.lastPathComponent) for report \(reportId)")
            
            session.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.handleResponse(data: data, response: response, error: error, completion: completion)
                }
            }.resume()
            
        } catch {
            completion(.failure(.fileUploadFailed(error.localizedDescription)))
        }
    }
    
    // MARK: - Private Methods
    
    private func createMultipartRequest(url: URL, boundary: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add API key if available
        if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Add custom headers
        request.setValue("QCBugPlugin/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        
        return request
    }
    
    private func createMultipartBody(
        report: Data,
        screenRecordingURL: URL?,
        boundary: String
    ) -> Data {
        var body = Data()
        
        // Add bug report JSON data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"bug_report\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        body.append(report)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add screen recording if available
        if let videoURL = screenRecordingURL,
           let videoData = try? Data(contentsOf: videoURL) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"screen_recording\"; filename=\"\(videoURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
            body.append(videoData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    private func createFileUploadBody(
        fileData: Data,
        fileName: String,
        reportId: String,
        boundary: String
    ) -> Data {
        var body = Data()
        
        // Add report ID
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"report_id\"\r\n\r\n".data(using: .utf8)!)
        body.append(reportId.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        
        // Determine content type based on file extension
        let contentType = mimeType(for: fileName)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    private func mimeType(for fileName: String) -> String {
        let pathExtension = (fileName as NSString).pathExtension.lowercased()
        
        switch pathExtension {
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "json":
            return "application/json"
        case "txt":
            return "text/plain"
        default:
            return "application/octet-stream"
        }
    }
    
    private func handleResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        completion: @escaping (Result<String, BugReportError>) -> Void
    ) {
        // Handle network error
        if let error = error {
            print("❌ BugReportAPIService: Network error: \(error.localizedDescription)")
            completion(.failure(.networkError(error.localizedDescription)))
            return
        }
        
        // Handle HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(.networkError("Invalid response")))
            return
        }
        
        let statusCode = httpResponse.statusCode
        print("📡 BugReportAPIService: Response status code: \(statusCode)")
        
        // Handle different status codes
        switch statusCode {
        case 200...299:
            // Success
            if let data = data,
               let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let reportId = responseDict["id"] as? String ?? responseDict["report_id"] as? String {
                print("✅ BugReportAPIService: Bug report submitted successfully with ID: \(reportId)")
                completion(.success(reportId))
            } else {
                // Success but no report ID returned
                let reportId = UUID().uuidString
                print("✅ BugReportAPIService: Bug report submitted successfully (generated ID: \(reportId))")
                completion(.success(reportId))
            }
            
        case 401:
            print("❌ BugReportAPIService: Authentication failed")
            completion(.failure(.authenticationFailed))
            
        case 400...499:
            let message = extractErrorMessage(from: data) ?? "Client error"
            print("❌ BugReportAPIService: Client error (\(statusCode)): \(message)")
            completion(.failure(.serverError(statusCode, message)))
            
        case 500...599:
            let message = extractErrorMessage(from: data) ?? "Server error"
            print("❌ BugReportAPIService: Server error (\(statusCode)): \(message)")
            completion(.failure(.serverError(statusCode, message)))
            
        default:
            let message = "Unexpected status code: \(statusCode)"
            print("❌ BugReportAPIService: \(message)")
            completion(.failure(.serverError(statusCode, message)))
        }
    }
    
    private func extractErrorMessage(from data: Data?) -> String? {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Try different common error message keys
        return json["error"] as? String ??
               json["message"] as? String ??
               json["detail"] as? String ??
               json["description"] as? String
    }
}

// MARK: - Mock Implementation for Testing

public final class MockBugReportAPIService: BugReportProtocol {
    
    public var shouldSucceed: Bool = true
    public var mockReportId: String = "mock-report-123"
    public var mockError: BugReportError = .networkError("Mock network error")
    public var delay: TimeInterval = 1.0
    
    public init() {}
    
    public func submitBugReport(_ report: BugReport, completion: @escaping (Result<String, BugReportError>) -> Void) {
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
    
    public func uploadFile(_ fileURL: URL, for reportId: String, completion: @escaping (Result<String, BugReportError>) -> Void) {
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
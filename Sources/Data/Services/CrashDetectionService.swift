//
//  CrashDetectionService.swift
//  QCBugPlugin
//
//  Created by QCBugPlugin on 11/6/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import UIKit

/// Protocol for crash detection service
protocol CrashDetectionProtocol {
    /// Start monitoring for crashes
    func startMonitoring()

    /// Stop monitoring for crashes
    func stopMonitoring()

    /// Check if there are pending crash reports
    func hasPendingCrashReports() -> Bool

    /// Get all pending crash reports
    func getPendingCrashReports() -> [CrashReport]

    /// Mark a crash report as handled
    func markCrashReportAsHandled(_ crashReport: CrashReport)

    /// Delete a crash report
    func deleteCrashReport(_ crashReport: CrashReport)

    /// Clear all crash reports
    func clearAllCrashReports()
}

/// Crash report data structure
public struct CrashReport: Codable {
    public let timestamp: Date
    public let crashType: CrashType
    public let exceptionName: String?
    public let exceptionReason: String?
    public let stackTrace: [String]
    public let appInfo: AppInfo
    public let deviceInfo: DeviceInfo
    public let logFilePath: String
    public let identifier: String

    public enum CrashType: String, Codable {
        case exception
        case signal
        case unknown
    }

    public struct AppInfo: Codable {
        public let bundleIdentifier: String
        public let version: String
        public let buildNumber: String
    }

    public struct DeviceInfo: Codable {
        public let model: String
        public let systemName: String
        public let systemVersion: String
        public let locale: String
    }

    init(
        timestamp: Date = Date(),
        crashType: CrashType,
        exceptionName: String? = nil,
        exceptionReason: String? = nil,
        stackTrace: [String] = [],
        logFilePath: String,
        identifier: String = UUID().uuidString
    ) {
        self.timestamp = timestamp
        self.crashType = crashType
        self.exceptionName = exceptionName
        self.exceptionReason = exceptionReason
        self.stackTrace = stackTrace
        self.logFilePath = logFilePath
        self.identifier = identifier

        // Capture app info
        let bundle = Bundle.main
        self.appInfo = AppInfo(
            bundleIdentifier: bundle.bundleIdentifier ?? "unknown",
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        )

        // Capture device info
        let device = UIDevice.current
        let locale = Locale.current.identifier
        self.deviceInfo = DeviceInfo(
            model: device.model,
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            locale: locale
        )
    }

    /// Generate formatted crash log content
    public func generateLogContent() -> String {
        var log = """
        =====================================
        CRASH REPORT
        =====================================

        Timestamp: \(timestamp)
        Crash Type: \(crashType.rawValue)
        Identifier: \(identifier)

        """

        if let name = exceptionName {
            log += "Exception Name: \(name)\n"
        }

        if let reason = exceptionReason {
            log += "Exception Reason: \(reason)\n"
        }

        log += """

        Application Info:
        - Bundle ID: \(appInfo.bundleIdentifier)
        - Version: \(appInfo.version) (\(appInfo.buildNumber))

        Device Info:
        - Model: \(deviceInfo.model)
        - System: \(deviceInfo.systemName) \(deviceInfo.systemVersion)
        - Locale: \(deviceInfo.locale)

        Stack Trace:

        """

        if stackTrace.isEmpty {
            log += "(No stack trace available)\n"
        } else {
            for (index, frame) in stackTrace.enumerated() {
                log += "\(index): \(frame)\n"
            }
        }

        log += "\n=====================================\n"

        return log
    }
}

/// Service for detecting and logging crashes
final class CrashDetectionService: CrashDetectionProtocol {

    // MARK: - Properties

    private var isMonitoring: Bool = false
    private let crashReportsDirectory: URL
    private let crashMetadataFile: URL
    private var previousExceptionHandler: (@convention(c) (NSException) -> Void)?

    // Signal handlers
    private let signalsToHandle: [Int32] = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE]

    // MARK: - Initialization

    init() {
        // Create crash reports directory
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let crashDir = documentsPath.appendingPathComponent("QCBugPlugin/CrashReports", isDirectory: true)

        self.crashReportsDirectory = crashDir
        self.crashMetadataFile = crashDir.appendingPathComponent("crash_metadata.json")

        // Ensure directory exists
        try? fileManager.createDirectory(at: crashDir, withIntermediateDirectories: true, attributes: nil)
    }

    // MARK: - Public Methods

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true

        // Install exception handler
        installExceptionHandler()

        // Install signal handlers
        installSignalHandlers()

        print("🛡️ QCBugPlugin: Crash detection monitoring started")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false

        // Restore previous exception handler
        if let previous = previousExceptionHandler {
            NSSetUncaughtExceptionHandler(previous)
        } else {
            NSSetUncaughtExceptionHandler(nil)
        }

        print("🛡️ QCBugPlugin: Crash detection monitoring stopped")
    }

    func hasPendingCrashReports() -> Bool {
        return !getPendingCrashReports().isEmpty
    }

    func getPendingCrashReports() -> [CrashReport] {
        guard let data = try? Data(contentsOf: crashMetadataFile),
              let reports = try? JSONDecoder().decode([CrashReport].self, from: data) else {
            return []
        }
        return reports
    }

    func markCrashReportAsHandled(_ crashReport: CrashReport) {
        // For now, marking as handled means deleting it
        deleteCrashReport(crashReport)
    }

    func deleteCrashReport(_ crashReport: CrashReport) {
        var reports = getPendingCrashReports()
        reports.removeAll { $0.identifier == crashReport.identifier }
        saveCrashReports(reports)

        // Delete log file
        let logURL = URL(fileURLWithPath: crashReport.logFilePath)
        try? FileManager.default.removeItem(at: logURL)
    }

    func clearAllCrashReports() {
        let reports = getPendingCrashReports()

        // Delete all log files
        for report in reports {
            let logURL = URL(fileURLWithPath: report.logFilePath)
            try? FileManager.default.removeItem(at: logURL)
        }

        // Clear metadata
        saveCrashReports([])

        print("🗑️ QCBugPlugin: All crash reports cleared")
    }

    // MARK: - Private Methods

    private func installExceptionHandler() {
        // Save previous handler
        previousExceptionHandler = NSGetUncaughtExceptionHandler()

        // Install new handler
        NSSetUncaughtExceptionHandler { exception in
            CrashDetectionService.handleException(exception)
        }
    }

    private func installSignalHandlers() {
        for sig in signalsToHandle {
            Darwin.signal(sig) { signalNumber in
                CrashDetectionService.handleSignal(signalNumber)
            }
        }
    }

    private static func handleException(_ exception: NSException) {
        let instance = CrashDetectionService()

        let stackTrace = exception.callStackSymbols
        let logPath = instance.createCrashLog(
            crashType: .exception,
            exceptionName: exception.name.rawValue,
            exceptionReason: exception.reason,
            stackTrace: stackTrace
        )

        let crashReport = CrashReport(
            crashType: .exception,
            exceptionName: exception.name.rawValue,
            exceptionReason: exception.reason,
            stackTrace: stackTrace,
            logFilePath: logPath
        )

        instance.saveCrashReport(crashReport)

        print("💥 QCBugPlugin: Exception crash detected and logged")
    }

    private static func handleSignal(_ signal: Int32) {
        let instance = CrashDetectionService()

        let signalName = instance.getSignalName(signal)
        let stackTrace = Thread.callStackSymbols

        let logPath = instance.createCrashLog(
            crashType: .signal,
            exceptionName: "Signal \(signalName)",
            exceptionReason: "Application received signal \(signal) (\(signalName))",
            stackTrace: stackTrace
        )

        let crashReport = CrashReport(
            crashType: .signal,
            exceptionName: "Signal \(signalName)",
            exceptionReason: "Application received signal \(signal) (\(signalName))",
            stackTrace: stackTrace,
            logFilePath: logPath
        )

        instance.saveCrashReport(crashReport)

        print("💥 QCBugPlugin: Signal crash detected and logged")

        // Re-raise signal to allow system to handle it
        Darwin.signal(signal, SIG_DFL)
        raise(signal)
    }

    private func getSignalName(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT"
        case SIGILL: return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGFPE: return "SIGFPE"
        case SIGBUS: return "SIGBUS"
        case SIGPIPE: return "SIGPIPE"
        default: return "UNKNOWN"
        }
    }

    private func createCrashLog(
        crashType: CrashReport.CrashType,
        exceptionName: String?,
        exceptionReason: String?,
        stackTrace: [String]
    ) -> String {
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestampString = formatter.string(from: timestamp)

        let filename = "crash_\(timestampString)_\(UUID().uuidString.prefix(8)).log"
        let logURL = crashReportsDirectory.appendingPathComponent(filename)

        let crashReport = CrashReport(
            timestamp: timestamp,
            crashType: crashType,
            exceptionName: exceptionName,
            exceptionReason: exceptionReason,
            stackTrace: stackTrace,
            logFilePath: logURL.path
        )

        let logContent = crashReport.generateLogContent()

        try? logContent.write(to: logURL, atomically: true, encoding: .utf8)

        return logURL.path
    }

    private func saveCrashReport(_ crashReport: CrashReport) {
        var reports = getPendingCrashReports()
        reports.append(crashReport)
        saveCrashReports(reports)
    }

    private func saveCrashReports(_ reports: [CrashReport]) {
        guard let data = try? JSONEncoder().encode(reports) else { return }
        try? data.write(to: crashMetadataFile, options: .atomic)
    }
}

//
//  QCCrashReportAlertController.swift
//  QCBugPlugin
//
//  Created by QCBugPlugin on 11/6/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import UIKit

/// Protocol for crash report alert delegate
protocol QCCrashReportAlertDelegate: AnyObject {
    func crashReportAlertDidSelectReport(_ crashReport: CrashReport)
    func crashReportAlertDidSelectDismiss(_ crashReport: CrashReport)
}

/// Alert controller for presenting crash reports to the user
final class QCCrashReportAlertController {

    weak var delegate: QCCrashReportAlertDelegate?

    /// Present crash report alert
    func presentCrashReportAlert(
        for crashReport: CrashReport,
        from viewController: UIViewController
    ) {
        let alert = createAlert(for: crashReport)
        viewController.present(alert, animated: true)
    }

    /// Present multiple crash reports alert
    func presentMultipleCrashReportsAlert(
        crashReports: [CrashReport],
        from viewController: UIViewController
    ) {
        let count = crashReports.count
        let alert = UIAlertController(
            title: "App Crashed",
            message: "The app crashed \(count) time\(count > 1 ? "s" : "") since you last used it. Would you like to report \(count > 1 ? "these crashes" : "this crash") to help us fix the issue?",
            preferredStyle: .alert
        )

        // Report all crashes
        alert.addAction(UIAlertAction(title: "Report All", style: .default) { [weak self] _ in
            for crashReport in crashReports {
                self?.delegate?.crashReportAlertDidSelectReport(crashReport)
            }
        })

        // Dismiss all
        alert.addAction(UIAlertAction(title: "Dismiss All", style: .cancel) { [weak self] _ in
            for crashReport in crashReports {
                self?.delegate?.crashReportAlertDidSelectDismiss(crashReport)
            }
        })

        viewController.present(alert, animated: true)
    }

    // MARK: - Private Methods

    private func createAlert(for crashReport: CrashReport) -> UIAlertController {
        let title = "App Crashed"

        var message = "The app crashed unexpectedly"
        if let reason = crashReport.exceptionReason, !reason.isEmpty {
            message = reason
        } else if let name = crashReport.exceptionName {
            message = "The app crashed with exception: \(name)"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let timeString = formatter.string(from: crashReport.timestamp)
        message += "\n\nCrash time: \(timeString)"
        message += "\n\nWould you like to report this crash to help us fix the issue?"

        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        // Report crash
        alert.addAction(UIAlertAction(title: "Report", style: .default) { [weak self] _ in
            self?.delegate?.crashReportAlertDidSelectReport(crashReport)
        })

        // View details
        alert.addAction(UIAlertAction(title: "View Details", style: .default) { [weak self] _ in
            self?.showCrashDetails(crashReport)
        })

        // Dismiss
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel) { [weak self] _ in
            self?.delegate?.crashReportAlertDidSelectDismiss(crashReport)
        })

        return alert
    }

    private func showCrashDetails(_ crashReport: CrashReport) {
        guard let topVC = UIApplication.shared.topViewController() else { return }

        let detailAlert = UIAlertController(
            title: "Crash Details",
            message: crashReport.generateLogContent(),
            preferredStyle: .alert
        )

        detailAlert.addAction(UIAlertAction(title: "Report", style: .default) { [weak self] _ in
            self?.delegate?.crashReportAlertDidSelectReport(crashReport)
        })

        detailAlert.addAction(UIAlertAction(title: "Close", style: .cancel) { [weak self] _ in
            self?.delegate?.crashReportAlertDidSelectDismiss(crashReport)
        })

        topVC.present(detailAlert, animated: true)
    }
}

// MARK: - UIApplication Extension

private extension UIApplication {
    func topViewController() -> UIViewController? {
        let keyWindow: UIWindow?
        if #available(iOS 13.0, *) {
            keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
        } else {
            keyWindow = UIApplication.shared.keyWindow
        }

        var topViewController = keyWindow?.rootViewController

        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }

        if let navigationController = topViewController as? UINavigationController {
            topViewController = navigationController.topViewController
        }

        if let tabBarController = topViewController as? UITabBarController {
            topViewController = tabBarController.selectedViewController
        }

        return topViewController
    }
}

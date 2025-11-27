//
//  QCOverlayWindow.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/27/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import UIKit

/// Dedicated overlay window for QCBugPlugin floating UI
/// This window sits above all app windows to ensure floating buttons always stay on top
final class QCOverlayWindow: UIWindow {

    // MARK: - Properties

    /// Callback invoked when device shake gesture is detected
    var shakeHandler: (() -> Void)?

    /// The floating action buttons managed by this window
    private(set) weak var floatingButtons: QCFloatingActionButtons?

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupWindow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupWindow() {
        // Configure window to be always on top
        windowLevel = UIWindow.Level.alert + 1

        // Transparent background so app content shows through
        backgroundColor = .clear

        // Create transparent root view controller (required for shake detection)
        let rootVC = TransparentViewController()
        rootViewController = rootVC
        rootVC.view.backgroundColor = .clear

        // Make window visible but non-key (doesn't steal focus)
        isHidden = false

        // Initially disable interaction (will be enabled only for button areas)
        isUserInteractionEnabled = true

        print("✅ QCOverlayWindow: Initialized at window level \(windowLevel.rawValue)")
    }

    // MARK: - Floating Buttons Management

    /// Attach floating buttons to this overlay window
    func attachFloatingButtons(_ buttons: QCFloatingActionButtons) {
        // Remove from any previous superview
        buttons.removeFromSuperview()

        // Add to this window's root view
        rootViewController?.view.addSubview(buttons)

        // Store weak reference
        floatingButtons = buttons

        print("✅ QCOverlayWindow: Floating buttons attached")
    }

    /// Remove floating buttons from this window
    func detachFloatingButtons() {
        floatingButtons?.removeFromSuperview()
        floatingButtons = nil
        print("🗑️ QCOverlayWindow: Floating buttons detached")
    }

    // MARK: - Shake Detection

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)

        if motion == .motionShake {
            shakeHandler?()
        }
    }

    // MARK: - Touch Handling

    /// Custom hit testing to allow touches to pass through transparent areas
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Convert point to root view coordinate space
        guard let rootView = rootViewController?.view else {
            return nil
        }

        let convertedPoint = convert(point, to: rootView)

        // Check if floating buttons can handle this touch
        if let buttons = floatingButtons,
           !buttons.isHidden,
           buttons.alpha > 0.01 {

            let buttonPoint = rootView.convert(convertedPoint, to: buttons)
            if let hitView = buttons.hitTest(buttonPoint, with: event) {
                return hitView
            }
        }

        // Touch is not within any interactive element, pass through to underlying windows
        return nil
    }
}

// MARK: - Transparent Root View Controller

/// Transparent root view controller for the overlay window
/// This is required for shake gesture detection to work
private final class TransparentViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        // Delegate status bar style to the app's main window
        if #available(iOS 13.0, *) {
            return .default
        } else {
            return .default
        }
    }
}

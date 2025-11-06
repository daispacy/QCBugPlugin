//
//  QCFloatingButton.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import UIKit

/// Floating button for easy access to bug reporting
final class QCFloatingButton: UIButton {
    
    // MARK: - Properties
    private var panGesture: UIPanGestureRecognizer!
    private var lastLocation: CGPoint = .zero
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    private var keyboardHeight: CGFloat = 0

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        setupButton()
        setupGestures()
        setupNotificationObservers()
        positionButton()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupButton() {
        // Appearance - iOS 12 compatible
        if #available(iOS 13.0, *) {
            backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        } else {
            backgroundColor = UIColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 0.9)
        }
        layer.cornerRadius = 30
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.3
        
        // Content
        setTitle("🐛", for: .normal)
        titleLabel?.font = UIFont.systemFont(ofSize: 24)
        
        // Border
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.cgColor
        
        // Animation
        transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        alpha = 0
        
        // Show with animation
        UIView.animate(withDuration: 0.6, delay: 0.5, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.transform = .identity
            self.alpha = 1
        }
    }
    
    private func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)

        // Add touch handlers for visual feedback
        addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    private func setupNotificationObservers() {
        // Orientation changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        // Keyboard events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )

        // Application state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleSceneDidActivate),
                name: UIScene.didActivateNotification,
                object: nil
            )
        }
    }

    private func positionButton() {
        guard let window = UIApplication.shared.windows.first else { return }

        // Position in bottom-right corner with safe area margins
        let safeArea = window.safeAreaInsets
        let margin: CGFloat = 20

        let x = window.bounds.width - frame.width - margin - safeArea.right
        let y = window.bounds.height - frame.height - margin - safeArea.bottom - 100 - keyboardHeight

        frame.origin = CGPoint(x: x, y: y)
        lastLocation = center
    }

    // MARK: - Notification Handlers

    @objc private func handleOrientationChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.ensureVisibleWithinBounds(animated: true)
        }
    }

    @objc private func handleKeyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }

        keyboardHeight = keyboardFrame.height

        UIView.animate(withDuration: duration) { [weak self] in
            self?.ensureVisibleWithinBounds(animated: false)
        }
    }

    @objc private func handleKeyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }

        keyboardHeight = 0

        UIView.animate(withDuration: duration) { [weak self] in
            self?.ensureVisibleWithinBounds(animated: false)
        }
    }

    @objc private func handleSceneDidActivate() {
        ensureVisibleWithinBounds(animated: true)
    }

    @objc private func handleApplicationDidBecomeActive() {
        ensureVisibleWithinBounds(animated: true)
    }

    // MARK: - Visibility Management

    /// Ensures the floating button stays within visible screen bounds
    private func ensureVisibleWithinBounds(animated: Bool) {
        guard let window = UIApplication.shared.windows.first else { return }

        let bounds = window.bounds
        let safeArea = window.safeAreaInsets
        let margin: CGFloat = 20
        let buttonRadius = frame.width / 2

        // Calculate allowed bounds
        let minX = buttonRadius + margin + safeArea.left
        let maxX = bounds.width - buttonRadius - margin - safeArea.right
        let minY = buttonRadius + margin + safeArea.top
        let maxY = bounds.height - buttonRadius - margin - safeArea.bottom - keyboardHeight

        var newCenter = center

        // Clamp to visible bounds
        if newCenter.x < minX {
            newCenter.x = minX
        } else if newCenter.x > maxX {
            newCenter.x = maxX
        }

        if newCenter.y < minY {
            newCenter.y = minY
        } else if newCenter.y > maxY {
            newCenter.y = maxY
        }

        // Update position if needed
        if newCenter != center {
            if animated {
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                    self.center = newCenter
                })
            } else {
                center = newCenter
            }
            lastLocation = newCenter
        }
    }
    
    // MARK: - Gesture Handling
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let window = UIApplication.shared.windows.first else { return }
        
        let translation = gesture.translation(in: window)
        
        switch gesture.state {
        case .began:
            lastLocation = center
            hapticFeedback.impactOccurred()
            
            // Scale down animation
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }
            
        case .changed:
            let newCenter = CGPoint(
                x: lastLocation.x + translation.x,
                y: lastLocation.y + translation.y
            )

            // Keep within screen bounds
            let bounds = window.bounds
            let safeArea = window.safeAreaInsets
            let buttonRadius = frame.width / 2
            let margin: CGFloat = 20

            center = CGPoint(
                x: max(buttonRadius + margin + safeArea.left, min(bounds.width - buttonRadius - margin - safeArea.right, newCenter.x)),
                y: max(buttonRadius + margin + safeArea.top,
                      min(bounds.height - buttonRadius - margin - safeArea.bottom - keyboardHeight, newCenter.y))
            )

        case .ended, .cancelled:
            // Snap to nearest edge
            snapToNearestEdge()

            // Scale back to normal
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                self.transform = .identity
            }

            // Ensure final position is within bounds
            ensureVisibleWithinBounds(animated: true)
            
        default:
            break
        }
    }
    
    private func snapToNearestEdge() {
        guard let window = UIApplication.shared.windows.first else { return }

        let bounds = window.bounds
        let safeArea = window.safeAreaInsets
        let margin: CGFloat = 20
        let buttonRadius = frame.width / 2

        // Determine which edge is closest
        let leftDistance = center.x
        let rightDistance = bounds.width - center.x
        let topDistance = center.y
        let bottomDistance = bounds.height - center.y - keyboardHeight

        let minDistance = min(leftDistance, rightDistance, topDistance, bottomDistance)

        var newCenter = center

        if minDistance == leftDistance {
            // Snap to left edge
            newCenter.x = buttonRadius + margin + safeArea.left
        } else if minDistance == rightDistance {
            // Snap to right edge
            newCenter.x = bounds.width - buttonRadius - margin - safeArea.right
        } else if minDistance == topDistance {
            // Snap to top edge
            newCenter.y = buttonRadius + margin + safeArea.top
        } else {
            // Snap to bottom edge
            newCenter.y = bounds.height - buttonRadius - margin - safeArea.bottom - keyboardHeight
        }

        // Animate to new position
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.center = newCenter
        }

        lastLocation = newCenter
    }
    
    // MARK: - Touch Feedback
    
    @objc private func buttonTouchDown() {
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.alpha = 0.8
        }
    }
    
    @objc private func buttonTouchUp() {
        UIView.animate(withDuration: 0.1) {
            self.transform = .identity
            self.alpha = 1.0
        }
    }
    
    // MARK: - Control Methods
    
    func hide(animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                self.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                self.alpha = 0
            }) { _ in
                self.removeFromSuperview()
            }
        } else {
            removeFromSuperview()
        }
    }
    
    func show(animated: Bool = true) {
        guard let window = UIApplication.shared.windows.first else { return }
        
        if superview == nil {
            window.addSubview(self)
            positionButton()
        }
        
        if animated {
            transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            alpha = 0
            
            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
                self.transform = .identity
                self.alpha = 1
            }
        } else {
            transform = .identity
            alpha = 1
        }
    }
    
    // MARK: - Lifecycle
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
        
        // Clean up gesture recognizer
        if let panGesture = panGesture {
            removeGestureRecognizer(panGesture)
        }
    }
}

// MARK: - Debug Only

#if DEBUG
extension QCFloatingButton {
    
    /// Show debug information overlay
    func showDebugInfo() {
        let debugLabel = UILabel()
        debugLabel.text = "QC Bug Report"
        debugLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        debugLabel.textColor = .white
        debugLabel.textAlignment = .center
        debugLabel.numberOfLines = 2
        debugLabel.frame = bounds.insetBy(dx: 4, dy: 4)
        debugLabel.center = CGPoint(x: bounds.midX, y: bounds.midY + 15)
        
        addSubview(debugLabel)
        
        // Remove debug label after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            debugLabel.removeFromSuperview()
        }
    }
}
#endif
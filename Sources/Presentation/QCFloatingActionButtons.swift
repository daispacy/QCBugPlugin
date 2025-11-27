//
//  QCFloatingActionButtons.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/4/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import UIKit

/// Delegate protocol for floating action buttons
protocol QCFloatingActionButtonsDelegate: AnyObject {
    func floatingButtonsDidTapRecord()
    func floatingButtonsDidTapScreenshot()
    func floatingButtonsDidTapBugReport()
    func floatingButtonsDidTapClearSession()
    func floatingButtonsDidTapStopRecording()
}

/// Floating action buttons container with record, screenshot, form, and session control buttons
final class QCFloatingActionButtons: UIView {

    // MARK: - Properties
    weak var delegate: QCFloatingActionButtonsDelegate?

    private let mainButton: UIButton
    private let recordButton: UIButton
    private let screenshotButton: UIButton
    private let formButton: UIButton
    private let clearSessionButton: UIButton
    private var isExpanded: Bool = false
    private var isRecording: Bool = false
    private let submissionProgressLayer = CAShapeLayer()
    private var isShowingSubmissionProgress = false

    private var panGesture: UIPanGestureRecognizer!
    private var lastLocation: CGPoint = .zero
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    private var keyboardHeight: CGFloat = 0
    private var isSuspended = false

    // MARK: - Initialization

    override init(frame: CGRect) {
        mainButton = UIButton(type: .custom)
    recordButton = UIButton(type: .custom)
    screenshotButton = UIButton(type: .custom)
    formButton = UIButton(type: .custom)
    clearSessionButton = UIButton(type: .custom)

        super.init(frame: CGRect(x: 0, y: 0, width: 60, height: 60))

        setupButtons()
        setupGestures()
        setupNotificationObservers()
        positionView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Lifecycle Overrides

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Window attachment handled by QCOverlayWindow
    }

    // MARK: - Setup

    private func setupButtons() {
        // Main button (Bug report)
        setupMainButton()

        // Record button
        setupRecordButton()

        // Screenshot button
        setupScreenshotButton()

        // Form button
        setupFormButton()

        // Clear session button
        setupClearSessionButton()

        // Add to view
        addSubview(recordButton)
        addSubview(screenshotButton)
        addSubview(formButton)
        addSubview(clearSessionButton)
        addSubview(mainButton)

        // Initially hide action buttons
        recordButton.alpha = 0
        recordButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        screenshotButton.alpha = 0
        screenshotButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        formButton.alpha = 0
        formButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        clearSessionButton.alpha = 0
        clearSessionButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        clipsToBounds = false
        isUserInteractionEnabled = true
    }

    private func setupMainButton() {
        mainButton.frame = CGRect(x: 0, y: 0, width: 60, height: 60)

        if #available(iOS 13.0, *) {
            mainButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        } else {
            mainButton.backgroundColor = UIColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 0.9)
        }

        mainButton.layer.cornerRadius = 30
        mainButton.layer.shadowColor = UIColor.black.cgColor
        mainButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        mainButton.layer.shadowRadius = 8
        mainButton.layer.shadowOpacity = 0.3
        mainButton.layer.borderWidth = 2
        mainButton.layer.borderColor = UIColor.white.cgColor

        mainButton.setTitle("🐛", for: .normal)
        mainButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)

        mainButton.addTarget(self, action: #selector(mainButtonTapped), for: .touchUpInside)

        configureSubmissionProgressLayer()
    }

    private func setupRecordButton() {
        recordButton.frame = CGRect(x: 0, y: 0, width: 50, height: 50)

        if #available(iOS 13.0, *) {
            recordButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
        } else {
            recordButton.backgroundColor = UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 0.9)
        }

        recordButton.layer.cornerRadius = 25
        recordButton.layer.shadowColor = UIColor.black.cgColor
        recordButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        recordButton.layer.shadowRadius = 6
        recordButton.layer.shadowOpacity = 0.3
        recordButton.layer.borderWidth = 2
        recordButton.layer.borderColor = UIColor.white.cgColor

        recordButton.setTitle("🎥", for: .normal)
        recordButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)

        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
    }

    private func setupScreenshotButton() {
        screenshotButton.frame = CGRect(x: 0, y: 0, width: 50, height: 50)

        if #available(iOS 13.0, *) {
            screenshotButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        } else {
            screenshotButton.backgroundColor = UIColor(red: 0.298, green: 0.851, blue: 0.392, alpha: 0.9)
        }

        screenshotButton.layer.cornerRadius = 25
        screenshotButton.layer.shadowColor = UIColor.black.cgColor
        screenshotButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        screenshotButton.layer.shadowRadius = 6
        screenshotButton.layer.shadowOpacity = 0.3
        screenshotButton.layer.borderWidth = 2
        screenshotButton.layer.borderColor = UIColor.white.cgColor

        screenshotButton.setTitle("📸", for: .normal)
        screenshotButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)

        screenshotButton.addTarget(self, action: #selector(screenshotButtonTapped), for: .touchUpInside)
    }
    
    private func setupFormButton() {
        formButton.frame = CGRect(x: 0, y: 0, width: 50, height: 50)

        if #available(iOS 13.0, *) {
            formButton.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.9)
        } else {
            formButton.backgroundColor = UIColor(red: 0.694, green: 0.282, blue: 0.835, alpha: 0.9)
        }

        formButton.layer.cornerRadius = 25
        formButton.layer.shadowColor = UIColor.black.cgColor
        formButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        formButton.layer.shadowRadius = 6
        formButton.layer.shadowOpacity = 0.3
        formButton.layer.borderWidth = 2
        formButton.layer.borderColor = UIColor.white.cgColor

        formButton.setTitle("📝", for: .normal)
        formButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        formButton.accessibilityLabel = "Open Bug Report Form"

        formButton.addTarget(self, action: #selector(formButtonTapped), for: .touchUpInside)
    }
    
    private func setupClearSessionButton() {
        clearSessionButton.frame = CGRect(x: 0, y: 0, width: 50, height: 50)

        if #available(iOS 13.0, *) {
            clearSessionButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.9)
        } else {
            clearSessionButton.backgroundColor = UIColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 0.9)
        }

        clearSessionButton.layer.cornerRadius = 25
        clearSessionButton.layer.shadowColor = UIColor.black.cgColor
        clearSessionButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        clearSessionButton.layer.shadowRadius = 6
        clearSessionButton.layer.shadowOpacity = 0.3
        clearSessionButton.layer.borderWidth = 2
        clearSessionButton.layer.borderColor = UIColor.white.cgColor

        clearSessionButton.setTitle("🗑️", for: .normal)
        clearSessionButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        clearSessionButton.accessibilityLabel = "Clear Bug Session"

        clearSessionButton.addTarget(self, action: #selector(clearSessionButtonTapped), for: .touchUpInside)
    }

    private func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        mainButton.addGestureRecognizer(panGesture)
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
    }

    private func positionView() {
        let window: UIWindow?
        if #available(iOS 13.0, *) {
            window = UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIApplication.shared.windows.first
        } else {
            window = UIApplication.shared.keyWindow ?? UIApplication.shared.windows.first
        }

        guard let window = window else { return }

        let safeArea = window.safeAreaInsets
        let margin: CGFloat = 20

        let x = window.bounds.width - 60 - margin - safeArea.right
        let y = window.bounds.height - 60 - margin - safeArea.bottom - 100 - keyboardHeight

        frame.origin = CGPoint(x: x, y: y)
        lastLocation = center
    }

    // MARK: - Notification Handlers

    @objc private func handleOrientationChange() {
        // Collapse expanded buttons during orientation change
        if isExpanded {
            collapse()
        }

        // Ensure button stays within visible bounds after orientation change
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

        // Collapse if expanded
        if isExpanded {
            collapse()
        }

        // Move button above keyboard
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

        // Restore button position
        UIView.animate(withDuration: duration) { [weak self] in
            self?.ensureVisibleWithinBounds(animated: false)
        }
    }

    // MARK: - Visibility Management

    func setSuspended(_ suspended: Bool) {
        isSuspended = suspended
    }

    /// Ensures the floating button stays within visible screen bounds
    private func ensureVisibleWithinBounds(animated: Bool) {
        let window: UIWindow?
        if #available(iOS 13.0, *) {
            window = UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIApplication.shared.windows.first
        } else {
            window = UIApplication.shared.keyWindow ?? UIApplication.shared.windows.first
        }

        guard let window = window else { return }

        let bounds = window.bounds
        let safeArea = window.safeAreaInsets
        let margin: CGFloat = 20
        let halfWidth = frame.width / 2
        let halfHeight = frame.height / 2

        // Calculate allowed bounds considering safe area and keyboard
        let minX = halfWidth + margin + safeArea.left
        let maxX = bounds.width - halfWidth - margin - safeArea.right
        let minY = halfHeight + margin + safeArea.top
        let maxY = bounds.height - halfHeight - margin - safeArea.bottom - keyboardHeight

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

    // MARK: - Submission Progress

    private func configureSubmissionProgressLayer() {
        submissionProgressLayer.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
        submissionProgressLayer.fillColor = UIColor.clear.cgColor
        submissionProgressLayer.lineWidth = 3
        submissionProgressLayer.lineCap = .round
        submissionProgressLayer.strokeStart = 0
        submissionProgressLayer.strokeEnd = 0.25
        submissionProgressLayer.zPosition = 1
        submissionProgressLayer.isHidden = true
        submissionProgressLayer.opacity = 0
        mainButton.layer.addSublayer(submissionProgressLayer)
        updateSubmissionProgressPath()
    }

    private func updateSubmissionProgressPath() {
        let inset: CGFloat = -6
        let pathRect = mainButton.bounds.insetBy(dx: inset, dy: inset)
        submissionProgressLayer.frame = mainButton.bounds
        submissionProgressLayer.path = UIBezierPath(ovalIn: pathRect).cgPath
    }

    func showSubmissionProgress() {
        guard !isShowingSubmissionProgress else { return }
        isShowingSubmissionProgress = true
        updateSubmissionProgressPath()
        submissionProgressLayer.isHidden = false
        submissionProgressLayer.opacity = 1
        submissionProgressLayer.strokeStart = 0
        submissionProgressLayer.strokeEnd = 0.25

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = 2 * CGFloat.pi
        rotation.duration = 1.1
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        submissionProgressLayer.add(rotation, forKey: "qcSubmissionSpin")
    }

    func hideSubmissionProgress() {
        guard isShowingSubmissionProgress else { return }
        isShowingSubmissionProgress = false
        submissionProgressLayer.removeAnimation(forKey: "qcSubmissionSpin")
        submissionProgressLayer.isHidden = true
        submissionProgressLayer.opacity = 0
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updateSubmissionProgressPath()
    }

    // MARK: - Actions

    @objc private func mainButtonTapped() {
        if isRecording {
            // Stop recording when main button is tapped during recording
            hapticFeedback.impactOccurred()
            delegate?.floatingButtonsDidTapStopRecording()
        } else if isExpanded {
            collapse()
        } else {
            expand()
        }
    }

    @objc private func recordButtonTapped() {
        hapticFeedback.impactOccurred()
        collapse()
        delegate?.floatingButtonsDidTapRecord()
    }

    @objc private func screenshotButtonTapped() {
        hapticFeedback.impactOccurred()
        collapse()
        delegate?.floatingButtonsDidTapScreenshot()
    }
    
    @objc private func formButtonTapped() {
        hapticFeedback.impactOccurred()
        collapse()
        delegate?.floatingButtonsDidTapBugReport()
    }
    
    @objc private func clearSessionButtonTapped() {
        hapticFeedback.impactOccurred()
        collapse()
        delegate?.floatingButtonsDidTapClearSession()
    }

    // MARK: - Expand/Collapse

    private func expand() {
        guard !isExpanded else { return }
        isExpanded = true

        hapticFeedback.impactOccurred()

        // Calculate positions - keep main button fixed, expand upward
        let spacing: CGFloat = 70

        // Calculate desired positions relative to main button
        let recordY = mainButton.center.y - spacing
        let screenshotY = recordY - spacing
        let formY = screenshotY - spacing
        let clearSessionY = formY - spacing

        // Position all buttons at main button center initially
        recordButton.center = mainButton.center
        screenshotButton.center = mainButton.center
        formButton.center = mainButton.center
        clearSessionButton.center = mainButton.center

        // Animate expansion upward from main button position
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            // Rotate main button to show expanded state
            self.mainButton.transform = CGAffineTransform(rotationAngle: .pi / 4)

            // Expand buttons upward from main button
            self.recordButton.center.y = recordY
            self.recordButton.alpha = 1
            self.recordButton.transform = .identity

            self.screenshotButton.center.y = screenshotY
            self.screenshotButton.alpha = 1
            self.screenshotButton.transform = .identity

            self.formButton.center.y = formY
            self.formButton.alpha = 1
            self.formButton.transform = .identity

            self.clearSessionButton.center.y = clearSessionY
            self.clearSessionButton.alpha = 1
            self.clearSessionButton.transform = .identity
        })
    }

    private func collapse() {
        guard isExpanded else { return }
        isExpanded = false

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            // Reset main button rotation
            self.mainButton.transform = .identity

            // Collapse all action buttons back to main button center
            self.recordButton.center = self.mainButton.center
            self.recordButton.alpha = 0
            self.recordButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)

            self.screenshotButton.center = self.mainButton.center
            self.screenshotButton.alpha = 0
            self.screenshotButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)

            self.formButton.center = self.mainButton.center
            self.formButton.alpha = 0
            self.formButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)

            self.clearSessionButton.center = self.mainButton.center
            self.clearSessionButton.alpha = 0
            self.clearSessionButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        })
    }

    // MARK: - Gesture Handling

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let window: UIWindow?
        if #available(iOS 13.0, *) {
            window = UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIApplication.shared.windows.first
        } else {
            window = UIApplication.shared.keyWindow ?? UIApplication.shared.windows.first
        }

        guard let window = window else { return }

        let translation = gesture.translation(in: window)

        switch gesture.state {
        case .began:
            lastLocation = center
            hapticFeedback.impactOccurred()

            // Collapse if expanded
            if isExpanded {
                collapse()
            }

            UIView.animate(withDuration: 0.2) {
                self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }

        case .changed:
            let newCenter = CGPoint(
                x: lastLocation.x + translation.x,
                y: lastLocation.y + translation.y
            )

            let bounds = window.bounds
            let safeArea = window.safeAreaInsets
            let halfWidth = frame.width / 2
            let margin: CGFloat = 20

            center = CGPoint(
                x: max(halfWidth + margin + safeArea.left, min(bounds.width - halfWidth - margin - safeArea.right, newCenter.x)),
                y: max(halfWidth + margin + safeArea.top,
                      min(bounds.height - halfWidth - margin - safeArea.bottom - keyboardHeight, newCenter.y))
            )

        case .ended, .cancelled:
            snapToNearestEdge()

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
        let window: UIWindow?
        if #available(iOS 13.0, *) {
            window = UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIApplication.shared.windows.first
        } else {
            window = UIApplication.shared.keyWindow ?? UIApplication.shared.windows.first
        }

        guard let window = window else { return }

        let bounds = window.bounds
        let safeArea = window.safeAreaInsets
        let margin: CGFloat = 20
        let halfWidth = frame.width / 2
        let halfHeight = frame.height / 2

        let leftDistance = center.x
        let rightDistance = bounds.width - center.x

        var newCenter = center

        // Snap to left or right edge
        if leftDistance < rightDistance {
            newCenter.x = halfWidth + margin + safeArea.left
        } else {
            newCenter.x = bounds.width - halfWidth - margin - safeArea.right
        }

        // Ensure Y position is within bounds (considering keyboard)
        let minY = halfHeight + margin + safeArea.top
        let maxY = bounds.height - halfHeight - margin - safeArea.bottom - keyboardHeight

        if newCenter.y < minY {
            newCenter.y = minY
        } else if newCenter.y > maxY {
            newCenter.y = maxY
        }

        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.center = newCenter
        }

        lastLocation = newCenter
    }

    // MARK: - Hit Testing for Touch Events
    
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Check if the point is within the main button
        let mainButtonPoint = convert(point, to: mainButton)
        if mainButton.bounds.contains(mainButtonPoint) {
            return mainButton.hitTest(mainButtonPoint, with: event) ?? mainButton
        }
        
        // Check if the point is within the record button
        let recordButtonPoint = convert(point, to: recordButton)
        if recordButton.bounds.contains(recordButtonPoint) && recordButton.alpha > 0 {
            return recordButton.hitTest(recordButtonPoint, with: event) ?? recordButton
        }
        
        // Check if the point is within the screenshot button
        let screenshotButtonPoint = convert(point, to: screenshotButton)
        if screenshotButton.bounds.contains(screenshotButtonPoint) && screenshotButton.alpha > 0 {
            return screenshotButton.hitTest(screenshotButtonPoint, with: event) ?? screenshotButton
        }
        
        // Check if the point is within the form button
        let formButtonPoint = convert(point, to: formButton)
        if formButton.bounds.contains(formButtonPoint) && formButton.alpha > 0 {
            return formButton.hitTest(formButtonPoint, with: event) ?? formButton
        }
        
        // Check if the point is within the clear session button
        let clearSessionButtonPoint = convert(point, to: clearSessionButton)
        if clearSessionButton.bounds.contains(clearSessionButtonPoint) && clearSessionButton.alpha > 0 {
            return clearSessionButton.hitTest(clearSessionButtonPoint, with: event) ?? clearSessionButton
        }
        
        // If point is not within any button, return nil to allow touches to pass through
        return nil
    }

    // MARK: - Control Methods

    func updateRecordingState(isRecording: Bool) {
        DispatchQueue.main.async {
            self.isRecording = isRecording

            if isRecording {
                // Change main button to Stop
                self.mainButton.setTitle("⏹️", for: .normal)
                if #available(iOS 13.0, *) {
                    self.mainButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
                } else {
                    self.mainButton.backgroundColor = UIColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 0.9)
                }

                // Collapse expanded menu when recording starts
                if self.isExpanded {
                    self.collapse()
                }

                // Update record button
                self.recordButton.setTitle("⏹️", for: .normal)
            } else {
                // Change main button back to Bug
                self.mainButton.setTitle("🐛", for: .normal)
                if #available(iOS 13.0, *) {
                    self.mainButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
                } else {
                    self.mainButton.backgroundColor = UIColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 0.9)
                }

                // Update record button
                self.recordButton.setTitle("🎥", for: .normal)
            }
        }
    }

    func hide(animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                self.alpha = 0
                self.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            }) { _ in
                self.removeFromSuperview()
            }
        } else {
            removeFromSuperview()
        }
    }

    func show(animated: Bool = true) {
        // Position view if needed
        if superview != nil {
            positionView()
        }

        if animated {
            alpha = 0
            transform = CGAffineTransform(scaleX: 0.1, y: 0.1)

            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
                self.alpha = 1
                self.transform = .identity
            }
        } else {
            alpha = 1
            transform = .identity
        }
    }
}

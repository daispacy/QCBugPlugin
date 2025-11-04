//
//  QCFloatingActionButtons.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/4/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import UIKit

/// Delegate protocol for floating action buttons
public protocol QCFloatingActionButtonsDelegate: AnyObject {
    func floatingButtonsDidTapRecord()
    func floatingButtonsDidTapScreenshot()
    func floatingButtonsDidTapBugReport()
}

/// Floating action buttons container with record, screenshot, and bug report buttons
public final class QCFloatingActionButtons: UIView {

    // MARK: - Properties
    public weak var delegate: QCFloatingActionButtonsDelegate?

    private let mainButton: UIButton
    private let recordButton: UIButton
    private let screenshotButton: UIButton
    private var isExpanded: Bool = false

    private var panGesture: UIPanGestureRecognizer!
    private var lastLocation: CGPoint = .zero
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Initialization

    public override init(frame: CGRect) {
        mainButton = UIButton(type: .custom)
        recordButton = UIButton(type: .custom)
        screenshotButton = UIButton(type: .custom)

        super.init(frame: CGRect(x: 0, y: 0, width: 60, height: 60))

        setupButtons()
        setupGestures()
        positionView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupButtons() {
        // Main button (Bug report)
        setupMainButton()

        // Record button
        setupRecordButton()

        // Screenshot button
        setupScreenshotButton()

        // Add to view
        addSubview(recordButton)
        addSubview(screenshotButton)
        addSubview(mainButton)

        // Initially hide action buttons
        recordButton.alpha = 0
        recordButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        screenshotButton.alpha = 0
        screenshotButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
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

    private func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        mainButton.addGestureRecognizer(panGesture)
    }

    private func positionView() {
        guard let window = UIApplication.shared.windows.first else { return }

        let safeArea = window.safeAreaInsets
        let margin: CGFloat = 20

        let x = window.bounds.width - 60 - margin - safeArea.right
        let y = window.bounds.height - 60 - margin - safeArea.bottom - 100

        frame.origin = CGPoint(x: x, y: y)
        lastLocation = center
    }

    // MARK: - Actions

    @objc private func mainButtonTapped() {
        if isExpanded {
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

    // MARK: - Expand/Collapse

    private func expand() {
        guard !isExpanded else { return }
        isExpanded = true

        hapticFeedback.impactOccurred()

        // Calculate positions
        let spacing: CGFloat = 70
        let recordY = mainButton.center.y - spacing
        let screenshotY = recordY - spacing

        recordButton.center = mainButton.center
        screenshotButton.center = mainButton.center

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            self.mainButton.transform = CGAffineTransform(rotationAngle: .pi / 4)

            self.recordButton.center.y = recordY
            self.recordButton.alpha = 1
            self.recordButton.transform = .identity

            self.screenshotButton.center.y = screenshotY
            self.screenshotButton.alpha = 1
            self.screenshotButton.transform = .identity
        })
    }

    private func collapse() {
        guard isExpanded else { return }
        isExpanded = false

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            self.mainButton.transform = .identity

            self.recordButton.center = self.mainButton.center
            self.recordButton.alpha = 0
            self.recordButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)

            self.screenshotButton.center = self.mainButton.center
            self.screenshotButton.alpha = 0
            self.screenshotButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        })
    }

    // MARK: - Gesture Handling

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let window = UIApplication.shared.windows.first else { return }

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
            let halfWidth = frame.width / 2

            center = CGPoint(
                x: max(halfWidth, min(bounds.width - halfWidth, newCenter.x)),
                y: max(halfWidth + window.safeAreaInsets.top,
                      min(bounds.height - halfWidth - window.safeAreaInsets.bottom, newCenter.y))
            )

        case .ended, .cancelled:
            snapToNearestEdge()

            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                self.transform = .identity
            }

        default:
            break
        }
    }

    private func snapToNearestEdge() {
        guard let window = UIApplication.shared.windows.first else { return }

        let bounds = window.bounds
        let safeArea = window.safeAreaInsets
        let margin: CGFloat = 20
        let halfWidth = frame.width / 2

        let leftDistance = center.x
        let rightDistance = bounds.width - center.x

        var newCenter = center

        if leftDistance < rightDistance {
            newCenter.x = halfWidth + margin + safeArea.left
        } else {
            newCenter.x = bounds.width - halfWidth - margin - safeArea.right
        }

        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.center = newCenter
        }

        lastLocation = newCenter
    }

    // MARK: - Hit Testing for Touch Events
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
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
        
        // If point is not within any button, return nil to allow touches to pass through
        return nil
    }

    // MARK: - Public Methods

    public func updateRecordingState(isRecording: Bool) {
        DispatchQueue.main.async {
            if isRecording {
                self.recordButton.setTitle("⏹️", for: .normal)
            } else {
                self.recordButton.setTitle("🎥", for: .normal)
            }
        }
    }

    public func hide(animated: Bool = true) {
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

    public func show(animated: Bool = true) {
        guard let window = UIApplication.shared.windows.first else { return }

        if superview == nil {
            window.addSubview(self)
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

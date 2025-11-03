//
//  UITrackingService.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import UIKit
import ObjectiveC

/// Service for tracking user interactions using method swizzling
public final class UITrackingService: NSObject, UITrackingProtocol {
    
    // MARK: - Properties
    private var actionHistory: [UserAction] = []
    internal var _isTracking: Bool = false
    private let actionQueue = DispatchQueue(label: "com.qcbugplugin.actionqueue", qos: .utility)
    
    public weak var delegate: UITrackingDelegate?
    
    public var isTracking: Bool {
        return _isTracking
    }
    
    public var maxActionHistoryCount: Int = 50 {
        didSet {
            trimHistoryIfNeeded()
        }
    }
    
    // MARK: - Initialization
    
    /// Public initializer for UITrackingService
    public override init() {
        super.init()
    }
    
    // MARK: - UITrackingProtocol Implementation
    
    public func startTracking() {
        guard !_isTracking else { return }
        
        _isTracking = true
        swizzleMethods()
        print("🎯 UITrackingService: Started tracking UI interactions")
    }
    
    public func stopTracking() {
        guard _isTracking else { return }
        
        _isTracking = false
        unswizzleMethods()
        print("⏹️ UITrackingService: Stopped tracking UI interactions")
    }
    
    public func getActionHistory() -> [UserAction] {
        return actionQueue.sync {
            return Array(actionHistory)
        }
    }
    
    public func clearActionHistory() {
        actionQueue.async { [weak self] in
            self?.actionHistory.removeAll()
            
            DispatchQueue.main.async {
                self?.delegate?.didClearActionHistory()
            }
        }
    }
    
    // MARK: - Private Methods
    
    internal func addAction(_ action: UserAction) {
        actionQueue.async { [weak self] in
            guard let self = self, self._isTracking else { return }
            
            self.actionHistory.append(action)
            self.trimHistoryIfNeeded()
            
            DispatchQueue.main.async {
                self.delegate?.didTrackUserAction(action)
                
                NotificationCenter.default.post(
                    name: .qcBugPluginDidTrackUserAction,
                    object: self,
                    userInfo: ["action": action]
                )
            }
        }
    }
    
    private func trimHistoryIfNeeded() {
        if actionHistory.count > maxActionHistoryCount {
            let excess = actionHistory.count - maxActionHistoryCount
            actionHistory.removeFirst(excess)
        }
    }
    
    internal func getCurrentScreenInfo() -> (String, String) {
        guard let topVC = UIApplication.shared.topViewController() else {
            return ("Unknown", "Unknown")
        }
        
        let className = String(describing: type(of: topVC))
        let screenName = topVC.title ?? topVC.navigationItem.title ?? className
        
        return (screenName, className)
    }
}

// MARK: - Method Swizzling

extension UITrackingService {
    
    private func swizzleMethods() {
        swizzleViewControllerMethods()
        swizzleButtonMethods()
        swizzleTextFieldMethods()
        swizzleGestureMethods()
    }
    
    private func unswizzleMethods() {
        // Restore original methods
        swizzleViewControllerMethods() // Swizzling again restores original
        swizzleButtonMethods()
        swizzleTextFieldMethods()
        swizzleGestureMethods()
    }
    
    private func swizzleViewControllerMethods() {
        swizzleMethod(
            class: UIViewController.self,
            originalSelector: #selector(UIViewController.viewDidAppear(_:)),
            swizzledSelector: #selector(UIViewController.qcBugPlugin_viewDidAppear(_:))
        )
        
        swizzleMethod(
            class: UIViewController.self,
            originalSelector: #selector(UIViewController.viewDidDisappear(_:)),
            swizzledSelector: #selector(UIViewController.qcBugPlugin_viewDidDisappear(_:))
        )
    }
    
    private func swizzleButtonMethods() {
        swizzleMethod(
            class: UIButton.self,
            originalSelector: #selector(UIButton.sendAction(_:to:for:)),
            swizzledSelector: #selector(UIButton.qcBugPlugin_sendAction(_:to:for:))
        )
    }
    
    private func swizzleTextFieldMethods() {
        swizzleMethod(
            class: UITextField.self,
            originalSelector: #selector(UITextField.becomeFirstResponder),
            swizzledSelector: #selector(UITextField.qcBugPlugin_becomeFirstResponder)
        )
    }
    
    private func swizzleGestureMethods() {
        swizzleMethod(
            class: UITapGestureRecognizer.self,
            originalSelector: #selector(UITapGestureRecognizer.touchesBegan(_:with:)),
            swizzledSelector: #selector(UITapGestureRecognizer.qcBugPlugin_touchesBegan(_:with:))
        )
    }
    
    private func swizzleMethod(class: AnyClass, originalSelector: Selector, swizzledSelector: Selector) {
        guard let originalMethod = class_getInstanceMethod(`class`, originalSelector),
              let swizzledMethod = class_getInstanceMethod(`class`, swizzledSelector) else {
            return
        }
        
        let didAddMethod = class_addMethod(
            `class`,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )
        
        if didAddMethod {
            class_replaceMethod(
                `class`,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}

// MARK: - UIViewController Swizzled Methods

extension UIViewController {
    
    @objc dynamic func qcBugPlugin_viewDidAppear(_ animated: Bool) {
        qcBugPlugin_viewDidAppear(animated) // Call original method
        
        // Track screen view
        if let tracker = UITrackingService.shared as? UITrackingService,
           tracker._isTracking {
            let className = String(describing: type(of: self))
            let screenName = self.title ?? self.navigationItem.title ?? className
            
            let action = UserAction.screenView(
                screenName: screenName,
                viewControllerClass: className
            )
            
            tracker.addAction(action)
        }
    }
    
    @objc dynamic func qcBugPlugin_viewDidDisappear(_ animated: Bool) {
        qcBugPlugin_viewDidDisappear(animated) // Call original method
        
        // Track screen disappear
        if let tracker = UITrackingService.shared as? UITrackingService,
           tracker._isTracking {
            let className = String(describing: type(of: self))
            let screenName = self.title ?? self.navigationItem.title ?? className
            
            let action = UserAction(
                actionType: .screenDisappear,
                screenName: screenName,
                viewControllerClass: className
            )
            
            tracker.addAction(action)
        }
    }
}

// MARK: - UIButton Swizzled Methods

extension UIButton {
    
    @objc dynamic func qcBugPlugin_sendAction(_ action: Selector, to target: Any?, for event: UIEvent?) {
        qcBugPlugin_sendAction(action, to: target, for: event) // Call original method
        
        // Track button tap
        if let tracker = UITrackingService.shared as? UITrackingService,
           tracker._isTracking,
           let touch = event?.allTouches?.first {
            
            let (screenName, className) = tracker.getCurrentScreenInfo()
            let coordinates = touch.location(in: self)
            
            let elementInfo = ElementInfo(
                accessibilityIdentifier: self.accessibilityIdentifier,
                accessibilityLabel: self.accessibilityLabel,
                className: String(describing: type(of: self)),
                text: self.currentTitle,
                tag: self.tag != 0 ? self.tag : nil,
                frame: self.frame
            )
            
            let userAction = UserAction.buttonTap(
                screenName: screenName,
                viewControllerClass: className,
                elementInfo: elementInfo,
                coordinates: coordinates
            )
            
            tracker.addAction(userAction)
        }
    }
}

// MARK: - UITextField Swizzled Methods

extension UITextField {
    
    @objc dynamic func qcBugPlugin_becomeFirstResponder() -> Bool {
        let result = qcBugPlugin_becomeFirstResponder() // Call original method
        
        // Track text field tap
        if let tracker = UITrackingService.shared as? UITrackingService,
           tracker._isTracking && result {
            let (screenName, className) = tracker.getCurrentScreenInfo()
            
            let elementInfo = ElementInfo(
                accessibilityIdentifier: self.accessibilityIdentifier,
                accessibilityLabel: self.accessibilityLabel,
                className: String(describing: type(of: self)),
                text: self.text,
                tag: self.tag != 0 ? self.tag : nil,
                frame: self.frame
            )
            
            let action = UserAction(
                actionType: .textFieldTap,
                screenName: screenName,
                viewControllerClass: className,
                elementInfo: elementInfo,
                coordinates: CGPoint(x: self.frame.midX, y: self.frame.midY)
            )
            
            tracker.addAction(action)
        }
        
        return result
    }
}

// MARK: - UITapGestureRecognizer Swizzled Methods

extension UITapGestureRecognizer {
    
    @objc dynamic func qcBugPlugin_touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        qcBugPlugin_touchesBegan(touches, with: event) // Call original method
        
        // Track tap gesture
        if let tracker = UITrackingService.shared as? UITrackingService,
           tracker._isTracking,
           let touch = touches.first,
           let view = self.view {
            
            let (screenName, className) = tracker.getCurrentScreenInfo()
            let coordinates = touch.location(in: view)
            
            let elementInfo = ElementInfo(
                accessibilityIdentifier: view.accessibilityIdentifier,
                accessibilityLabel: view.accessibilityLabel,
                className: String(describing: type(of: view)),
                text: nil,
                tag: view.tag != 0 ? view.tag : nil,
                frame: view.frame
            )
            
            let action = UserAction(
                actionType: .buttonTap, // Generic tap
                screenName: screenName,
                viewControllerClass: className,
                elementInfo: elementInfo,
                coordinates: coordinates
            )
            
            tracker.addAction(action)
        }
    }
}

// MARK: - Singleton Access

extension UITrackingService {
    static let shared = UITrackingService()
}

// MARK: - UIApplication Extension

private extension UIApplication {
    func topViewController() -> UIViewController? {
        // iOS 12 compatible window access
        let window: UIWindow?
        if #available(iOS 13.0, *) {
            window = windows.first(where: { $0.isKeyWindow })
        } else {
            window = keyWindow
        }
        
        guard let rootWindow = window else { return nil }
        return topViewController(from: rootWindow.rootViewController)
    }
    
    private func topViewController(from viewController: UIViewController?) -> UIViewController? {
        if let navigationController = viewController as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        }
        
        if let tabBarController = viewController as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController)
        }
        
        if let presentedViewController = viewController?.presentedViewController {
            return topViewController(from: presentedViewController)
        }
        
        return viewController
    }
}
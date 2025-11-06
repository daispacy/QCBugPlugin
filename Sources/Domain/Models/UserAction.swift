//
//  UserAction.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import UIKit

/// Represents a user action that was tracked
struct UserAction: Codable {
    /// Unique identifier for the action
    let id: String
    
    /// Timestamp when the action occurred
    let timestamp: Date
    
    /// Type of action performed
    let actionType: ActionType
    
    /// Name of the screen where action occurred
    let screenName: String
    
    /// Class name of the view controller
    let viewControllerClass: String
    
    /// Information about the UI element (if applicable)
    let elementInfo: ElementInfo?
    
    /// Coordinates where the action occurred (if applicable)
    let coordinates: CGPoint?
    
    /// Additional context data
    let metadata: [String: String]?
    
    init(
        actionType: ActionType,
        screenName: String,
        viewControllerClass: String,
        elementInfo: ElementInfo? = nil,
        coordinates: CGPoint? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.actionType = actionType
        self.screenName = screenName
        self.viewControllerClass = viewControllerClass
        self.elementInfo = elementInfo
        self.coordinates = coordinates
        self.metadata = metadata
    }
}

/// Types of user actions that can be tracked
enum ActionType: String, Codable, CaseIterable {
    case screenView = "screen_view"
    case screenDisappear = "screen_disappear"
    case buttonTap = "button_tap"
    case textInput = "text_input"
    case textFieldTap = "textfield_tap"
    case scroll = "scroll"
    case swipe = "swipe"
    case pinch = "pinch"
    case longPress = "long_press"
    case segmentedControlTap = "segmented_control_tap"
    case switchToggle = "switch_toggle"
    case sliderChange = "slider_change"
    case alertAction = "alert_action"
    case navigationBack = "navigation_back"
    case tabChange = "tab_change"
    case modalPresent = "modal_present"
    case modalDismiss = "modal_dismiss"
    
    var displayName: String {
        switch self {
        case .screenView: return "Screen View"
        case .screenDisappear: return "Screen Disappear"
        case .buttonTap: return "Button Tap"
        case .textInput: return "Text Input"
        case .textFieldTap: return "TextField Tap"
        case .scroll: return "Scroll"
        case .swipe: return "Swipe"
        case .pinch: return "Pinch"
        case .longPress: return "Long Press"
        case .segmentedControlTap: return "Segmented Control"
        case .switchToggle: return "Switch Toggle"
        case .sliderChange: return "Slider Change"
        case .alertAction: return "Alert Action"
        case .navigationBack: return "Navigation Back"
        case .tabChange: return "Tab Change"
        case .modalPresent: return "Modal Present"
        case .modalDismiss: return "Modal Dismiss"
        }
    }
}

/// Information about a UI element
struct ElementInfo: Codable {
    /// Accessibility identifier
    let accessibilityIdentifier: String?
    
    /// Accessibility label
    let accessibilityLabel: String?
    
    /// Element class name
    let className: String
    
    /// Element text (for buttons, labels, etc.)
    let text: String?
    
    /// Element tag
    let tag: Int?
    
    /// Element frame
    let frame: CGRect?
    
    init(
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil,
        className: String,
        text: String? = nil,
        tag: Int? = nil,
        frame: CGRect? = nil
    ) {
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.className = className
        self.text = text
        self.tag = tag
        self.frame = frame
    }
}

// MARK: - Extensions for better usability

extension UserAction {
    /// Create a screen view action
    static func screenView(
        screenName: String,
        viewControllerClass: String,
        metadata: [String: String]? = nil
    ) -> UserAction {
        return UserAction(
            actionType: .screenView,
            screenName: screenName,
            viewControllerClass: viewControllerClass,
            metadata: metadata
        )
    }
    
    /// Create a button tap action
    static func buttonTap(
        screenName: String,
        viewControllerClass: String,
        elementInfo: ElementInfo,
        coordinates: CGPoint,
        metadata: [String: String]? = nil
    ) -> UserAction {
        return UserAction(
            actionType: .buttonTap,
            screenName: screenName,
            viewControllerClass: viewControllerClass,
            elementInfo: elementInfo,
            coordinates: coordinates,
            metadata: metadata
        )
    }
}
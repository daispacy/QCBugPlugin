//
//  UITrackingProtocol.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation
import UIKit

/// Protocol for tracking user interactions
public protocol UITrackingProtocol: AnyObject {
    /// Start tracking user interactions
    func startTracking()
    
    /// Stop tracking user interactions
    func stopTracking()
    
    /// Get the current action history
    func getActionHistory() -> [UserAction]
    
    /// Clear action history
    func clearActionHistory()
    
    /// Check if tracking is enabled
    var isTracking: Bool { get }
    
    /// Maximum number of actions to keep in history
    var maxActionHistoryCount: Int { get set }
}

/// Delegate for UI tracking events
public protocol UITrackingDelegate: AnyObject {
    /// Called when a new user action is tracked
    func didTrackUserAction(_ action: UserAction)
    
    /// Called when action history is cleared
    func didClearActionHistory()
}
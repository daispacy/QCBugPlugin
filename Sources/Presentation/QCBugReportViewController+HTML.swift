//
//  QCBugReportViewController+HTML.swift
//  QCBugPlugin
//
//  Created by PayooMerchant on 11/3/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation

extension QCBugReportViewController {
    
    func generateBugReportHTML() -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Bug Report</title>
            <style>
                \(generateCSS())
            </style>
        </head>
        <body>
            <div class="container">
                <div class="section">
                    <h2>📝 Bug Description</h2>
                    <textarea 
                        id="bugDescription" 
                        placeholder="Please describe the bug you encountered..."
                        rows="4"
                        oninput="updateDescription()"
                    ></textarea>
                </div>
                
                <div class="section">
                    <h2>⚠️ Priority</h2>
                    <select id="prioritySelect" onchange="updatePriority()">
                        <option value="low">🟢 Low</option>
                        <option value="medium" selected>🟡 Medium</option>
                        <option value="high">🟠 High</option>
                        <option value="critical">🔴 Critical</option>
                    </select>
                </div>
                
                
                
                <div class="section" id="mediaSection" style="display: none;">
                    <h2>📎 Attachments</h2>
                    <div id="mediaList" class="media-list"></div>
                </div>
                
                <div class="section">
                    <h2>👆 User Actions Timeline</h2>
                    <div id="actionsTimeline" class="actions-timeline">
                        <div class="loading">Loading user actions...</div>
                    </div>
                </div>
                
                <div class="section">
                    <h2>🔧 System Information</h2>
                    <div class="system-info" id="systemInfo">
                        <div class="info-grid">
                            <div class="info-item">
                                <span class="label">Device:</span>
                                <span id="deviceModel">-</span>
                            </div>
                            <div class="info-item">
                                <span class="label">OS:</span>
                                <span id="systemVersion">-</span>
                            </div>
                            <div class="info-item">
                                <span class="label">App Version:</span>
                                <span id="appVersion">-</span>
                            </div>
                            <div class="info-item">
                                <span class="label">Screen Size:</span>
                                <span id="screenSize">-</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            
            <script>
                \(generateJavaScript())
            </script>
        </body>
        </html>
        """
    }
    
    private func generateCSS() -> String {
        return """
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            background-color: #f5f5f7;
            color: #1d1d1f;
            line-height: 1.6;
        }
        
        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .section {
            background: white;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
        }
        
        h2 {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 15px;
            color: #1d1d1f;
        }
        
        textarea, select {
            width: 100%;
            padding: 12px;
            border: 2px solid #e5e5e7;
            border-radius: 8px;
            font-size: 16px;
            font-family: inherit;
            transition: border-color 0.3s ease;
        }
        
        textarea:focus, select:focus {
            outline: none;
            border-color: #007aff;
        }
        
        textarea {
            resize: vertical;
            min-height: 100px;
        }
        
        select {
            height: 44px;
            background: white;
            cursor: pointer;
        }
        
        .checkbox-container {
            display: flex;
            align-items: center;
            cursor: pointer;
            font-size: 16px;
            margin-bottom: 15px;
        }
        
        .checkbox-container input[type="checkbox"] {
            margin-right: 12px;
            width: 18px;
            height: 18px;
            cursor: pointer;
        }
        
        .media-preview {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 12px;
            border: 1px solid #e5e5e7;
        }
        
        .media-item {
            display: flex;
            align-items: center;
            padding: 10px;
            background: white;
            border-radius: 6px;
            border: 1px solid #e5e5e7;
        }
        
        .media-type {
            font-size: 18px;
            margin-right: 10px;
            min-width: 30px;
        }
        
        .media-name {
            flex: 1;
            font-size: 14px;
            color: #1d1d1f;
            font-weight: 500;
            word-break: break-word;
        }
        
        .media-list {
            display: flex;
            flex-direction: column;
            gap: 10px;
        }
        
        .media-list .media-item {
            justify-content: space-between;
        }
        
        .actions-timeline {
            max-height: 300px;
            overflow-y: auto;
            border: 1px solid #e5e5e7;
            border-radius: 8px;
            padding: 10px;
        }
        
        .action-item {
            display: flex;
            align-items: center;
            padding: 8px 12px;
            margin-bottom: 8px;
            background: #f8f9fa;
            border-radius: 6px;
            font-size: 14px;
        }
        
        .action-item:last-child {
            margin-bottom: 0;
        }
        
        .action-icon {
            width: 24px;
            height: 24px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-right: 12px;
            font-size: 12px;
            color: white;
            font-weight: bold;
        }
        
        .action-icon.screen-view { background: #007aff; }
        .action-icon.button-tap { background: #34c759; }
        .action-icon.text-input { background: #ff9500; }
        .action-icon.scroll { background: #af52de; }
        .action-icon.other { background: #8e8e93; }
        
        .action-details {
            flex: 1;
        }
        
        .action-screen {
            font-weight: 600;
            color: #1d1d1f;
        }
        
        .action-description {
            color: #8e8e93;
            font-size: 12px;
            margin-top: 2px;
        }
        
        .action-time {
            font-size: 12px;
            color: #8e8e93;
            white-space: nowrap;
        }
        
        .system-info {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 15px;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 12px;
        }
        
        .info-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .info-item .label {
            font-weight: 500;
            color: #1d1d1f;
        }
        
        .info-item span:last-child {
            color: #8e8e93;
            font-family: 'SF Mono', Consolas, 'Liberation Mono', Menlo, monospace;
            font-size: 14px;
        }
        
        .loading {
            text-align: center;
            color: #8e8e93;
            padding: 20px;
            font-style: italic;
        }
        
        .empty-state {
            text-align: center;
            color: #8e8e93;
            padding: 20px;
        }
        
        .hidden {
            display: none !important;
        }
        
        @media (max-width: 600px) {
            .container {
                padding: 15px;
            }
            
            .section {
                padding: 15px;
            }
            
            .info-grid {
                grid-template-columns: 1fr;
            }
        }
        """
    }
    
    private func generateJavaScript() -> String {
        return """
        let actionHistory = [];
        let capturedMedia = [];
        
        // Initialize on page load
        document.addEventListener('DOMContentLoaded', function() {
            updateSystemInfo();
        });
        
        // Bug report form handlers
        function updateDescription() {
            const description = document.getElementById('bugDescription').value;
            webkit.messageHandlers.bugReportHandler.postMessage({
                action: 'updateDescription',
                description: description
            });
        }
        
        function updatePriority() {
            const priority = document.getElementById('prioritySelect').value;
            webkit.messageHandlers.bugReportHandler.postMessage({
                action: 'updatePriority',
                priority: priority
            });
        }
        
        function updateCategory() {
            const category = document.querySelector('.section:nth-of-type(3) select').value;
            webkit.messageHandlers.bugReportHandler.postMessage({
                action: 'updateCategory',
                category: category
            });
        }
        
        // Action history
        function loadActionHistory(actions) {
            actionHistory = actions;
            renderActionHistory();
        }
        
        function renderActionHistory() {
            const timeline = document.getElementById('actionsTimeline');
            
            if (actionHistory.length === 0) {
                timeline.innerHTML = '<div class="empty-state">No user actions recorded</div>';
                return;
            }
            
            const html = actionHistory.map(action => {
                const timeAgo = getTimeAgo(new Date(action.timestamp));
                const icon = getActionIcon(action.actionType);
                const description = getActionDescription(action);
                
                return `
                    <div class="action-item">
                        <div class="action-icon ${action.actionType}">
                            ${icon}
                        </div>
                        <div class="action-details">
                            <div class="action-screen">${action.screenName}</div>
                            <div class="action-description">${description}</div>
                        </div>
                        <div class="action-time">${timeAgo}</div>
                    </div>
                `;
            }).join('');
            
            timeline.innerHTML = html;
        }
        
        function getActionIcon(actionType) {
            const icons = {
                'screen_view': '👁️',
                'screen_disappear': '👋',
                'button_tap': '👆',
                'text_input': '⌨️',
                'textfield_tap': '📝',
                'scroll': '📜',
                'swipe': '👋',
                'pinch': '🤏',
                'long_press': '👆',
                'segmented_control_tap': '🎛️',
                'switch_toggle': '🔘',
                'slider_change': '🎚️',
                'alert_action': '⚠️',
                'navigation_back': '←',
                'tab_change': '📑',
                'modal_present': '📋',
                'modal_dismiss': '✕'
            };
            
            return icons[actionType] || '❓';
        }
        
        function getActionDescription(action) {
            switch (action.actionType) {
                case 'screen_view':
                    return `Viewed screen`;
                case 'button_tap':
                    return `Tapped ${action.elementInfo?.text || 'button'}`;
                case 'text_input':
                    return `Entered text`;
                case 'textfield_tap':
                    return `Tapped text field`;
                case 'scroll':
                    return `Scrolled content`;
                default:
                    return action.actionType.replace('_', ' ');
            }
        }
        
        function getTimeAgo(date) {
            const now = new Date();
            const diffMs = now - date;
            const diffSecs = Math.floor(diffMs / 1000);
            const diffMins = Math.floor(diffSecs / 60);
            const diffHours = Math.floor(diffMins / 60);
            
            if (diffSecs < 60) return `${diffSecs}s ago`;
            if (diffMins < 60) return `${diffMins}m ago`;
            if (diffHours < 24) return `${diffHours}h ago`;
            return date.toLocaleDateString();
        }
        
        function updateSystemInfo() {
            // These will be populated by native code if needed
            document.getElementById('deviceModel').textContent = navigator.platform || 'Unknown';
            document.getElementById('systemVersion').textContent = navigator.userAgent.includes('iPhone') ? 'iOS' : 'Unknown';
            document.getElementById('appVersion').textContent = '1.0.0';
            document.getElementById('screenSize').textContent = `${screen.width}×${screen.height}`;
        }
        
        function addMediaAttachment(media) {
            capturedMedia.push(media);
            updateMediaList();
        }
        
        function updateMediaList() {
            const mediaList = document.getElementById('mediaList');
            const mediaSection = document.getElementById('mediaSection');
            
            if (capturedMedia.length === 0) {
                mediaSection.style.display = 'none';
                return;
            }
            
            mediaSection.style.display = 'block';
            
            const html = capturedMedia.map((media, index) => {
                const icon = media.type === 'screenRecording' ? '🎥' : 
                            media.type === 'screenshot' ? '📸' : '📎';
                
                return `
                    <div class="media-item">
                        <span class="media-type">${icon}</span>
                        <span class="media-name">${media.fileName}</span>
                    </div>
                `;
            }).join('');
            
            mediaList.innerHTML = html;
        }
        """
    }
}
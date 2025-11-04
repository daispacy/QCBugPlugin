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
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
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
            
            <div id="mediaPreviewOverlay" class="media-preview-overlay" onclick="if (event.target === this) { closeMediaPreview(); }">
                <div class="media-preview-content" onclick="event.stopPropagation();">
                    <button type="button" class="media-preview-close" onclick="closeMediaPreview();">✕</button>
                    <div id="mediaPreviewBody" class="media-preview-body"></div>
                    <div id="mediaPreviewCaption" class="media-preview-caption"></div>
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

        body.media-preview-active {
            overflow: hidden;
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

        function showMediaPreview(index) {
            if (index < 0 || index >= capturedMedia.length) {
                return;
            }

            const media = capturedMedia[index];
            const overlay = document.getElementById('mediaPreviewOverlay');
            const body = document.getElementById('mediaPreviewBody');
            const caption = document.getElementById('mediaPreviewCaption');

            if (!overlay || !body || !caption) {
                return;
            }

            // Clear previous content
            while (body.firstChild) {
                body.removeChild(body.firstChild);
            }
            caption.textContent = '';

            const type = (media.type || '').toLowerCase();
            const isRecording = type === 'screenrecording' || type === 'screen_recording';
            const isScreenshot = type === 'screenshot';
            const isImage = isScreenshot || (media.fileURL && media.fileURL.match(/\\.(jpg|jpeg|png|gif|webp)$/i));
            const displayName = media.fileName || `Attachment ${index + 1}`;

            if (isImage && media.fileURL) {
                const img = document.createElement('img');
                img.className = 'media-preview-image';
                img.src = media.fileURL;
                img.alt = displayName;
                img.onerror = function() {
                    caption.textContent = 'Preview unavailable for this attachment';
                };
                body.appendChild(img);
            } else if (isRecording && media.fileURL) {
                const video = document.createElement('video');
                video.className = 'media-preview-video';
                video.controls = true;
                video.autoplay = true;
                video.playsInline = true;
                const source = document.createElement('source');
                source.src = media.fileURL;
                source.type = 'video/mp4';
                video.appendChild(source);
                body.appendChild(video);
            } else {
                const fallback = document.createElement('div');
                fallback.className = 'media-preview-fallback';
                const text = document.createElement('span');
                text.textContent = 'Preview not available. ';
                const link = document.createElement('a');
                if (media.fileURL) {
                    link.href = media.fileURL;
                } else {
                    link.href = '#';
                    link.addEventListener('click', function(event) {
                        event.preventDefault();
                    });
                }
                link.target = '_blank';
                link.rel = 'noopener';
                link.textContent = 'Open attachment';
                fallback.appendChild(text);
                fallback.appendChild(link);
                body.appendChild(fallback);
            }

            caption.textContent = displayName;
            overlay.classList.add('is-visible');
            if (document.body) {
                document.body.classList.add('media-preview-active');
            }
        }

        function closeMediaPreview() {
            const overlay = document.getElementById('mediaPreviewOverlay');
            const body = document.getElementById('mediaPreviewBody');
            const caption = document.getElementById('mediaPreviewCaption');

            if (!overlay || !overlay.classList.contains('is-visible')) {
                return;
            }

            const video = overlay.querySelector('video');
            if (video) {
                video.pause();
            }

            overlay.classList.remove('is-visible');
            if (document.body) {
                document.body.classList.remove('media-preview-active');
            }

            if (caption) {
                caption.textContent = '';
            }

            if (body) {
                while (body.firstChild) {
                    body.removeChild(body.firstChild);
                }
            }
        }

        document.addEventListener('keydown', function(event) {
            if (event.key === 'Escape') {
                closeMediaPreview();
            }
        });
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
        
        .media-thumbnail-container {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
            gap: 12px;
        }
        
        .media-thumbnail {
            position: relative;
            background: #f8f9fa;
            border: 1px solid #e5e5e7;
            border-radius: 8px;
            overflow: hidden;
            aspect-ratio: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .media-thumbnail:hover {
            border-color: #007aff;
            box-shadow: 0 2px 8px rgba(0, 122, 255, 0.2);
            transform: scale(1.05);
        }
        
        .media-delete-btn {
            position: absolute;
            top: 4px;
            right: 4px;
            background: rgba(255, 59, 48, 0.9);
            color: white;
            border: none;
            border-radius: 50%;
            width: 28px;
            height: 28px;
            padding: 0;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            font-size: 16px;
            opacity: 0.9;
            transform: scale(1);
            transition: all 0.2s ease;
            z-index: 10;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
        }
        
        .media-thumbnail:hover .media-delete-btn {
            opacity: 1;
            transform: scale(1.1);
        }
        
        .media-delete-btn:hover {
            background: rgba(255, 59, 48, 1);
            transform: scale(1.1);
        }
        
        .media-delete-btn:active {
            transform: scale(0.95);
        }
        
        .media-thumbnail img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        
        .media-thumbnail-icon {
            font-size: 32px;
        }
        
        .media-thumbnail-icon--fallback {
            display: none;
        }
        
        .media-thumbnail-icon--fallback.is-visible {
            display: block;
        }

        .media-preview-overlay {
            position: fixed;
            top: 0;
            left: 0;
            width: 100vw;
            height: 100vh;
            background: rgba(0, 0, 0, 0.65);
            display: none;
            align-items: center;
            justify-content: center;
            z-index: 2000;
            padding: 24px;
        }

        .media-preview-overlay.is-visible {
            display: flex;
        }

        .media-preview-content {
            position: relative;
            max-width: min(900px, 90vw);
            max-height: 90vh;
            background: rgba(28, 28, 30, 0.9);
            border-radius: 18px;
            padding: 20px;
            box-shadow: 0 12px 40px rgba(0, 0, 0, 0.35);
            display: flex;
            flex-direction: column;
            align-items: center;
            width: 100%;
        }

        .media-preview-body {
            flex: 1;
            width: 100%;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
        }

        .media-preview-image,
        .media-preview-video {
            max-width: 100%;
            max-height: 70vh;
            border-radius: 12px;
        }

        .media-preview-video {
            background: black;
        }

        .media-preview-close {
            position: absolute;
            top: 14px;
            right: 14px;
            width: 36px;
            height: 36px;
            border-radius: 18px;
            background: rgba(0, 0, 0, 0.6);
            color: #ffffff;
            border: none;
            font-size: 20px;
            line-height: 1;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .media-preview-close:hover {
            background: rgba(255, 255, 255, 0.15);
        }

        .media-preview-close:active {
            transform: scale(0.95);
        }

        .media-preview-caption {
            margin-top: 16px;
            color: #f2f2f7;
            font-size: 14px;
            text-align: center;
            word-break: break-word;
        }

        .media-preview-fallback {
            color: #f2f2f7;
            font-size: 15px;
            text-align: center;
            padding: 16px;
        }

        .media-preview-fallback a {
            color: #0a84ff;
            text-decoration: underline;
        }
        
        .media-thumbnail-label {
            position: absolute;
            bottom: 0;
            left: 0;
            right: 0;
            background: rgba(0, 0, 0, 0.7);
            color: white;
            font-size: 11px;
            padding: 4px 6px;
            text-align: center;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
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
        
        function deleteMediaAttachment(index) {
            if (index < 0 || index >= capturedMedia.length) {
                return;
            }
            const [removed] = capturedMedia.splice(index, 1);
            updateMediaList();

            const overlay = document.getElementById('mediaPreviewOverlay');
            if (overlay && overlay.classList.contains('is-visible')) {
                closeMediaPreview();
            }

            if (removed && removed.fileURL && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.bugReportHandler) {
                window.webkit.messageHandlers.bugReportHandler.postMessage({
                    action: 'deleteMediaAttachment',
                    fileURL: removed.fileURL
                });
            }
        }
        
        function updateMediaList() {
            const mediaList = document.getElementById('mediaList');
            const mediaSection = document.getElementById('mediaSection');
            
            if (capturedMedia.length === 0) {
                mediaSection.style.display = 'none';
                return;
            }
            
            mediaSection.style.display = 'block';
            
            const html = `<div class="media-thumbnail-container">` + 
                capturedMedia.map((media, index) => {
                    const type = (media.type || '').toLowerCase();
                    const isRecording = type === 'screenrecording' || type === 'screen_recording';
                    const isScreenshot = type === 'screenshot';
                    const icon = isRecording ? '🎥' : isScreenshot ? '📸' : '📎';
                    const isImage = isScreenshot || (media.fileURL && media.fileURL.match(/\\.(jpg|jpeg|png|gif|webp)$/i));
                    const rawFileName = media.fileName || `Attachment ${index + 1}`;
                    const fileName = rawFileName
                        .replace(/&/g, '&amp;')
                        .replace(/</g, '&lt;')
                        .replace(/>/g, '&gt;')
                        .replace(/"/g, '&quot;')
                        .replace(/'/g, '&#39;');
                    const deleteButton = `
                        <button type="button" class="media-delete-btn" onclick="event.stopPropagation(); deleteMediaAttachment(${index});">
                            ✕
                        </button>
                    `;
                    const fallbackIcon = `
                        <span class="media-thumbnail-icon media-thumbnail-icon--fallback">${icon}</span>
                    `;
                    
                    if (isImage && media.fileURL.startsWith('file://')) {
                        // Show image thumbnail
                        return `
                            <div class="media-thumbnail" title="${fileName}" onclick="showMediaPreview(${index});">
                                ${deleteButton}
                                <img src="${media.fileURL}" alt="${fileName}" onerror="this.style.display='none'; if (this.nextElementSibling) { this.nextElementSibling.classList.add('is-visible'); }">
                                ${fallbackIcon}
                                <div class="media-thumbnail-label">${fileName}</div>
                            </div>
                        `;
                    } else {
                        // Show icon for video or other media
                        return `
                            <div class="media-thumbnail" title="${fileName}" onclick="showMediaPreview(${index});">
                                ${deleteButton}
                                <span class="media-thumbnail-icon">${icon}</span>
                                <div class="media-thumbnail-label">${fileName}</div>
                            </div>
                        `;
                    }
                }).join('') + 
                `</div>`;
            
            mediaList.innerHTML = html;
        }

        function showMediaPreview(index) {
            if (index < 0 || index >= capturedMedia.length) {
                return;
            }

            const media = capturedMedia[index];
            const overlay = document.getElementById('mediaPreviewOverlay');
            const body = document.getElementById('mediaPreviewBody');
            const caption = document.getElementById('mediaPreviewCaption');

            if (!overlay || !body || !caption) {
                return;
            }

            while (body.firstChild) {
                body.removeChild(body.firstChild);
            }
            caption.textContent = '';

            const type = (media.type || '').toLowerCase();
            const isRecording = type === 'screenrecording' || type === 'screen_recording';
            const isScreenshot = type === 'screenshot';
            const isImage = isScreenshot || (media.fileURL && media.fileURL.match(/\\.(jpg|jpeg|png|gif|webp)$/i));
            const displayName = media.fileName || `Attachment ${index + 1}`;

            if (isImage && media.fileURL) {
                const img = document.createElement('img');
                img.className = 'media-preview-image';
                img.src = media.fileURL;
                img.alt = displayName;
                img.onerror = function() {
                    caption.textContent = 'Preview unavailable for this attachment';
                };
                body.appendChild(img);
            } else if (isRecording && media.fileURL) {
                const video = document.createElement('video');
                video.className = 'media-preview-video';
                video.controls = true;
                video.autoplay = true;
                video.playsInline = true;
                const source = document.createElement('source');
                source.src = media.fileURL;
                source.type = 'video/mp4';
                video.appendChild(source);
                body.appendChild(video);
            } else {
                const fallback = document.createElement('div');
                fallback.className = 'media-preview-fallback';
                const text = document.createElement('span');
                text.textContent = 'Preview not available. ';
                const link = document.createElement('a');
                if (media.fileURL) {
                    link.href = media.fileURL;
                } else {
                    link.href = '#';
                    link.addEventListener('click', function(event) {
                        event.preventDefault();
                    });
                }
                link.target = '_blank';
                link.rel = 'noopener';
                link.textContent = 'Open attachment';
                fallback.appendChild(text);
                fallback.appendChild(link);
                body.appendChild(fallback);
            }

            caption.textContent = displayName;
            overlay.classList.add('is-visible');
            if (document.body) {
                document.body.classList.add('media-preview-active');
            }
        }

        function closeMediaPreview() {
            const overlay = document.getElementById('mediaPreviewOverlay');
            const body = document.getElementById('mediaPreviewBody');
            const caption = document.getElementById('mediaPreviewCaption');

            if (!overlay || !overlay.classList.contains('is-visible')) {
                return;
            }

            const video = overlay.querySelector('video');
            if (video) {
                video.pause();
            }

            overlay.classList.remove('is-visible');
            if (document.body) {
                document.body.classList.remove('media-preview-active');
            }

            if (caption) {
                caption.textContent = '';
            }

            if (body) {
                while (body.firstChild) {
                    body.removeChild(body.firstChild);
                }
            }
        }

        document.addEventListener('keydown', function(event) {
            if (event.key === 'Escape') {
                closeMediaPreview();
            }
        });
        """
    }
}

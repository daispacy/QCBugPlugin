(function () {
    var state = {
        actionHistory: [],
        capturedMedia: [],
        webhookURL: '',
        gitlab: {
            isAuthenticated: false,
            requiresLogin: false,
            isLoading: false,
            userId: null,
            username: null,
            avatarUrl: null,
            error: '',
            available: false
        }
    };

    var HANDLER_NAME = 'bugReportHandler';

    function postMessage(message) {
        if (!window.webkit || !window.webkit.messageHandlers) {
            return false;
        }
        var handler = window.webkit.messageHandlers[HANDLER_NAME];
        if (!handler || typeof handler.postMessage !== 'function') {
            return false;
        }
        handler.postMessage(message);
        return true;
    }

    function escapeHtml(value) {
        if (value === null || value === undefined) {
            return '';
        }
        return String(value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function updateSystemInfo() {
        var deviceLabel = document.getElementById('deviceModel');
        var systemLabel = document.getElementById('systemVersion');
        var appLabel = document.getElementById('appVersion');
        var screenLabel = document.getElementById('screenSize');

        if (deviceLabel) {
            deviceLabel.textContent = navigator.platform || 'Unknown';
        }

        if (systemLabel) {
            systemLabel.textContent = navigator.userAgent || 'Unknown';
        }

        if (appLabel) {
            appLabel.textContent = '1.0.0';
        }

        if (screenLabel) {
            screenLabel.textContent = (window.screen.width || '?') + '×' + (window.screen.height || '?');
        }
    }

    function updateGitLabSection() {
        var section = document.getElementById('gitlabSection');
        var statusLabel = document.getElementById('gitlabStatus');
        var button = document.getElementById('gitlabLoginButton');
        var errorLabel = document.getElementById('gitlabError');
        var profile = document.getElementById('gitlabProfile');
        var avatarWrapper = document.getElementById('gitlabAvatarWrapper');
        var avatarImg = document.getElementById('gitlabAvatar');
        var avatarFallback = document.getElementById('gitlabAvatarFallback');
        var logoutButton = document.getElementById('gitlabLogoutButton');
        var usernameLabel = document.getElementById('gitlabUsername');

        if (!section || !statusLabel || !button || !errorLabel || !profile || !avatarWrapper || !avatarImg || !avatarFallback || !logoutButton || !usernameLabel) {
            return;
        }

        var gitlab = state.gitlab;
        if (!gitlab.available) {
            section.style.display = 'none';
            return;
        }

        section.style.display = 'block';
        var buttonLabel = button.textContent || 'Log in with GitLab';

        avatarWrapper.classList.remove('has-image', 'show-fallback');
        avatarImg.style.display = 'none';
        avatarFallback.textContent = '';
        profile.style.display = 'none';
        logoutButton.style.display = 'none';
        logoutButton.disabled = false;
    usernameLabel.textContent = '';

        if (gitlab.isLoading) {
            statusLabel.textContent = 'Updating GitLab session…';
            button.disabled = true;
            buttonLabel = 'Opening…';
            logoutButton.disabled = true;
            if (gitlab.isAuthenticated && gitlab.username) {
                usernameLabel.textContent = '@' + gitlab.username;
                profile.style.display = 'flex';
            }
        } else if (gitlab.isAuthenticated) {
            var userLabel = gitlab.username ? ('@' + gitlab.username) : (gitlab.userId ? ('#' + gitlab.userId) : 'account');
            statusLabel.textContent = 'Connected to GitLab';
            usernameLabel.textContent = userLabel;
            profile.style.display = 'flex';

            if (gitlab.avatarUrl) {
                avatarImg.src = gitlab.avatarUrl;
                avatarImg.style.display = 'block';
                avatarWrapper.classList.add('has-image');
            } else {
                var fallbackInitial = gitlab.username ? gitlab.username.charAt(0) : (gitlab.userId ? String(gitlab.userId).charAt(0) : '?');
                avatarFallback.textContent = (fallbackInitial || '?').toUpperCase();
                avatarWrapper.classList.add('show-fallback');
            }

            button.disabled = false;
            buttonLabel = 'Refresh GitLab Session';
            logoutButton.style.display = 'inline-flex';
        } else if (gitlab.requiresLogin) {
            statusLabel.textContent = 'Not connected to GitLab';
            button.disabled = false;
            buttonLabel = 'Log in with GitLab';
        } else {
            statusLabel.textContent = 'GitLab integration unavailable';
            button.disabled = true;
            buttonLabel = 'Unavailable';
        }

        button.textContent = buttonLabel;
        logoutButton.disabled = logoutButton.disabled || gitlab.isLoading;
        errorLabel.textContent = gitlab.error ? String(gitlab.error) : '';
        errorLabel.style.display = errorLabel.textContent ? 'block' : 'none';
    }

    window.triggerGitLabLogin = function () {
        if (!postMessage({ action: 'gitlabLogin' })) {
            return;
        }

        state.gitlab.available = true;
        state.gitlab.isLoading = true;
        state.gitlab.error = '';
        state.gitlab.requiresLogin = true;
        updateGitLabSection();
    };

    window.logoutGitLab = function () {
        if (!postMessage({ action: 'gitlabLogout' })) {
            return;
        }

        state.gitlab.isLoading = true;
        state.gitlab.error = '';
        state.gitlab.isAuthenticated = false;
        state.gitlab.requiresLogin = true;
        state.gitlab.avatarUrl = null;
        updateGitLabSection();
    };

    window.qcBugHandleThumbnailError = function (img) {
        if (!img) {
            return;
        }
        img.style.display = 'none';
        var fallback = img.nextElementSibling;
        if (fallback && fallback.classList) {
            fallback.classList.add('is-visible');
        }
    };

    window.updateDescription = function () {
        var field = document.getElementById('bugDescription');
        if (!field) {
            return;
        }
        postMessage({
            action: 'updateDescription',
            description: field.value
        });
    };

    window.updatePriority = function () {
        var field = document.getElementById('prioritySelect');
        if (!field) {
            return;
        }
        postMessage({
            action: 'updatePriority',
            priority: field.value
        });
    };

    window.updateCategory = function () {
        var field = document.getElementById('categorySelect');
        if (!field) {
            return;
        }
        postMessage({
            action: 'updateCategory',
            category: field.value
        });
    };

    window.updateWebhookURL = function () {
        var field = document.getElementById('webhookURL');
        if (!field) {
            return;
        }
        var value = typeof field.value === 'string' ? field.value : '';
        var trimmed = value.trim();
        var previous = state.webhookURL;
        state.webhookURL = trimmed;

        if (previous === trimmed) {
            return;
        }

        postMessage({
            action: 'updateWebhookURL',
            webhookURL: trimmed
        });
    };

    window.onGitLabAuthReady = function (payload) {
        payload = payload || {};
        state.gitlab.isAuthenticated = !!payload.isAuthenticated;
        state.gitlab.requiresLogin = !!payload.requiresLogin;
        state.gitlab.isLoading = !!payload.isLoading;
        state.gitlab.userId = typeof payload.userId === 'number' ? payload.userId : null;
        state.gitlab.username = typeof payload.username === 'string' && payload.username.length ? payload.username : null;
        state.gitlab.avatarUrl = typeof payload.avatarUrl === 'string' && payload.avatarUrl.length ? payload.avatarUrl : null;
        state.gitlab.error = payload.error ? String(payload.error) : '';
        state.gitlab.available = state.gitlab.requiresLogin || state.gitlab.isAuthenticated || !!state.gitlab.error || state.gitlab.isLoading;
        updateGitLabSection();
    };

    window.loadActionHistory = function (actions) {
        state.actionHistory = Array.isArray(actions) ? actions : [];
        renderActionHistory();
    };

    function renderActionHistory() {
        var timeline = document.getElementById('actionsTimeline');
        if (!timeline) {
            return;
        }

        if (!state.actionHistory.length) {
            timeline.innerHTML = '<div class="empty-state">No user actions recorded</div>';
            return;
        }

        var html = state.actionHistory.map(function (action) {
            var timestamp = action && action.timestamp ? new Date(action.timestamp) : new Date();
            var actionType = action && action.actionType ? String(action.actionType) : 'unknown';
            var screenName = action && action.screenName ? escapeHtml(action.screenName) : 'Unknown Screen';
            var description = getActionDescription(action);

            return '' +
                '<div class="action-item">' +
                    '<div class="action-icon ' + actionType + '">' + getActionIcon(actionType) + '</div>' +
                    '<div class="action-details">' +
                        '<div class="action-screen">' + screenName + '</div>' +
                        '<div class="action-description">' + description + '</div>' +
                    '</div>' +
                    '<div class="action-time">' + getTimeAgo(timestamp) + '</div>' +
                '</div>';
        }).join('');

        timeline.innerHTML = html;
    }

    function getActionIcon(actionType) {
        var icons = {
            screen_view: '👁️',
            screen_disappear: '👋',
            button_tap: '👆',
            text_input: '⌨️',
            textfield_tap: '📝',
            scroll: '📜',
            swipe: '👋',
            pinch: '🤏',
            long_press: '👆',
            segmented_control_tap: '🎛️',
            switch_toggle: '🔘',
            slider_change: '🎚️',
            alert_action: '⚠️',
            navigation_back: '←',
            tab_change: '📑',
            modal_present: '📋',
            modal_dismiss: '✕'
        };
        return icons[actionType] || '❓';
    }

    function getActionDescription(action) {
        if (!action) {
            return 'User action';
        }

        var actionType = action.actionType || '';
        var elementText = action.elementInfo && action.elementInfo.text ? escapeHtml(action.elementInfo.text) : '';

        switch (actionType) {
            case 'screen_view':
                return 'Viewed screen';
            case 'button_tap':
                return elementText ? 'Tapped ' + elementText : 'Tapped button';
            case 'text_input':
                return 'Entered text';
            case 'textfield_tap':
                return 'Tapped text field';
            case 'scroll':
                return 'Scrolled content';
            case 'alert_action':
                return 'Interacted with alert';
            default:
                return actionType ? escapeHtml(actionType.replace(/_/g, ' ')) : 'User action';
        }
    }

    function getTimeAgo(date) {
        if (!(date instanceof Date) || isNaN(date.getTime())) {
            return '';
        }

        var now = Date.now();
        var diffMs = now - date.getTime();
        if (diffMs < 0) {
            diffMs = 0;
        }

        var diffSecs = Math.floor(diffMs / 1000);
        var diffMins = Math.floor(diffSecs / 60);
        var diffHours = Math.floor(diffMins / 60);
        var diffDays = Math.floor(diffHours / 24);

        if (diffSecs < 60) {
            return diffSecs + 's ago';
        }
        if (diffMins < 60) {
            return diffMins + 'm ago';
        }
        if (diffHours < 24) {
            return diffHours + 'h ago';
        }
        if (diffDays < 7) {
            return diffDays + 'd ago';
        }
        return date.toLocaleDateString();
    }

    window.addMediaAttachment = function (media) {
        if (!media) {
            return;
        }
        state.capturedMedia.push(media);
        updateMediaList();
    };

    window.deleteMediaAttachment = function (index) {
        if (typeof index !== 'number' || index < 0 || index >= state.capturedMedia.length) {
            return;
        }
        var removed = state.capturedMedia.splice(index, 1);
        updateMediaList();
        window.closeMediaPreview();

        if (removed.length && removed[0] && removed[0].fileURL) {
            postMessage({
                action: 'deleteMediaAttachment',
                fileURL: removed[0].fileURL
            });
        }
    };

    function updateMediaList() {
        var mediaSection = document.getElementById('mediaSection');
        var mediaList = document.getElementById('mediaList');

        if (!mediaSection || !mediaList) {
            return;
        }

        if (!state.capturedMedia.length) {
            mediaSection.style.display = 'none';
            mediaList.innerHTML = '';
            return;
        }

        mediaSection.style.display = 'block';

        var html = state.capturedMedia.map(function (media, index) {
            var type = media && media.type ? String(media.type).toLowerCase() : '';
            var isRecording = type === 'screenrecording' || type === 'screen_recording';
            var isScreenshot = type === 'screenshot';
            var fileURL = media && media.fileURL ? String(media.fileURL) : '';
            var fileNameRaw = media && media.fileName ? media.fileName : 'Attachment ' + (index + 1);
            var fileName = escapeHtml(fileNameRaw);
            var icon = isRecording ? '🎥' : (isScreenshot ? '📸' : '📎');
            var deleteButton = '<button type="button" class="media-delete-btn" onclick="event.stopPropagation(); deleteMediaAttachment(' + index + ');">✕</button>';
            var fallbackIcon = '<span class="media-thumbnail-icon media-thumbnail-icon--fallback">' + icon + '</span>';
            var isImage = isScreenshot || (fileURL && /(\.jpg|\.jpeg|\.png|\.gif|\.webp)$/i.test(fileURL));

            if (isImage && fileURL.indexOf('file://') === 0) {
                return '' +
                    '<div class="media-thumbnail" title="' + fileName + '" onclick="showMediaPreview(' + index + ');">' +
                        deleteButton +
                        '<img src="' + fileURL + '" alt="' + fileName + '" onerror="qcBugHandleThumbnailError(this)">' +
                        fallbackIcon +
                        '<div class="media-thumbnail-label">' + fileName + '</div>' +
                    '</div>';
            }

            return '' +
                '<div class="media-thumbnail" title="' + fileName + '" onclick="showMediaPreview(' + index + ');">' +
                    deleteButton +
                    '<span class="media-thumbnail-icon">' + icon + '</span>' +
                    '<div class="media-thumbnail-label">' + fileName + '</div>' +
                '</div>';
        }).join('');

        mediaList.innerHTML = '<div class="media-thumbnail-container">' + html + '</div>';
    }

    window.showMediaPreview = function (index) {
        if (typeof index !== 'number' || index < 0 || index >= state.capturedMedia.length) {
            return;
        }

        var media = state.capturedMedia[index];
        var overlay = document.getElementById('mediaPreviewOverlay');
        var body = document.getElementById('mediaPreviewBody');
        var caption = document.getElementById('mediaPreviewCaption');

        if (!overlay || !body || !caption) {
            return;
        }

        while (body.firstChild) {
            body.removeChild(body.firstChild);
        }
        caption.textContent = '';

        var type = media && media.type ? String(media.type).toLowerCase() : '';
        var fileURL = media && media.fileURL ? String(media.fileURL) : '';
        var displayName = media && media.fileName ? media.fileName : 'Attachment ' + (index + 1);
        var isRecording = type === 'screenrecording' || type === 'screen_recording';
        var isScreenshot = type === 'screenshot';
        var isImage = isScreenshot || (fileURL && /(\.jpg|\.jpeg|\.png|\.gif|\.webp)$/i.test(fileURL));

        if (isImage && fileURL) {
            var img = document.createElement('img');
            img.className = 'media-preview-image';
            img.src = fileURL;
            img.alt = displayName;
            img.onerror = function () {
                handlePreviewFailure(index);
            };
            body.appendChild(img);
        } else if (isRecording && fileURL) {
            var video = document.createElement('video');
            video.className = 'media-preview-video';
            video.controls = true;
            video.autoplay = true;
            video.playsInline = true;
            video.onerror = function () {
                handlePreviewFailure(index);
            };
            var source = document.createElement('source');
            source.src = fileURL;
            source.type = 'video/mp4';
            video.appendChild(source);
            body.appendChild(video);
        } else {
            handlePreviewFailure(index);
            return;
        }

        caption.textContent = displayName;
        overlay.classList.add('is-visible');
        if (document.body) {
            document.body.classList.add('media-preview-active');
        }
    };

    window.closeMediaPreview = function () {
        var overlay = document.getElementById('mediaPreviewOverlay');
        var body = document.getElementById('mediaPreviewBody');
        var caption = document.getElementById('mediaPreviewCaption');

        if (!overlay || !overlay.classList.contains('is-visible')) {
            return;
        }

        var video = overlay.querySelector('video');
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
    };

    function handlePreviewFailure(index) {
        window.closeMediaPreview();
        requestNativePreviewByIndex(index);
    }

    function requestNativePreviewByIndex(index) {
        if (typeof index !== 'number' || index < 0 || index >= state.capturedMedia.length) {
            return;
        }
        requestNativePreview(state.capturedMedia[index]);
    }

    function requestNativePreview(media) {
        if (!media || !media.fileURL) {
            return;
        }

        var didPost = postMessage({
            action: 'previewAttachment',
            fileURL: media.fileURL,
            type: media.type || '',
            fileName: media.fileName || ''
        });

        if (!didPost) {
            window.open(media.fileURL, '_blank');
        }
    }

    document.addEventListener('DOMContentLoaded', function () {
        updateSystemInfo();
        updateGitLabSection();
    });

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape') {
            window.closeMediaPreview();
        }
    });
})();

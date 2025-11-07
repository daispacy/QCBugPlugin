(function () {
    var state = {
        actionHistory: [],
        capturedMedia: [],
        webhookURL: '',
        assign: {
            options: [],
            isLoading: false,
            error: '',
            selected: null,
            lastFetchKey: null,
            requestId: 0
        },
        priority: {
            options: [],
            isLoading: false,
            error: '',
            selected: null,
            lastFetchKey: null,
            requestId: 0
        },
        issueNumber: '',
        gitlab: {
            isAuthenticated: false,
            requiresLogin: false,
            isLoading: false,
            username: null,
            project: null,
            pat: null,
            error: '',
            available: false
        }
    };

    var HANDLER_NAME = 'bugReportHandler';
    var assignFetchTimeout = null;
    var priorityFetchTimeout = null;

    function getWebhookInputValue() {
        var field = document.getElementById('webhookURL');
        if (!field || typeof field.value !== 'string') {
            return '';
        }
        return field.value.trim();
    }

    function notifyNativeLog(message) {
        if (!message) {
            return;
        }
        postMessage({
            action: 'logMessage',
            message: String(message)
        });
    }

    function deriveMembersEndpoint(url) {
        if (!url || typeof url !== 'string') {
            return null;
        }
        var trimmed = url.trim();
        if (!trimmed) {
            return null;
        }
        if (!/^https?:\/\//i.test(trimmed)) {
            return null;
        }
        return trimmed;
    }

    function resetAssignState(shouldNotify) {
        if (assignFetchTimeout) {
            clearTimeout(assignFetchTimeout);
            assignFetchTimeout = null;
        }
        var previousSelection = state.assign.selected;
        state.assign.options = [];
        state.assign.isLoading = false;
        state.assign.error = '';
        state.assign.lastFetchKey = null;
        state.assign.requestId = 0;
        state.assign.selected = shouldNotify ? null : state.assign.selected;
        renderAssignControls();
        if (shouldNotify && previousSelection) {
            postMessage({ action: 'updateAssignee', username: null });
        }
    }

    function renderAssignControls() {
        var select = document.getElementById('assigneeSelect');
        var status = document.getElementById('assignStatus');
        if (!select || !status) {
            return;
        }

        var options = Array.isArray(state.assign.options) ? state.assign.options.slice() : [];
        var selected = state.assign.selected;
        var endpoint = deriveMembersEndpoint(state.webhookURL);
        var hasEndpoint = !!endpoint;
        var projectValue = typeof state.gitlab.project === 'string' ? state.gitlab.project.trim() : '';
        var hasProject = projectValue.length > 0;
        if (selected && options.indexOf(selected) === -1) {
            options.unshift(selected);
        }

        var needsRebuild = select.options.length !== options.length + 1;
        if (!needsRebuild) {
            for (var i = 1; i < select.options.length; i += 1) {
                if (select.options[i].value !== options[i - 1]) {
                    needsRebuild = true;
                    break;
                }
            }
        }

        if (needsRebuild) {
            while (select.firstChild) {
                select.removeChild(select.firstChild);
            }

            var defaultOption = document.createElement('option');
            defaultOption.value = '';
            defaultOption.textContent = 'Unassigned';
            select.appendChild(defaultOption);

            options.forEach(function (username) {
                var option = document.createElement('option');
                option.value = username;
                option.textContent = username;
                select.appendChild(option);
            });
        }

        var desiredValue = selected && options.indexOf(selected) !== -1 ? selected : '';
        select.value = desiredValue;
        select.disabled = !!state.assign.isLoading || !hasEndpoint || !hasProject;

        status.textContent = '';
        status.className = 'assign-status';
        if (state.assign.isLoading) {
            status.textContent = 'Loading assignees…';
            status.classList.add('assign-status--loading');
        } else if (state.assign.error) {
            status.textContent = state.assign.error;
            status.classList.add('assign-status--error');
        } else if (state.assign.lastFetchKey && options.length === 0) {
            status.textContent = 'No team members found for this webhook.';
        } else if (!hasEndpoint) {
            status.textContent = 'Enter a webhook URL to load assignees.';
        } else if (!hasProject) {
            status.textContent = 'Set a GitLab project to load assignees.';
        }
    }

    function scheduleAssigneeFetch(force) {
        if (assignFetchTimeout) {
            clearTimeout(assignFetchTimeout);
        }

        var currentWebhook = getWebhookInputValue();
        state.webhookURL = currentWebhook;

        var endpoint = deriveMembersEndpoint(currentWebhook);
        if (!endpoint) {
            return;
        }

        var projectValue = typeof state.gitlab.project === 'string' ? state.gitlab.project.trim() : '';
        if (!projectValue.length) {
            return;
        }

        assignFetchTimeout = setTimeout(function () {
            fetchAssignees(force);
            assignFetchTimeout = null;
        }, 400);
    }

    function fetchAssignees(force) {
        var currentWebhook = getWebhookInputValue();
        state.webhookURL = currentWebhook;

        var endpoint = deriveMembersEndpoint(currentWebhook);
        if (!endpoint) {
            return;
        }

        var projectValue = typeof state.gitlab.project === 'string' ? state.gitlab.project.trim() : '';
        if (!projectValue.length) {
            return;
        }

        var cacheKey = endpoint + '::' + projectValue;

        if (!force && state.assign.lastFetchKey === cacheKey && state.assign.options.length && !state.assign.error) {
            return;
        }

        var requestId = state.assign.requestId + 1;
        state.assign.requestId = requestId;
        state.assign.isLoading = true;
        state.assign.error = '';
        renderAssignControls();

        var payload = {
            team: 'ios',
            whtype: 'get_members',
            project: projectValue
        };

        notifyNativeLog('Fetching GitLab members (endpoint=' + endpoint + ', project=' + projectValue + ')');

        fetch(endpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        })
            .then(function (response) {
                if (state.assign.requestId !== requestId) {
                    return null;
                }
                return response.json().catch(function () {
                    return null;
                });
            })
            .then(function (json) {
                if (state.assign.requestId !== requestId) {
                    return;
                }

                state.assign.isLoading = false;

                if (json && json.code === 200 && Array.isArray(json.data)) {
                    var usernames = [];
                    json.data.forEach(function (member) {
                        var username = member && typeof member.username === 'string' ? member.username.trim() : '';
                        if (username && usernames.indexOf(username) === -1) {
                            usernames.push(username);
                        }
                    });
                    var previousSelection = state.assign.selected;
                    state.assign.options = usernames;
                    state.assign.error = '';
                    state.assign.lastFetchKey = cacheKey;
                    if (previousSelection && usernames.indexOf(previousSelection) === -1) {
                        state.assign.selected = null;
                        postMessage({ action: 'updateAssignee', username: null });
                    }
                    notifyNativeLog('Loaded GitLab members: count=' + usernames.length);
                } else {
                    var message = (json && typeof json.message === 'string' && json.message.trim()) ? json.message.trim() : 'Unable to load team members.';
                    state.assign.options = [];
                    state.assign.error = message;
                    state.assign.lastFetchKey = null;
                    notifyNativeLog('GitLab member fetch failed: ' + message);
                }

                renderAssignControls();
            })
            .catch(function () {
                if (state.assign.requestId !== requestId) {
                    return;
                }
                state.assign.isLoading = false;
                state.assign.options = [];
                state.assign.error = 'Unable to load team members.';
                state.assign.lastFetchKey = null;
                renderAssignControls();
                notifyNativeLog('GitLab member fetch encountered a network error.');
            });
    }

    function resetPriorityState(shouldNotify) {
        if (priorityFetchTimeout) {
            clearTimeout(priorityFetchTimeout);
            priorityFetchTimeout = null;
        }
        var previousSelection = state.priority.selected;
        state.priority.options = [];
        state.priority.isLoading = false;
        state.priority.error = '';
        state.priority.lastFetchKey = null;
        state.priority.requestId = 0;
        state.priority.selected = shouldNotify ? null : state.priority.selected;
        renderPriorityControls();
        if (shouldNotify && previousSelection) {
            postMessage({ action: 'updatePriority', priority: null });
        }
    }

    function renderPriorityControls() {
        var select = document.getElementById('prioritySelect');
        var status = document.getElementById('priorityStatus');
        if (!select || !status) {
            return;
        }

        var options = Array.isArray(state.priority.options) ? state.priority.options.slice() : [];
        var endpoint = deriveMembersEndpoint(state.webhookURL);
        var hasEndpoint = !!endpoint;
        var projectValue = typeof state.gitlab.project === 'string' ? state.gitlab.project.trim() : '';
        var hasProject = projectValue.length > 0;

        while (select.firstChild) {
            select.removeChild(select.firstChild);
        }

        var placeholder = document.createElement('option');
        placeholder.value = '';
        placeholder.textContent = 'Select priority';
        select.appendChild(placeholder);

        options.forEach(function (option) {
            var opt = document.createElement('option');
            opt.value = option.value;
            opt.textContent = option.title;
            select.appendChild(opt);
        });

        var selectedValue = '';
        if (state.priority.selected && options.some(function (option) { return option.value === state.priority.selected; })) {
            selectedValue = state.priority.selected;
        }
        select.value = selectedValue;
        select.disabled = !!state.priority.isLoading || !hasEndpoint || !hasProject;

        status.textContent = '';
        status.className = 'assign-status';
        if (state.priority.isLoading) {
            status.textContent = 'Loading priorities…';
            status.classList.add('assign-status--loading');
        } else if (state.priority.error) {
            status.textContent = state.priority.error;
            status.classList.add('assign-status--error');
        } else if (state.priority.lastFetchKey && options.length === 0) {
            status.textContent = 'No priority labels found.';
        } else if (!hasEndpoint) {
            status.textContent = 'Enter a webhook URL to load priorities.';
        } else if (!hasProject) {
            status.textContent = 'Set a GitLab project to load priorities.';
        }
    }

    function schedulePriorityFetch(force) {
        if (priorityFetchTimeout) {
            clearTimeout(priorityFetchTimeout);
        }

        var endpoint = deriveMembersEndpoint(state.webhookURL);
        if (!endpoint) {
            return;
        }

        var projectValue = typeof state.gitlab.project === 'string' ? state.gitlab.project.trim() : '';
        if (!projectValue.length) {
            return;
        }

        priorityFetchTimeout = setTimeout(function () {
            fetchPriorities(force);
            priorityFetchTimeout = null;
        }, 400);
    }

    function fetchPriorities(force) {
        var currentWebhook = getWebhookInputValue();
        state.webhookURL = currentWebhook;

        var endpoint = deriveMembersEndpoint(currentWebhook);
        if (!endpoint) {
            return;
        }

        var projectValue = typeof state.gitlab.project === 'string' ? state.gitlab.project.trim() : '';
        if (!projectValue.length) {
            return;
        }

        var cacheKey = endpoint + '::labels::' + projectValue;

        if (!force && state.priority.lastFetchKey === cacheKey && state.priority.options.length && !state.priority.error) {
            return;
        }

        var requestId = state.priority.requestId + 1;
        state.priority.requestId = requestId;
        state.priority.isLoading = true;
        state.priority.error = '';
        renderPriorityControls();

        var payload = {
            whtype: 'get_labels',
            project: projectValue
        };

        // Add metadata with GitLab JWT if available
        if (state.gitlab.pat) {
            payload.metadata = {
                gitlab: {
                    pat: state.gitlab.pat
                }
            };
        }

        notifyNativeLog('Fetching GitLab priorities (endpoint=' + endpoint + ', project=' + projectValue + ')');

        fetch(endpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        })
            .then(function (response) {
                if (state.priority.requestId !== requestId) {
                    return null;
                }
                return response.json().catch(function () {
                    return null;
                });
            })
            .then(function (json) {
                if (state.priority.requestId !== requestId) {
                    return;
                }

                state.priority.isLoading = false;

                if (json && json.code === 200 && Array.isArray(json.data)) {
                    var prefix = 'priority::';
                    var labels = [];
                    json.data.forEach(function (item) {
                        var title = item && typeof item.title === 'string' ? item.title.trim() : '';
                        if (!title.length) {
                            return;
                        }
                        var normalized = title.toLowerCase();
                        if (normalized.indexOf(prefix) !== 0) {
                            return;
                        }
                        var rawValue = title.substring(prefix.length).trim().toLowerCase();
                        if (!rawValue.length) {
                            return;
                        }
                        if (labels.some(function (label) { return label.value === rawValue; })) {
                            return;
                        }
                        labels.push({ title: title, value: rawValue });
                    });

                    var previousSelection = state.priority.selected;
                    state.priority.options = labels;
                    state.priority.error = '';
                    state.priority.lastFetchKey = cacheKey;
                    if (previousSelection && !labels.some(function (label) { return label.value === previousSelection; })) {
                        state.priority.selected = null;
                        postMessage({ action: 'updatePriority', priority: null });
                    }
                    notifyNativeLog('Loaded GitLab priorities: count=' + labels.length);
                } else {
                    var message = (json && typeof json.message === 'string' && json.message.trim()) ? json.message.trim() : 'Unable to load priorities.';
                    state.priority.options = [];
                    state.priority.error = message;
                    state.priority.lastFetchKey = null;
                    notifyNativeLog('GitLab priority fetch failed: ' + message);
                }

                renderPriorityControls();
            })
            .catch(function () {
                if (state.priority.requestId !== requestId) {
                    return;
                }
                state.priority.isLoading = false;
                state.priority.options = [];
                state.priority.error = 'Unable to load priorities.';
                state.priority.lastFetchKey = null;
                renderPriorityControls();
                notifyNativeLog('GitLab priority fetch encountered a network error.');
            });
    }

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
        var loginButton = document.getElementById('gitlabLoginButton');
        var logoutButton = document.getElementById('gitlabLogoutButton');
        var authState = document.getElementById('gitlabAuthState');
        var usernameLabel = document.getElementById('gitlabUsernameLabel');
        var errorLabel = document.getElementById('gitlabError');

        if (!section || !loginButton || !logoutButton || !authState || !usernameLabel || !errorLabel) {
            return;
        }

        var gitlab = state.gitlab;
        if (!gitlab.available) {
            section.style.display = 'none';
            return;
        }

        section.style.display = 'block';
        loginButton.style.display = 'inline-flex';
        loginButton.disabled = false;
        loginButton.textContent = 'Log in with GitLab';

        authState.style.display = 'none';
        logoutButton.disabled = false;

        if (gitlab.isLoading) {
            if (gitlab.isAuthenticated && gitlab.username) {
                usernameLabel.textContent = '@' + gitlab.username;
                authState.style.display = 'flex';
                logoutButton.disabled = true;
                loginButton.style.display = 'none';
            } else {
                loginButton.disabled = true;
                loginButton.textContent = 'Opening…';
            }
        } else if (gitlab.isAuthenticated) {
            var label = gitlab.username ? ('@' + gitlab.username) : 'GitLab account';
            usernameLabel.textContent = label;
            authState.style.display = 'flex';
            loginButton.style.display = 'none';
        } else if (gitlab.requiresLogin) {
            loginButton.style.display = 'inline-flex';
        } else {
            section.style.display = 'none';
            return;
        }

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
        state.gitlab.username = null;
        state.gitlab.available = true;
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
        var value = typeof field.value === 'string' ? field.value.trim().toLowerCase() : '';
        var priority = value.length ? value : null;
        state.priority.selected = priority;
        renderPriorityControls();
        postMessage({
            action: 'updatePriority',
            priority: priority
        });
    };

    window.setInitialPriority = function (value) {
        var priority = null;
        if (typeof value === 'string') {
            var trimmed = value.trim().toLowerCase();
            if (trimmed.length) {
                priority = trimmed;
            }
        }
        state.priority.selected = priority;
        renderPriorityControls();
    };

    window.updateWebhookURL = function () {
        var trimmed = getWebhookInputValue();
        var previous = state.webhookURL;
        state.webhookURL = trimmed;
        renderAssignControls();
        renderPriorityControls();

        if (previous !== trimmed) {
            if (!trimmed) {
                resetAssignState(true);
                resetPriorityState(true);
            } else {
                scheduleAssigneeFetch(true);
                schedulePriorityFetch(true);
            }
        }

        if (previous === trimmed) {
            return;
        }

        postMessage({
            action: 'updateWebhookURL',
            webhookURL: trimmed
        });
    };

    window.updateAssignee = function () {
        var select = document.getElementById('assigneeSelect');
        if (!select) {
            return;
        }
        var value = typeof select.value === 'string' ? select.value.trim() : '';
        var username = value ? value : null;
        state.assign.selected = username;
        renderAssignControls();
        postMessage({
            action: 'updateAssignee',
            username: username
        });
    };

    window.setInitialAssignee = function (username) {
        var value = typeof username === 'string' ? username.trim() : '';
        state.assign.selected = value ? value : null;
        renderAssignControls();
    };

    window.updateIssueNumber = function () {
        var field = document.getElementById('issueNumberInput');
        if (!field) {
            return;
        }
        var value = typeof field.value === 'string' ? field.value : '';
        var sanitized = value.replace(/[^0-9]/g, '');
        if (sanitized !== value) {
            field.value = sanitized;
        }
        state.issueNumber = sanitized;
        postMessage({
            action: 'updateIssueNumber',
            issueNumber: sanitized.length ? parseInt(sanitized, 10) : null
        });
    };

    window.setInitialIssueNumber = function (value) {
        var numericString = '';
        if (typeof value === 'number' && isFinite(value)) {
            numericString = Math.max(0, Math.floor(value)).toString();
        } else if (typeof value === 'string') {
            numericString = value.replace(/[^0-9]/g, '');
        }
        state.issueNumber = numericString;
        var field = document.getElementById('issueNumberInput');
        if (field) {
            field.value = numericString;
        }
    };

    window.onGitLabAuthReady = function (payload) {
        payload = payload || {};
        state.gitlab.isAuthenticated = !!payload.isAuthenticated;
        state.gitlab.requiresLogin = !!payload.requiresLogin;
        state.gitlab.isLoading = !!payload.isLoading;
        state.gitlab.username = typeof payload.username === 'string' && payload.username.length ? payload.username : null;
        state.gitlab.pat = typeof payload.pat === 'string' && payload.pat.length ? payload.pat : null;
        var previousProject = state.gitlab.project;
        var projectValue = typeof payload.project === 'string' ? payload.project.trim() : '';
        state.gitlab.project = projectValue.length ? projectValue : null;
        state.gitlab.error = payload.error ? String(payload.error) : '';
        state.gitlab.available = state.gitlab.requiresLogin || state.gitlab.isAuthenticated || !!state.gitlab.error || state.gitlab.isLoading;
        updateGitLabSection();

        if (state.gitlab.project !== previousProject) {
            if (state.gitlab.project) {
                scheduleAssigneeFetch(true);
                schedulePriorityFetch(true);
            } else {
                resetAssignState(true);
                resetPriorityState(true);
            }
        }

        renderAssignControls();
        renderPriorityControls();
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

    window.updateGitLabMembers = function (members) {
        if (!Array.isArray(members)) {
            notifyNativeLog('updateGitLabMembers called with invalid data');
            return;
        }

        var usernames = [];
        members.forEach(function (member) {
            var username = member && typeof member.username === 'string' ? member.username.trim() : '';
            if (username && usernames.indexOf(username) === -1) {
                usernames.push(username);
            }
        });

        state.assign.options = usernames;
        state.assign.error = '';
        state.assign.isLoading = false;

        // Update cache key to prevent re-fetching
        var endpoint = deriveMembersEndpoint(state.webhookURL);
        var projectValue = typeof state.gitlab.project === 'string' ? state.gitlab.project.trim() : '';
        if (endpoint && projectValue) {
            state.assign.lastFetchKey = endpoint + '::' + projectValue;
        }

        renderAssignControls();
        notifyNativeLog('Updated GitLab members from native: count=' + usernames.length);
    };

    window.refetchPriorities = function () {
        if (state.gitlab.project) {
            schedulePriorityFetch(true);
            notifyNativeLog('Triggering priority refetch');
        }
    };

    document.addEventListener('DOMContentLoaded', function () {
        updateSystemInfo();
        updateGitLabSection();
        renderAssignControls();
        renderPriorityControls();
    });

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape') {
            window.closeMediaPreview();
        }
    });
})();

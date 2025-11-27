//
//  GitLabAuthService.swift
//  QCBugPlugin
//
//  Created by GitHub Copilot on 11/5/25.
//

import Foundation
import AuthenticationServices
import UIKit

/// Concrete implementation responsible for acquiring GitLab JWTs via OAuth callback.
/// The server handles OAuth token exchange and returns JWT + username in the callback URL.
final class GitLabAuthService: GitLabAuthProviding {

    private struct CachedJWT {
        let header: String
        let jwt: String
        let expiration: Date
        let username: String?
    }

    private let configuration: GitLabAppConfig
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let sessionStore: GitLabSessionStore
    private let stateQueue = DispatchQueue(label: "com.qcbugplugin.gitlab-auth", attributes: .concurrent)

    private var cachedJWT: CachedJWT?
    private var authSession: ASWebAuthenticationSession?
    private var presentationContextProvider: AnyObject?

    convenience init(
        configuration: GitLabAppConfig,
        session: URLSession = .shared
    ) {
        self.init(configuration: configuration, session: session, sessionStore: GitLabSessionStore.shared)
    }

    init(
        configuration: GitLabAppConfig,
        session: URLSession,
        sessionStore: GitLabSessionStore
    ) {
        self.configuration = configuration
        self.session = session
        self.jsonDecoder = JSONDecoder()
        self.sessionStore = sessionStore
        restorePersistedState()
    }

    // MARK: - GitLabAuthProviding

    func fetchAuthorization(completion: @escaping (Result<GitLabAuthorization, GitLabAuthError>) -> Void) {
        if let cachedJWT = currentCachedJWT(), cachedJWT.expiration > Date() {
            let authorization = GitLabAuthorization(
                authorizationHeader: cachedJWT.header,
                jwt: cachedJWT.jwt,
                username: cachedJWT.username,
                project: configuration.project
            )
            DispatchQueue.main.async {
                completion(.success(authorization))
            }
            return
        }

        DispatchQueue.main.async {
            completion(.failure(.userAuthenticationRequired))
        }
    }

    func clearCache() {
        stateQueue.async(flags: .barrier) {
            self.cachedJWT = nil
            self.authSession = nil
            if #available(iOS 13.0, *) {
                self.presentationContextProvider = nil
            }
        }
        sessionStore.clearAll()
    }

    func hasValidAuthorization() -> Bool {
        if let jwt = currentCachedJWT(), jwt.expiration > Date() {
            return true
        }
        return false
    }

    // MARK: - Internal Workflow

    func authenticateInteractively(from presenter: UIViewController, completion: @escaping (Result<GitLabAuthorization, GitLabAuthError>) -> Void) {
        if hasValidAuthorization() {
            fetchAuthorization(completion: completion)
            return
        }

        guard let redirectURI = configuration.redirectURI,
              let callbackScheme = redirectURI.scheme else {
            DispatchQueue.main.async {
                completion(.failure(.invalidConfiguration))
            }
            return
        }

        guard #available(iOS 12.0, *) else {
            DispatchQueue.main.async {
                completion(.failure(.invalidConfiguration))
            }
            return
        }

        let state = configuration.scheme
        guard let authorizationURL = authorizationURL(state: state, redirectURI: redirectURI) else {
            DispatchQueue.main.async {
                completion(.failure(.invalidConfiguration))
            }
            return
        }

        DispatchQueue.main.async {
            // Use modern callback-based API for iOS 17.4+, fall back to deprecated API for older versions
            let session: ASWebAuthenticationSession
            if #available(iOS 17.4, *) {
                session = ASWebAuthenticationSession(
                    url: authorizationURL,
                    callback: .customScheme(callbackScheme)
                ) { [weak self] callbackURL, error in
                    self?.handleAuthenticationCallback(callbackURL: callbackURL, error: error, redirectURI: redirectURI, completion: completion)
                }
            } else {
                session = ASWebAuthenticationSession(
                    url: authorizationURL,
                    callbackURLScheme: callbackScheme
                ) { [weak self] callbackURL, error in
                    self?.handleAuthenticationCallback(callbackURL: callbackURL, error: error, redirectURI: redirectURI, completion: completion)
                }
            }

            if #available(iOS 13.0, *) {
                let provider = WebAuthContextProvider()
                provider.anchor = self.presentationAnchor(for: presenter)
                session.presentationContextProvider = provider
                session.prefersEphemeralWebBrowserSession = true
                self.presentationContextProvider = provider
            }

            if !session.start() {
                self.authSession = nil
                if #available(iOS 13.0, *) {
                    self.presentationContextProvider = nil
                }
                DispatchQueue.main.async {
                    completion(.failure(.invalidConfiguration))
                }
                return
            }

            self.authSession = session
        }
    }

    private func handleAuthenticationCallback(
        callbackURL: URL?,
        error: Error?,
        redirectURI: URL,
        completion: @escaping (Result<GitLabAuthorization, GitLabAuthError>) -> Void
    ) {
        self.authSession = nil
        if #available(iOS 13.0, *) {
            self.presentationContextProvider = nil
        }

        if let error = error {
            if let sessionError = error as? ASWebAuthenticationSessionError,
               sessionError.code == .canceledLogin {
                DispatchQueue.main.async {
                    completion(.failure(.authenticationCancelled))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
            }
            return
        }

        guard let callbackURL = callbackURL else {
            DispatchQueue.main.async {
                completion(.failure(.invalidResponse))
            }
            return
        }

        self.processAuthenticationCallback(callbackURL, redirectURI: redirectURI) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private func authorizationURL(state: String, redirectURI: URL) -> URL? {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var path = components.path
        if path.hasSuffix("/") {
            path.removeLast()
        }
        components.path = path.isEmpty ? "/oauth/authorize" : path + "/oauth/authorize"

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.appId),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state)
        ]

        if let audience = configuration.audience {
            queryItems.append(URLQueryItem(name: "audience", value: audience))
        }

        components.queryItems = queryItems
        return components.url
    }

    private func presentationAnchor(for presenter: UIViewController) -> UIWindow? {
        if let window = presenter.view.window {
            return window
        }
        if let window = presenter.navigationController?.view.window {
            return window
        }
        if let window = presenter.viewIfLoaded?.window {
            return window
        }

        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIApplication.shared.windows.first
        }
    }

    private func processAuthenticationCallback(
        _ callbackURL: URL,
        redirectURI: URL,
        completion: @escaping (Result<GitLabAuthorization, GitLabAuthError>) -> Void
    ) {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            completion(.failure(.invalidResponse))
            return
        }

        let jwt = queryItems.first { $0.name == "jwt" }?.value
        let username = queryItems.first { $0.name == "username" }?.value

        guard let jwtToken = jwt, !jwtToken.isEmpty else {
            print("❌ GitLabAuthService: Invalid callback - missing JWT token")
            completion(.failure(.invalidResponse))
            return
        }

        guard let user = username, !user.isEmpty else {
            print("❌ GitLabAuthService: Invalid callback - missing username")
            completion(.failure(.invalidResponse))
            return
        }

        print("✅ GitLabAuthService: Authorization callback received")
        print("   Username: \(user)")
        print("   JWT: \(jwtToken.prefix(50))...")

        // Calculate expiration from JWT or use default (31 days)
        let expiration = Date().addingTimeInterval(configuration.jwtExpiration)

        let cachedJWT = CachedJWT(
            header: "Bearer \(jwtToken)",
            jwt: jwtToken,
            expiration: expiration,
            username: user
        )

        storeCachedJWT(cachedJWT)

        let authorization = GitLabAuthorization(
            authorizationHeader: cachedJWT.header,
            jwt: cachedJWT.jwt,
            username: cachedJWT.username,
            project: configuration.project
        )

        completion(.success(authorization))
    }


    private func decodeErrorMessage(from data: Data?) -> String? {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json["error_description"] as? String ??
            json["error"] as? String ??
            json["message"] as? String
    }



    // MARK: - Helpers

    private func currentCachedJWT() -> CachedJWT? {
        stateQueue.sync { cachedJWT }
    }

    private func storeCachedJWT(_ jwt: CachedJWT) {
        stateQueue.sync(flags: .barrier) {
            self.cachedJWT = jwt
        }
        sessionStore.saveJWT(jwt: jwt.jwt, header: jwt.header, expiration: jwt.expiration, username: jwt.username)
    }

    // MARK: - Members Fetching

    /// TODO: This method needs to be updated to work with the new architecture.
    /// Since iOS no longer has a GitLab access token (only the JWT from the server),
    /// this should either:
    /// 1. Call a backend endpoint that proxies to GitLab API, OR
    /// 2. Have the server return the access_token in the callback URL
    func fetchProjectMembers(project: String, completion: @escaping (Result<[GitLabMember], GitLabAuthError>) -> Void) {
        print("⚠️ GitLabAuthService: fetchProjectMembers is not implemented with new OAuth flow")
        print("   This method requires a GitLab access token, which is no longer available on iOS")
        print("   Consider implementing a backend endpoint to fetch members")
        completion(.failure(.notAuthenticated))
    }

    private func restorePersistedState() {
        if let storedJWT = sessionStore.loadJWT() {
            let expiration = storedJWT.expiration ?? Date.distantFuture
            let jwt = CachedJWT(
                header: storedJWT.header,
                jwt: storedJWT.jwt,
                expiration: expiration,
                username: storedJWT.username
            )
            stateQueue.sync(flags: .barrier) {
                self.cachedJWT = jwt
            }
        }
    }
}

@available(iOS 13.0, *)
private final class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    weak var anchor: ASPresentationAnchor?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor ?? ASPresentationAnchor()
    }
}

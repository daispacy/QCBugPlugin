//
//  GitLabAuthService.swift
//  QCBugPlugin
//
//  Created by GitHub Copilot on 11/5/25.
//

import CommonCrypto
import Foundation
import AuthenticationServices
import UIKit

/// Concrete implementation responsible for acquiring GitLab access tokens and JWTs.
public final class GitLabAuthService: GitLabAuthProviding {

    private struct CachedAccessToken {
        let value: String
        let expiration: Date
        let username: String
    }

    private struct CachedJWT {
        let header: String
        let jwt: String
        let expiration: Date
        let username: String?
    }

    private struct AccessTokenResponse: Decodable {
        let accessToken: String
        let tokenType: String
        let expiresIn: Int
        let createdAt: Int?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case createdAt = "created_at"
        }
    }

    private struct GitLabUserResponse: Decodable {
        let username: String
    }

    private let configuration: GitLabAppConfig
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let sessionStore: GitLabSessionStore
    private let stateQueue = DispatchQueue(label: "com.qcbugplugin.gitlab-auth", attributes: .concurrent)

    private var cachedAccessToken: CachedAccessToken?
    private var cachedJWT: CachedJWT?
    private var authSession: ASWebAuthenticationSession?
    private var pendingAuthState: String?
    private var presentationContextProvider: AnyObject?

    public convenience init(
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

    public func fetchAuthorization(completion: @escaping (Result<GitLabAuthorization, GitLabAuthError>) -> Void) {
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

        guard let accessToken = currentCachedAccessToken(), accessToken.expiration > Date() else {
            DispatchQueue.main.async {
                completion(.failure(.userAuthenticationRequired))
            }
            return
        }

        switch generateJWT(using: accessToken) {
        case .failure(let error):
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        case .success(let cachedJWT):
            storeCachedJWT(cachedJWT)
            let authorization = GitLabAuthorization(
                authorizationHeader: cachedJWT.header,
                jwt: cachedJWT.jwt,
                username: cachedJWT.username,
                project: configuration.project
            )
            DispatchQueue.main.async {
                completion(.success(authorization))
            }
        }
    }

    public func clearCache() {
        stateQueue.async(flags: .barrier) {
            self.cachedAccessToken = nil
            self.cachedJWT = nil
            self.pendingAuthState = nil
            self.authSession = nil
            if #available(iOS 13.0, *) {
                self.presentationContextProvider = nil
            }
        }
        sessionStore.clearAll()
    }

    public func hasValidAuthorization() -> Bool {
        if let jwt = currentCachedJWT(), jwt.expiration > Date() {
            return true
        }
        if let token = currentCachedAccessToken(), token.expiration > Date() {
            return true
        }
        return false
    }

    // MARK: - Internal Workflow

    public func authenticateInteractively(from presenter: UIViewController, completion: @escaping (Result<GitLabAuthorization, GitLabAuthError>) -> Void) {
        if hasValidAuthorization() {
            fetchAuthorization(completion: completion)
            return
        }

        if pendingAuthState != nil {
            DispatchQueue.main.async {
                completion(.failure(.networkError("GitLab authentication is already in progress")))
            }
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

        let state = UUID().uuidString
        guard let authorizationURL = authorizationURL(state: state, redirectURI: redirectURI) else {
            DispatchQueue.main.async {
                completion(.failure(.invalidConfiguration))
            }
            return
        }
        pendingAuthState = state

        DispatchQueue.main.async {
            let session = ASWebAuthenticationSession(url: authorizationURL, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
                guard let self = self else { return }
                self.authSession = nil
                self.pendingAuthState = nil
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

                self.processAuthenticationCallback(callbackURL, expectedState: state, redirectURI: redirectURI) { result in
                    DispatchQueue.main.async {
                        completion(result)
                    }
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
                self.pendingAuthState = nil
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
        expectedState: String,
        redirectURI: URL,
        completion: @escaping (Result<GitLabAuthorization, GitLabAuthError>) -> Void
    ) {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            completion(.failure(.invalidResponse))
            return
        }

        let code = queryItems.first { $0.name == "code" }?.value
        let state = queryItems.first { $0.name == "state" }?.value

        guard let authorizationCode = code, state == expectedState else {
            completion(.failure(.invalidResponse))
            return
        }

        requestAccessToken(authorizationCode: authorizationCode, redirectURI: redirectURI.absoluteString) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let token):
                switch self.generateJWT(using: token) {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let cachedJWT):
                    self.storeCachedJWT(cachedJWT)
                    let authorization = GitLabAuthorization(
                        authorizationHeader: cachedJWT.header,
                        jwt: cachedJWT.jwt,
                        username: cachedJWT.username,
                        project: self.configuration.project
                    )
                    completion(.success(authorization))
                }
            }
        }
    }

    private func requestAccessToken(
        authorizationCode: String,
        redirectURI: String,
        completion: @escaping (Result<CachedAccessToken, GitLabAuthError>) -> Void
    ) {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            completion(.failure(.invalidConfiguration))
            return
        }

        var path = components.path
        if path.hasSuffix("/") {
            path.removeLast()
        }
        components.path = path.isEmpty ? "/oauth/token" : path + "/oauth/token"

        guard let url = components.url else {
            completion(.failure(.invalidConfiguration))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: authorizationCode),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "client_id", value: configuration.appId),
            URLQueryItem(name: "client_secret", value: configuration.secret)
        ]
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                let message = self.decodeErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
                completion(.failure(.networkError(message)))
                return
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            do {
                let response = try self.jsonDecoder.decode(AccessTokenResponse.self, from: data)
                let lifetime = TimeInterval(response.expiresIn)
                let expiry = Date().addingTimeInterval(max(lifetime - 30, 30))

                self.fetchUserProfile(accessToken: response.accessToken) { userResult in
                    switch userResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let userProfile):
                        let username = userProfile.username.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !username.isEmpty else {
                            completion(.failure(.invalidResponse))
                            return
                        }
                        let cachedToken = CachedAccessToken(
                            value: response.accessToken,
                            expiration: expiry,
                            username: username
                        )
                        self.storeCachedAccessToken(cachedToken)
                        completion(.success(cachedToken))
                    }
                }
            } catch {
                completion(.failure(.tokenGenerationFailed))
            }
        }.resume()
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

    private func fetchUserProfile(accessToken: String, completion: @escaping (Result<GitLabUserResponse, GitLabAuthError>) -> Void) {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            completion(.failure(.invalidConfiguration))
            return
        }

        var path = components.path
        if path.hasSuffix("/") {
            path.removeLast()
        }
        components.path = path.isEmpty ? "/api/v4/user" : path + "/api/v4/user"

        guard let url = components.url else {
            completion(.failure(.invalidConfiguration))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                let message = self.decodeErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
                completion(.failure(.networkError(message)))
                return
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            do {
                let user = try self.jsonDecoder.decode(GitLabUserResponse.self, from: data)
                completion(.success(user))
            } catch {
                print("❌ GitLabAuthService: Failed to decode GitLab user response - \(error.localizedDescription)")
                completion(.failure(.invalidResponse))
            }
        }.resume()
    }

    private func generateJWT(using token: CachedAccessToken) -> Result<CachedJWT, GitLabAuthError> {
        guard !configuration.signingKey.isEmpty else {
            return .failure(.invalidConfiguration)
        }

        let issuedAt = Date()
        let expiration = issuedAt.addingTimeInterval(max(configuration.jwtExpiration, 60))

        let header: [String: Any] = [
            "alg": "HS256",
            "typ": "JWT"
        ]

        let username = token.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else {
            return .failure(.jwtGenerationFailed("Missing GitLab username"))
        }

        var claims: [String: Any] = [
            "sub": username,
            "typ": "mcp-session",
            "iat": Int(issuedAt.timeIntervalSince1970),
            "exp": Int(expiration.timeIntervalSince1970)
        ]

        if let audience = configuration.audience {
            claims["aud"] = audience
        }

        for (key, value) in configuration.additionalClaims {
            claims[key] = value
        }

        guard JSONSerialization.isValidJSONObject(header), JSONSerialization.isValidJSONObject(claims) else {
            return .failure(.jwtGenerationFailed("Claims contain non-JSON compatible values"))
        }

        do {
            let headerData = try JSONSerialization.data(withJSONObject: header, options: [])
            let payloadData = try JSONSerialization.data(withJSONObject: claims, options: [])

            let headerPart = base64URLEncode(headerData)
            let payloadPart = base64URLEncode(payloadData)
            let signingInput = "\(headerPart).\(payloadPart)"

            guard let signatureData = hmacSHA256(signingInput: signingInput, key: configuration.signingKey) else {
                return .failure(.jwtGenerationFailed("Unable to sign JWT"))
            }

            let signaturePart = base64URLEncode(signatureData)
            let jwt = "\(signingInput).\(signaturePart)"
            let cachedJWT = CachedJWT(
                header: "Bearer \(jwt)",
                jwt: jwt,
                expiration: expiration,
                username: username
            )
            print("✅ GitLabAuthService: Generated GitLab session JWT expiring at \(expiration)")
            return .success(cachedJWT)
        } catch {
            return .failure(.jwtGenerationFailed(error.localizedDescription))
        }
    }

    // MARK: - Helpers

    private func hmacSHA256(signingInput: String, key: String) -> Data? {
        guard let messageData = signingInput.data(using: .utf8),
              let keyData = key.data(using: .utf8) else {
            return nil
        }

        var hmac = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        hmac.withUnsafeMutableBytes { hmacBytes in
            messageData.withUnsafeBytes { messageBytes in
                keyData.withUnsafeBytes { keyBytes in
                    CCHmac(
                        CCHmacAlgorithm(kCCHmacAlgSHA256),
                        keyBytes.baseAddress,
                        keyData.count,
                        messageBytes.baseAddress,
                        messageData.count,
                        hmacBytes.baseAddress
                    )
                }
            }
        }
        return hmac
    }

    private func base64URLEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func currentCachedAccessToken() -> CachedAccessToken? {
        stateQueue.sync { cachedAccessToken }
    }

    private func storeCachedAccessToken(_ token: CachedAccessToken) {
        stateQueue.sync(flags: .barrier) {
            self.cachedAccessToken = token
        }
        sessionStore.saveAccessToken(value: token.value, expiration: token.expiration, username: token.username)
    }

    private func currentCachedJWT() -> CachedJWT? {
        stateQueue.sync { cachedJWT }
    }

    private func storeCachedJWT(_ jwt: CachedJWT) {
        stateQueue.sync(flags: .barrier) {
            self.cachedJWT = jwt
        }
        sessionStore.saveJWT(jwt: jwt.jwt, header: jwt.header, expiration: jwt.expiration, username: jwt.username)
    }

    private func restorePersistedState() {
        if let storedToken = sessionStore.loadAccessToken() {
            let token = CachedAccessToken(
                value: storedToken.value,
                expiration: storedToken.expiration,
                username: storedToken.username
            )
            stateQueue.sync(flags: .barrier) {
                self.cachedAccessToken = token
            }
        }

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

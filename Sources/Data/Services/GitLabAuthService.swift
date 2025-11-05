//
//  GitLabAuthService.swift
//  QCBugPlugin
//
//  Created by GitHub Copilot on 11/5/25.
//

import CommonCrypto
import Foundation

/// Concrete implementation responsible for acquiring GitLab access tokens and JWTs.
public final class GitLabAuthService: GitLabAuthProviding {

    private struct CachedAccessToken {
        let value: String
        let expiration: Date
    }

    private struct CachedJWT {
        let value: String
        let expiration: Date
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

    private let configuration: GitLabAppConfig
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let stateQueue = DispatchQueue(label: "com.qcbugplugin.gitlab-auth", attributes: .concurrent)

    private var cachedAccessToken: CachedAccessToken?
    private var cachedJWT: CachedJWT?

    public init(configuration: GitLabAppConfig, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
        self.jsonDecoder = JSONDecoder()
    }

    // MARK: - GitLabAuthProviding

    public func fetchAuthorizationHeader(completion: @escaping (Result<String, GitLabAuthError>) -> Void) {
        if let cachedJWT = currentCachedJWT(), cachedJWT.expiration > Date() {
            DispatchQueue.main.async {
                completion(.success(cachedJWT.value))
            }
            return
        }

        obtainAuthorizationHeader { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    public func clearCache() {
        stateQueue.async(flags: .barrier) {
            self.cachedAccessToken = nil
            self.cachedJWT = nil
        }
    }

    // MARK: - Internal Workflow

    private func obtainAuthorizationHeader(completion: @escaping (Result<String, GitLabAuthError>) -> Void) {
        getValidAccessToken { [weak self] result in
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
                    completion(.success(cachedJWT.value))
                }
            }
        }
    }

    private func getValidAccessToken(completion: @escaping (Result<CachedAccessToken, GitLabAuthError>) -> Void) {
        if let cachedToken = currentCachedAccessToken(), cachedToken.expiration > Date() {
            completion(.success(cachedToken))
            return
        }

        requestAccessToken(completion: completion)
    }

    private func requestAccessToken(completion: @escaping (Result<CachedAccessToken, GitLabAuthError>) -> Void) {
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
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "client_id", value: configuration.appId),
            URLQueryItem(name: "client_secret", value: configuration.secret),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " "))
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
                print("❌ GitLabAuthService: Token request failed - \(message)")
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
                let cachedToken = CachedAccessToken(value: response.accessToken, expiration: expiry)
                self.storeCachedAccessToken(cachedToken)
                print("✅ GitLabAuthService: Obtained GitLab access token (expires in \(response.expiresIn) seconds)")
                completion(.success(cachedToken))
            } catch {
                let message = error.localizedDescription
                print("❌ GitLabAuthService: Failed to decode access token response - \(message)")
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

    private func generateJWT(using token: CachedAccessToken) -> Result<CachedJWT, GitLabAuthError> {
        let issuedAt = Date()
        let expiration = issuedAt.addingTimeInterval(max(configuration.jwtExpiration, 60))

        let header: [String: Any] = [
            "alg": "HS256",
            "typ": "JWT"
        ]

        var claims: [String: Any] = [
            "iss": configuration.appId,
            "iat": Int(issuedAt.timeIntervalSince1970),
            "exp": Int(expiration.timeIntervalSince1970),
            "token": token.value,
            "scope": configuration.scopes.joined(separator: " ")
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

            guard let signatureData = hmacSHA256(signingInput: signingInput) else {
                return .failure(.jwtGenerationFailed("Unable to sign JWT"))
            }

            let signaturePart = base64URLEncode(signatureData)
            let jwt = "\(signingInput).\(signaturePart)"
            let cachedJWT = CachedJWT(value: "Bearer \(jwt)", expiration: expiration)
            print("✅ GitLabAuthService: Generated GitLab JWT expiring at \(expiration)")
            return .success(cachedJWT)
        } catch {
            return .failure(.jwtGenerationFailed(error.localizedDescription))
        }
    }

    // MARK: - Helpers

    private func hmacSHA256(signingInput: String) -> Data? {
        guard let messageData = signingInput.data(using: .utf8),
              let keyData = configuration.secret.data(using: .utf8) else {
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
        stateQueue.async(flags: .barrier) {
            self.cachedAccessToken = token
        }
    }

    private func currentCachedJWT() -> CachedJWT? {
        stateQueue.sync { cachedJWT }
    }

    private func storeCachedJWT(_ jwt: CachedJWT) {
        stateQueue.async(flags: .barrier) {
            self.cachedJWT = jwt
        }
    }
}

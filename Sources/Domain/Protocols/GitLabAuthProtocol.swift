//
//  GitLabAuthProtocol.swift
//  QCBugPlugin
//
//  Created by GitHub Copilot on 11/5/25.
//

import Foundation

/// GitLab authorization information returned by auth providers.
public struct GitLabAuthorization {
    public let authorizationHeader: String
    public let jwt: String
    public let userId: Int?

    public init(authorizationHeader: String, jwt: String, userId: Int?) {
        self.authorizationHeader = authorizationHeader
        self.jwt = jwt
        self.userId = userId
    }
}

/// Abstraction for retrieving GitLab authorization credentials.
public protocol GitLabAuthProviding: AnyObject {
    /// Resolves GitLab authorization credentials. Implementations should cache values when appropriate.
    func fetchAuthorization(completion: @escaping (Result<GitLabAuthorization, GitLabAuthError>) -> Void)

    /// Clears any cached tokens. Optional for implementations that maintain cache state.
    func clearCache()
}

/// Errors that can occur when acquiring GitLab credentials.
public enum GitLabAuthError: Error {
    case invalidConfiguration
    case networkError(String)
    case invalidResponse
    case tokenGenerationFailed
    case jwtGenerationFailed(String)
}

extension GitLabAuthError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid GitLab application configuration"
        case .networkError(let message):
            return "GitLab network error: \(message)"
        case .invalidResponse:
            return "GitLab returned an unexpected response"
        case .tokenGenerationFailed:
            return "Failed to obtain GitLab access token"
        case .jwtGenerationFailed(let message):
            return "Failed to generate GitLab JWT: \(message)"
        }
    }
}

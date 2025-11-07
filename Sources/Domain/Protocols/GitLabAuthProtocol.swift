//
//  GitLabAuthProtocol.swift
//  QCBugPlugin
//
//  Created by GitHub Copilot on 11/5/25.
//

import Foundation
import UIKit

/// GitLab authorization information returned by auth providers.
struct GitLabAuthorization {
    let authorizationHeader: String
    let jwt: String
    let username: String?
    let project: String?
    
    init(authorizationHeader: String, jwt: String, username: String?, project: String? = nil) {
        self.authorizationHeader = authorizationHeader
        self.jwt = jwt
        self.username = username
        self.project = project
    }
}

/// Abstraction for retrieving GitLab authorization credentials.
protocol GitLabAuthProviding: AnyObject {
    /// Resolves GitLab authorization credentials. Implementations should cache values when appropriate.
    func fetchAuthorization(completion: @escaping (Result<GitLabAuthorization, GitLabAuthError>) -> Void)

    /// Clears any cached tokens. Optional for implementations that maintain cache state.
    func clearCache()

    /// Returns true when a valid cached authorization exists.
    func hasValidAuthorization() -> Bool

    /// Begins an interactive authentication flow if required. Completion executes on the main queue.
    func authenticateInteractively(from presenter: UIViewController, completion: @escaping (Result<GitLabAuthorization, GitLabAuthError>) -> Void)

    /// Fetches project members for a given GitLab project.
    func fetchProjectMembers(project: String, completion: @escaping (Result<[GitLabMember], GitLabAuthError>) -> Void)
}

/// Errors that can occur when acquiring GitLab credentials.
enum GitLabAuthError: Error {
    case invalidConfiguration
    case networkError(String)
    case invalidResponse
    case tokenGenerationFailed
    case jwtGenerationFailed(String)
    case userAuthenticationRequired
    case authenticationCancelled
    case notAuthenticated
}

extension GitLabAuthError: LocalizedError {
    var errorDescription: String? {
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
        case .userAuthenticationRequired:
            return "Sign in with GitLab to continue"
        case .authenticationCancelled:
            return "GitLab authentication was cancelled"
        case .notAuthenticated:
            return "Not authenticated with GitLab"
        }
    }
}

//
//  GitLabAppConfiguration.swift
//  QCBugPlugin
//
//  Created by GitHub Copilot on 11/5/25.
//

import Foundation

/// Configuration describing a GitLab application used for webhook authentication.
public struct GitLabAppConfig {
    public let appId: String
    public let secret: String
    public let baseURL: URL
    public let scopes: [String]
    public let audience: String?
    public let jwtExpiration: TimeInterval
    public let additionalClaims: [String: Any]
    public let signingKey: String
    public let redirectURI: URL?
    public let project: String?

    public init(
        appId: String,
        secret: String,
        signingKey: String,
        redirectURI: URL? = nil,
        baseURL: URL = URL(string: "https://gitlab.com")!,
        scopes: [String] = ["api"],
        audience: String? = nil,
        jwtExpiration: TimeInterval = 24 * 60 * 60 * 31, // 31 days (matching TypeScript implementation)
        additionalClaims: [String: Any] = [:],
        project: String? = nil
    ) {
        self.appId = appId
        self.secret = secret
        self.signingKey = signingKey
        self.redirectURI = redirectURI
        self.baseURL = baseURL
        self.scopes = scopes
        self.audience = audience
        self.jwtExpiration = jwtExpiration
        self.additionalClaims = additionalClaims
        if let rawProject = project?.trimmingCharacters(in: .whitespacesAndNewlines), !rawProject.isEmpty {
            self.project = rawProject
        } else {
            self.project = nil
        }
    }
}

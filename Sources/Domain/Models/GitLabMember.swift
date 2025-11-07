//
//  GitLabMember.swift
//  QCBugPlugin
//
//  Created by Claude on 11/7/25.
//  Copyright © 2025 VietUnion. All rights reserved.
//

import Foundation

/// Represents a GitLab project member
public struct GitLabMember: Codable {
    public let id: Int
    public let username: String
    public let name: String
    public let state: String?
    public let avatarURL: String?
    public let webURL: String?
    public let accessLevel: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case name
        case state
        case avatarURL = "avatar_url"
        case webURL = "web_url"
        case accessLevel = "access_level"
    }

    public init(id: Int, username: String, name: String, state: String? = nil, avatarURL: String? = nil, webURL: String? = nil, accessLevel: Int? = nil) {
        self.id = id
        self.username = username
        self.name = name
        self.state = state
        self.avatarURL = avatarURL
        self.webURL = webURL
        self.accessLevel = accessLevel
    }
}

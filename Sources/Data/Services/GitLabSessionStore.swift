import Foundation

final class GitLabSessionStore {
    static let shared = GitLabSessionStore()

    private struct StoredAccessToken: Codable {
        let value: String
        let expiration: Date
        let username: String
    }

    private struct StoredJWT: Codable {
        let jwt: String
        let header: String
        let expiration: Date?
        let username: String?
    }

    private enum Keys {
        static let jwtPayload = "com.qcbugplugin.gitlab.jwt.payload"
        static let tokenPayload = "com.qcbugplugin.gitlab.accessToken.payload"
        static let jwtString = "com.qcbugplugin.gitlab.jwt"
        static let jwtHeader = "com.qcbugplugin.gitlab.jwt.header"
        static let username = "com.qcbugplugin.gitlab.username"
    }

    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "com.qcbugplugin.gitlab.sessionstore", attributes: .concurrent)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public Accessors

    func currentJWT() -> String? {
        queue.sync {
            defaults.string(forKey: Keys.jwtString) ?? loadJWTPayload()?.jwt
        }
    }

    func currentUsername() -> String? {
        queue.sync {
            defaults.string(forKey: Keys.username) ?? loadJWTPayload()?.username
        }
    }

    func loadAccessToken() -> (value: String, expiration: Date, username: String)? {
        queue.sync {
            guard
                let data = defaults.data(forKey: Keys.tokenPayload),
                let stored = try? decoder.decode(StoredAccessToken.self, from: data)
            else {
                return nil
            }
            return (value: stored.value, expiration: stored.expiration, username: stored.username)
        }
    }

    func loadJWT() -> (jwt: String, header: String, expiration: Date?, username: String?)? {
        queue.sync {
            if let payload = loadJWTPayload() {
                return (jwt: payload.jwt, header: payload.header, expiration: payload.expiration, username: payload.username)
            }

            guard let jwt = defaults.string(forKey: Keys.jwtString) else {
                return nil
            }
            let username = defaults.string(forKey: Keys.username)
            let header = defaults.string(forKey: Keys.jwtHeader) ?? "Bearer \(jwt)"
            return (jwt: jwt, header: header, expiration: nil, username: username)
        }
    }

    // MARK: - Mutations

    func saveAccessToken(value: String, expiration: Date, username: String) {
        let payload = StoredAccessToken(value: value, expiration: expiration, username: username)
        queue.async(flags: .barrier) {
            if let data = try? self.encoder.encode(payload) {
                self.defaults.set(data, forKey: Keys.tokenPayload)
            }
        }
    }

    func saveJWT(jwt: String, header: String, expiration: Date?, username: String?) {
        let payload = StoredJWT(jwt: jwt, header: header, expiration: expiration, username: username)
        queue.async(flags: .barrier) {
            if let data = try? self.encoder.encode(payload) {
                self.defaults.set(data, forKey: Keys.jwtPayload)
            }
            self.defaults.set(jwt, forKey: Keys.jwtString)
            self.defaults.set(header, forKey: Keys.jwtHeader)
            if let username = username, !username.isEmpty {
                self.defaults.set(username, forKey: Keys.username)
            } else {
                self.defaults.removeObject(forKey: Keys.username)
            }
        }
    }

    func clearAccessToken() {
        queue.async(flags: .barrier) {
            self.defaults.removeObject(forKey: Keys.tokenPayload)
        }
    }

    func clearJWT() {
        queue.async(flags: .barrier) {
            self.defaults.removeObject(forKey: Keys.jwtPayload)
            self.defaults.removeObject(forKey: Keys.jwtString)
            self.defaults.removeObject(forKey: Keys.jwtHeader)
            self.defaults.removeObject(forKey: Keys.username)
        }
    }

    func clearAll() {
        queue.async(flags: .barrier) {
            self.defaults.removeObject(forKey: Keys.tokenPayload)
            self.defaults.removeObject(forKey: Keys.jwtPayload)
            self.defaults.removeObject(forKey: Keys.jwtString)
            self.defaults.removeObject(forKey: Keys.jwtHeader)
            self.defaults.removeObject(forKey: Keys.username)
        }
    }

    // MARK: - Helpers

    private func loadJWTPayload() -> StoredJWT? {
        guard let data = defaults.data(forKey: Keys.jwtPayload) else {
            return nil
        }
        return try? decoder.decode(StoredJWT.self, from: data)
    }
}

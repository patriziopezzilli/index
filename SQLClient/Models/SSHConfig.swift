import Foundation

struct SSHConfig: Codable, Equatable, Hashable {
    var enabled: Bool
    var host: String
    var port: Int
    var username: String
    var password: String
    var useKeyAuthentication: Bool
    var privateKeyPath: String?

    init() {
        self.enabled = false
        self.host = ""
        self.port = 22
        self.username = ""
        self.password = ""
        self.useKeyAuthentication = false
        self.privateKeyPath = nil
    }

    var isValid: Bool {
        guard enabled else { return true }
        return !host.isEmpty && !username.isEmpty && (useKeyAuthentication ? privateKeyPath != nil : !password.isEmpty)
    }
}

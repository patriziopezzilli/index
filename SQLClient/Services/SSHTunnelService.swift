import Foundation

/// Service for managing SSH tunnels with port forwarding
/// Enables secure connections to remote databases through SSH
/// Uses native ssh command for reliable port forwarding
class SSHTunnelService {

    // MARK: - Properties

    private let sshConfig: SSHConfig
    private let remoteHost: String
    private let remotePort: Int

    private var sshProcess: Process?
    private(set) var localPort: Int = 0
    private(set) var isConnected = false

    // MARK: - Initialization

    init(sshConfig: SSHConfig, remoteHost: String, remotePort: Int) {
        self.sshConfig = sshConfig
        self.remoteHost = remoteHost
        self.remotePort = remotePort
    }

    deinit {
        disconnect()
    }

    // MARK: - Connection Management

    /// Establishes SSH tunnel and returns local port
    func connect() async throws -> Int {
        guard sshConfig.enabled && sshConfig.isValid else {
            throw SSHTunnelError.invalidConfiguration
        }

        // Find available local port
        localPort = try findAvailablePort()

        // Create temporary file for password if using password auth
        var passwordFileURL: URL?
        if !sshConfig.useKeyAuthentication {
            passwordFileURL = try createPasswordFile()
        }

        defer {
            if let url = passwordFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

            var arguments = [
                "-N",  // No command execution
                "-L", "\(localPort):\(remoteHost):\(remotePort)",  // Local port forwarding
                "-o", "StrictHostKeyChecking=no",  // Don't prompt for host key
                "-o", "UserKnownHostsFile=/dev/null",  // Don't save host key
                "-o", "ServerAliveInterval=60",  // Keep connection alive
                "-o", "ServerAliveCountMax=3",
                "-p", "\(sshConfig.port)",
                "\(sshConfig.username)@\(sshConfig.host)"
            ]

            // Add authentication options
            if sshConfig.useKeyAuthentication, let keyPath = sshConfig.privateKeyPath {
                arguments.insert(contentsOf: ["-i", keyPath], at: 0)
            } else if let passwordFile = passwordFileURL {
                // Use sshpass if available, otherwise use expect
                arguments.insert(contentsOf: [
                    "-o", "PreferredAuthentications=password",
                    "-o", "PubkeyAuthentication=no"
                ], at: 0)
            }

            process.arguments = arguments

            // Set up environment for password authentication
            var environment = ProcessInfo.processInfo.environment
            if !sshConfig.useKeyAuthentication {
                environment["SSH_ASKPASS"] = "/bin/echo"
                environment["DISPLAY"] = ":0"
                environment["SSH_ASKPASS_REQUIRE"] = "force"
            }
            process.environment = environment

            // Capture output
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Handle password input
            if !sshConfig.useKeyAuthentication {
                let inputPipe = Pipe()
                process.standardInput = inputPipe

                // Write password to stdin
                if let passwordData = "\(sshConfig.password)\n".data(using: .utf8) {
                    inputPipe.fileHandleForWriting.write(passwordData)
                    try? inputPipe.fileHandleForWriting.close()
                }
            }

            try process.run()
            sshProcess = process

            // Wait for tunnel to establish
            try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

            // Check if process is still running
            guard process.isRunning else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw SSHTunnelError.connectionFailed(errorMessage)
            }

            isConnected = true
            return localPort

        } catch {
            sshProcess?.terminate()
            sshProcess = nil
            throw SSHTunnelError.connectionFailed(error.localizedDescription)
        }
    }

    /// Disconnects SSH tunnel
    func disconnect() {
        guard isConnected else { return }

        sshProcess?.terminate()
        sshProcess?.waitUntilExit()
        sshProcess = nil

        isConnected = false
        localPort = 0
    }

    // MARK: - Private Helpers

    private func findAvailablePort() throws -> Int {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else {
            throw SSHTunnelError.noAvailablePort
        }
        defer { Darwin.close(socket) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0  // Let system choose port
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.bind(socket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            throw SSHTunnelError.noAvailablePort
        }

        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let getsocknameResult = withUnsafeMutablePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.getsockname(socket, sockaddrPtr, &addrLen)
            }
        }

        guard getsocknameResult == 0 else {
            throw SSHTunnelError.noAvailablePort
        }

        return Int(UInt16(bigEndian: addr.sin_port))
    }

    private func createPasswordFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("ssh_pwd_\(UUID().uuidString)")

        try sshConfig.password.write(to: fileURL, atomically: true, encoding: .utf8)

        // Set permissions to readable only by owner
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o600)],
            ofItemAtPath: fileURL.path
        )

        return fileURL
    }
}

// MARK: - Errors

enum SSHTunnelError: LocalizedError {
    case invalidConfiguration
    case connectionFailed(String)
    case noAvailablePort
    case tunnelNotEstablished

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "SSH configuration is invalid"
        case .connectionFailed(let message):
            return "SSH connection failed: \(message)"
        case .noAvailablePort:
            return "Could not find available local port"
        case .tunnelNotEstablished:
            return "SSH tunnel not established"
        }
    }
}

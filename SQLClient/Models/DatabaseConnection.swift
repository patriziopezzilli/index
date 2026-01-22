import SwiftUI

enum DatabaseType: String, Codable, CaseIterable {
    case postgresql = "PostgreSQL"
    case mysql = "MySQL"
    case sqlite = "SQLite"
    case sqlserver = "SQL Server"

    var icon: String {
        switch self {
        case .postgresql: return "cylinder.fill"
        case .mysql: return "server.rack"
        case .sqlite: return "internaldrive.fill"
        case .sqlserver: return "building.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .postgresql: return .blue
        case .mysql: return .orange
        case .sqlite: return .green
        case .sqlserver: return .red
        }
    }

    var defaultPort: Int {
        switch self {
        case .postgresql: return 5432
        case .mysql: return 3306
        case .sqlite: return 0
        case .sqlserver: return 1433
        }
    }
}

struct DatabaseConnection: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: DatabaseType
    var host: String
    var port: Int
    var database: String
    var username: String
    var password: String
    var sshConfig: SSHConfig
    var createdAt: Date

    init(name: String, type: DatabaseType, host: String = "localhost", port: Int? = nil, database: String = "", username: String = "", password: String = "", sshConfig: SSHConfig = SSHConfig()) {
        self.name = name
        self.type = type
        self.host = host
        self.port = port ?? type.defaultPort
        self.database = database
        self.username = username
        self.password = password
        self.sshConfig = sshConfig
        self.createdAt = Date()
    }

    var displayInfo: String {
        if type == .sqlite {
            return database.isEmpty ? "Local Database" : database
        }
        var info = "\(username)@\(host):\(port)"
        if sshConfig.enabled {
            info += " (SSH)"
        }
        return info
    }
}

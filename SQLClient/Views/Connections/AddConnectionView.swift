import SwiftUI

struct AddConnectionView: View {
    var onSave: ((DatabaseConnection) -> Void)? = nil

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var databaseService = DatabaseService()

    @State private var name = ""
    @State private var selectedType: DatabaseType = .postgresql
    @State private var host = "localhost"
    @State private var port = ""
    @State private var database = ""
    @State private var username = ""
    @State private var password = ""
    @State private var sshConfig = SSHConfig()
    @State private var isTestingConnection = false
    @State private var testResult: TestResult?

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Connection Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))

                            TextField("My Database", text: $name)
                                .textFieldStyle(CustomTextFieldStyle())
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Database Type")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(DatabaseType.allCases, id: \.self) { type in
                                        DatabaseTypeButton(
                                            type: type,
                                            isSelected: selectedType == type,
                                            action: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    selectedType = type
                                                    port = String(type.defaultPort)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }

                        if selectedType != .sqlite {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Host")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))

                                TextField("localhost", text: $host)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.none)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Port")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))

                                TextField("5432", text: $port)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .keyboardType(.numberPad)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Database")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))

                            TextField(selectedType == .sqlite ? "database.db" : "mydatabase", text: $database)
                                .textFieldStyle(CustomTextFieldStyle())
                                .autocapitalization(.none)
                        }

                        if selectedType != .sqlite {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))

                                TextField("username", text: $username)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.none)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))

                                SecureField("password", text: $password)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }

                            SSHConfigSection(sshConfig: $sshConfig)
                        }

                        if let result = testResult {
                            HStack(spacing: 12) {
                                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.isSuccess ? .green : .red)

                                Text(result.isSuccess ? "Connection successful!" : "Connection failed")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(result.isSuccess ? .green : .red)

                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill((result.isSuccess ? Color.green : Color.red).opacity(0.2))
                            )
                            .transition(.scale.combined(with: .opacity))
                        }

                        Button(action: testConnection) {
                            HStack(spacing: 8) {
                                if isTestingConnection {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                    Text("Test Connection")
                                }
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        .disabled(isTestingConnection || !isFormValid)

                        Button(action: saveConnection) {
                            Text("Save Connection")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isFormValid ? .white : Color.white.opacity(0.3))
                                )
                        }
                        .disabled(!isFormValid)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            port = String(selectedType.defaultPort)
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty && !database.isEmpty && (selectedType == .sqlite || (!host.isEmpty && !username.isEmpty))
    }

    private func testConnection() {
        isTestingConnection = true
        testResult = nil

        let connection = DatabaseConnection(
            name: name,
            type: selectedType,
            host: host,
            port: Int(port),
            database: database,
            username: username,
            password: password,
            sshConfig: sshConfig
        )

        Task {
            let success = await databaseService.testConnection(connection)

            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    testResult = success ? .success : .failure("Connection failed")
                    isTestingConnection = false
                }
            }
        }
    }

    private func saveConnection() {
        let connection = DatabaseConnection(
            name: name,
            type: selectedType,
            host: host,
            port: Int(port) ?? selectedType.defaultPort,
            database: database,
            username: username,
            password: password,
            sshConfig: sshConfig
        )

        if let onSave = onSave {
            // Use callback if provided (from ConnectionsListView)
            onSave(connection)
        } else {
            // Fallback to appState for backwards compatibility
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appState.addConnection(connection)
            }
            dismiss()
        }
    }
}

extension AddConnectionView.TestResult {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

struct DatabaseTypeButton: View {
    let type: DatabaseType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? type.color.opacity(0.2) : Color.white.opacity(0.05))
                        .frame(width: 60, height: 60)

                    Image(systemName: type.icon)
                        .font(.system(size: 28))
                        .foregroundColor(isSelected ? type.color : .white.opacity(0.5))
                }

                Text(type.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            }
            .frame(width: 90)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
            )
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16))
            .foregroundColor(.white)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
    }
}

struct SSHConfigSection: View {
    @Binding var sshConfig: SSHConfig
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.purple)

                    Text("SSH Tunnel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Toggle("", isOn: $sshConfig.enabled)
                        .labelsHidden()
                        .tint(.purple)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.1))
                )
            }

            if isExpanded && sshConfig.enabled {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SSH Host")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        TextField("ssh.example.com", text: $sshConfig.host)
                            .textFieldStyle(CustomTextFieldStyle())
                            .autocapitalization(.none)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("SSH Port")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        TextField("22", value: $sshConfig.port, format: .number)
                            .textFieldStyle(CustomTextFieldStyle())
                            .keyboardType(.numberPad)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("SSH Username")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        TextField("username", text: $sshConfig.username)
                            .textFieldStyle(CustomTextFieldStyle())
                            .autocapitalization(.none)
                    }

                    Toggle(isOn: $sshConfig.useKeyAuthentication) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use Key Authentication")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)

                            Text("Use private key instead of password")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .tint(.purple)

                    if sshConfig.useKeyAuthentication {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Private Key Path")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))

                            TextField("~/.ssh/id_rsa", text: Binding(
                                get: { sshConfig.privateKeyPath ?? "" },
                                set: { sshConfig.privateKeyPath = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(CustomTextFieldStyle())
                            .autocapitalization(.none)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SSH Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))

                            SecureField("password", text: $sshConfig.password)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

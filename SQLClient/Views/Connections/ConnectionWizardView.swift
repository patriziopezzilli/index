import SwiftUI

struct ConnectionWizardView: View {
    var onSave: ((DatabaseConnection) -> Void)? = nil

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var databaseService: DatabaseService

    @State private var currentStep = 0
    @State private var name = ""
    @State private var selectedType: DatabaseType = .postgresql
    @State private var host = "localhost"
    @State private var port = ""
    @State private var database = ""
    @State private var username = ""
    @State private var password = ""
    @State private var sshConfig = SSHConfig()
    @State private var isTestingConnection = false
    @State private var testResult: ConnectionTestResult?
    @State private var animateStepChange = false

    enum ConnectionTestResult {
        case success
        case failure(String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    private let totalSteps = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                WizardProgressBar(currentStep: currentStep, totalSteps: totalSteps)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Step content
                TabView(selection: $currentStep) {
                    // Step 1: Database Type
                    WizardStepView(
                        stepNumber: 1,
                        title: "Choose Database",
                        subtitle: "Select the type of database you want to connect to"
                    ) {
                        DatabaseTypeSelector(selectedType: $selectedType) {
                            port = String(selectedType.defaultPort)
                        }
                    }
                    .tag(0)

                    // Step 2: Connection Details
                    WizardStepView(
                        stepNumber: 2,
                        title: "Connection Details",
                        subtitle: selectedType == .sqlite ? "Configure your SQLite database" : "Enter your server information"
                    ) {
                        ConnectionDetailsForm(
                            selectedType: selectedType,
                            host: $host,
                            port: $port,
                            database: $database
                        )
                    }
                    .tag(1)

                    // Step 3: Authentication (skip for SQLite)
                    WizardStepView(
                        stepNumber: 3,
                        title: selectedType == .sqlite ? "Name Your Connection" : "Authentication",
                        subtitle: selectedType == .sqlite ? "Give your connection a memorable name" : "Enter your credentials"
                    ) {
                        if selectedType == .sqlite {
                            ConnectionNameForm(name: $name)
                        } else {
                            AuthenticationForm(
                                username: $username,
                                password: $password,
                                name: $name,
                                sshConfig: $sshConfig
                            )
                        }
                    }
                    .tag(2)

                    // Step 4: Test & Save
                    WizardStepView(
                        stepNumber: 4,
                        title: "Test Connection",
                        subtitle: "Verify your connection works before saving"
                    ) {
                        TestConnectionView(
                            connection: buildConnection(),
                            isTestingConnection: $isTestingConnection,
                            testResult: $testResult,
                            onTest: testConnection
                        )
                    }
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)

                // Navigation buttons
                WizardNavigationBar(
                    currentStep: $currentStep,
                    totalSteps: totalSteps,
                    canProceed: canProceedFromCurrentStep,
                    isLastStep: currentStep == totalSteps - 1,
                    onNext: nextStep,
                    onBack: previousStep,
                    onComplete: saveConnection
                )
            }
            .background(Color(.systemBackground))
            .navigationTitle("New Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            port = String(selectedType.defaultPort)
        }
    }

    private var canProceedFromCurrentStep: Bool {
        switch currentStep {
        case 0: return true // Database type always selected
        case 1: return selectedType == .sqlite ? !database.isEmpty : (!host.isEmpty && !database.isEmpty)
        case 2: return !name.isEmpty && (selectedType == .sqlite || !username.isEmpty)
        case 3: return testResult?.isSuccess == true
        default: return false
        }
    }

    private func nextStep() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if currentStep < totalSteps - 1 {
                currentStep += 1
            }
        }
    }

    private func previousStep() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if currentStep > 0 {
                currentStep -= 1
                testResult = nil
            }
        }
    }

    private func buildConnection() -> DatabaseConnection {
        DatabaseConnection(
            name: name,
            type: selectedType,
            host: host,
            port: Int(port) ?? selectedType.defaultPort,
            database: database,
            username: username,
            password: password,
            sshConfig: sshConfig
        )
    }

    private func testConnection() {
        isTestingConnection = true
        testResult = nil

        Task {
            let success = await databaseService.testConnection(buildConnection())

            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    testResult = success ? .success : .failure("Connection failed")
                    isTestingConnection = false
                }
            }
        }
    }

    private func saveConnection() {
        let connection = buildConnection()

        if let onSave = onSave {
            onSave(connection)
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                databaseService.saveConnection(connection)
            }
            dismiss()
        }
    }
}

// MARK: - Progress Bar

struct WizardProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                ProgressStepIndicator(
                    stepNumber: step + 1,
                    isActive: step == currentStep,
                    isCompleted: step < currentStep
                )

                if step < totalSteps - 1 {
                    ProgressConnector(isCompleted: step < currentStep)
                }
            }
        }
        .padding(.vertical, 16)
    }
}

struct ProgressStepIndicator: View {
    let stepNumber: Int
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 36, height: 36)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("\(stepNumber)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isActive ? .white : .secondary)
            }
        }
        .scaleEffect(isActive ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }

    private var backgroundColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return .blue
        } else {
            return Color(.tertiarySystemFill)
        }
    }
}

struct ProgressConnector: View {
    let isCompleted: Bool

    var body: some View {
        Rectangle()
            .fill(isCompleted ? Color.green : Color(.tertiarySystemFill))
            .frame(height: 3)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Step Container

struct WizardStepView<Content: View>: View {
    let stepNumber: Int
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)

                content

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Database Type Selector

struct DatabaseTypeSelector: View {
    @Binding var selectedType: DatabaseType
    var onChange: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ForEach(DatabaseType.allCases, id: \.self) { type in
                DatabaseTypeCard(
                    type: type,
                    isSelected: selectedType == type
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedType = type
                        onChange()
                    }
                }
            }
        }
    }
}

struct DatabaseTypeCard: View {
    let type: DatabaseType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? type.color.opacity(0.15) : Color(.secondarySystemBackground))
                        .frame(width: 56, height: 56)

                    Image(systemName: type.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? type.color : .secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(typeDescription(for: type))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(type.color)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? type.color : Color.clear, lineWidth: 2)
            )
        }
    }

    private func typeDescription(for type: DatabaseType) -> String {
        switch type {
        case .postgresql:
            return "Advanced open-source relational database"
        case .mysql:
            return "Popular open-source database system"
        case .sqlite:
            return "Lightweight local file-based database"
        }
    }
}

// MARK: - Connection Details Form

struct ConnectionDetailsForm: View {
    let selectedType: DatabaseType
    @Binding var host: String
    @Binding var port: String
    @Binding var database: String

    var body: some View {
        VStack(spacing: 20) {
            if selectedType != .sqlite {
                WizardTextField(
                    title: "Host",
                    placeholder: "localhost or IP address",
                    text: $host,
                    icon: "server.rack"
                )

                WizardTextField(
                    title: "Port",
                    placeholder: String(selectedType.defaultPort),
                    text: $port,
                    icon: "number",
                    keyboardType: .numberPad
                )
            }

            WizardTextField(
                title: "Database Name",
                placeholder: selectedType == .sqlite ? "mydatabase.db" : "mydatabase",
                text: $database,
                icon: "cylinder"
            )

            if selectedType == .sqlite {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)

                    Text("SQLite databases are stored locally on your device")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
    }
}

// MARK: - Authentication Form

struct AuthenticationForm: View {
    @Binding var username: String
    @Binding var password: String
    @Binding var name: String
    @Binding var sshConfig: SSHConfig
    @State private var showSSHConfig = false

    var body: some View {
        VStack(spacing: 20) {
            WizardTextField(
                title: "Connection Name",
                placeholder: "My Database",
                text: $name,
                icon: "tag"
            )

            WizardTextField(
                title: "Username",
                placeholder: "database_user",
                text: $username,
                icon: "person"
            )

            WizardSecureField(
                title: "Password",
                placeholder: "Enter password",
                text: $password,
                icon: "lock"
            )

            // SSH Tunnel Section
            VStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showSSHConfig.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.purple)
                            .frame(width: 24)

                        Text("SSH Tunnel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)

                        Spacer()

                        Toggle("", isOn: $sshConfig.enabled)
                            .labelsHidden()
                            .tint(.purple)

                        Image(systemName: showSSHConfig ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.purple.opacity(0.1))
                    )
                }

                if showSSHConfig && sshConfig.enabled {
                    VStack(spacing: 16) {
                        WizardTextField(
                            title: "SSH Host",
                            placeholder: "ssh.example.com",
                            text: $sshConfig.host,
                            icon: "server.rack"
                        )

                        HStack(spacing: 16) {
                            WizardTextField(
                                title: "SSH Port",
                                placeholder: "22",
                                text: Binding(
                                    get: { String(sshConfig.port) },
                                    set: { sshConfig.port = Int($0) ?? 22 }
                                ),
                                icon: "number",
                                keyboardType: .numberPad
                            )

                            WizardTextField(
                                title: "SSH User",
                                placeholder: "user",
                                text: $sshConfig.username,
                                icon: "person"
                            )
                        }

                        WizardSecureField(
                            title: "SSH Password",
                            placeholder: "SSH password",
                            text: $sshConfig.password,
                            icon: "lock"
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

// MARK: - Connection Name Form (SQLite)

struct ConnectionNameForm: View {
    @Binding var name: String

    var body: some View {
        VStack(spacing: 20) {
            WizardTextField(
                title: "Connection Name",
                placeholder: "My Local Database",
                text: $name,
                icon: "tag"
            )

            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)

                Text("Choose a name that helps you remember this connection")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
            )
        }
    }
}

// MARK: - Test Connection View

struct TestConnectionView: View {
    let connection: DatabaseConnection
    @Binding var isTestingConnection: Bool
    @Binding var testResult: ConnectionWizardView.ConnectionTestResult?
    let onTest: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Connection Summary
            VStack(alignment: .leading, spacing: 16) {
                Text("Connection Summary")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                VStack(spacing: 12) {
                    SummaryRow(label: "Name", value: connection.name)
                    SummaryRow(label: "Type", value: connection.type.rawValue)
                    if connection.type != .sqlite {
                        SummaryRow(label: "Host", value: "\(connection.host):\(connection.port)")
                    }
                    SummaryRow(label: "Database", value: connection.database)
                    if connection.type != .sqlite {
                        SummaryRow(label: "User", value: connection.username)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            }

            // Test Result
            if let result = testResult {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(result.isSuccess ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(result.isSuccess ? .green : .red)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.isSuccess ? "Connection Successful" : "Connection Failed")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(result.isSuccess ? .green : .red)

                        Text(result.isSuccess ? "Your database is ready to use" : "Please check your connection details")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill((result.isSuccess ? Color.green : Color.red).opacity(0.1))
                )
                .transition(.scale.combined(with: .opacity))
            }

            // Test Button
            Button(action: onTest) {
                HStack(spacing: 12) {
                    if isTestingConnection {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }

                    Text(isTestingConnection ? "Testing..." : "Test Connection")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.blue)
                )
            }
            .disabled(isTestingConnection)
        }
    }
}

struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Navigation Bar

struct WizardNavigationBar: View {
    @Binding var currentStep: Int
    let totalSteps: Int
    let canProceed: Bool
    let isLastStep: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button(action: onBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(height: 54)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }

            Button(action: isLastStep ? onComplete : onNext) {
                HStack(spacing: 8) {
                    Text(isLastStep ? "Save Connection" : "Continue")
                    if !isLastStep {
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(height: 54)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(canProceed ? Color.blue : Color.blue.opacity(0.5))
                )
            }
            .disabled(!canProceed)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
}

// MARK: - Wizard Text Field Components

struct WizardTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 24)

                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(keyboardType)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

struct WizardSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    @State private var showPassword = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 24)

                if showPassword {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 16))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } else {
                    SecureField(placeholder, text: $text)
                        .font(.system(size: 16))
                }

                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

#Preview {
    ConnectionWizardView()
        .environmentObject(AppState())
        .environmentObject(DatabaseService())
}

import SwiftUI
import Speech
import AVFoundation

struct VoiceToSQLView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @State private var isRecording = false
    @State private var transcribedText = ""
    @State private var generatedSQL = ""
    @State private var isProcessing = false
    @State private var speechRecognizer = SFSpeechRecognizer()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var showingPermissionsAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                            Text("Voice-to-SQL")
                                .font(.system(size: 24, weight: .bold))
                        }

                        Text("Speak your database query in natural language and get SQL code instantly.")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Voice Recording Section
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.1))
                                .frame(width: 120, height: 120)

                            Button(action: toggleRecording) {
                                ZStack {
                                    Circle()
                                        .fill(isRecording ? Color.red : Color.blue)
                                        .frame(width: 80, height: 80)

                                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                            }
                        }

                        Text(isRecording ? "Listening... Tap to stop" : "Tap to start recording")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isRecording ? .red : .primary)
                    }

                    // Transcribed Text
                    if !transcribedText.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("You said:")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)

                            Text(transcribedText)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                )
                        }
                    }

                    // Generated SQL
                    if !generatedSQL.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Generated SQL:")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)

                                Spacer()

                                if isProcessing {
                                    ProgressView()
                                        .tint(.blue)
                                }
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(generatedSQL)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.secondarySystemBackground))
                                    )
                                    .textSelection(.enabled)
                            }

                            HStack(spacing: 12) {
                                Button(action: {
                                    UIPasteboard.general.string = generatedSQL
                                }) {
                                    HStack {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                                }

                                Button(action: {
                                    // Add to new tab
                                    if let ws = databaseService.currentWorkspace {
                                        let newTab = WorkspaceSubTab(name: "Voice SQL", type: .editor)
                                        ws.subTabs.append(newTab)
                                        ws.selectedSubTabId = newTab.id
                                        ws.queryToRun = generatedSQL
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle")
                                        Text("Open in Editor")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }

                    // Quick Examples
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Try saying:")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        VStack(spacing: 8) {
                            ExamplePhrase(text: "Show me all users from New York")
                            ExamplePhrase(text: "Find orders placed last month")
                            ExamplePhrase(text: "Calculate total sales by product")
                            ExamplePhrase(text: "List customers with more than 5 orders")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Voice SQL")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Microphone Permission Required", isPresented: $showingPermissionsAlert) {
                Button("Settings", action: openSettings)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable microphone access in Settings to use voice-to-SQL functionality.")
            }
            .onAppear {
                requestPermissions()
            }
            .onDisappear {
                stopRecording()
            }
        }
    }

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        if !granted {
                            showingPermissionsAlert = true
                        }
                    }
                case .denied, .restricted, .notDetermined:
                    showingPermissionsAlert = true
                @unknown default:
                    break
                }
            }
        }
    }

    private func openSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #elseif os(macOS)
        // Su macOS, apriamo le preferenze di sistema per la privacy del microfono
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

            let inputNode = audioEngine.inputNode
            guard let recognitionRequest = recognitionRequest else { return }

            recognitionRequest.shouldReportPartialResults = true

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                var isFinal = false

                if let result = result {
                    transcribedText = result.bestTranscription.formattedString
                    isFinal = result.isFinal
                }

                if error != nil || isFinal {
                    audioEngine.stop()
                    inputNode.removeTap(onBus: 0)

                    recognitionRequest.endAudio()
                    self.recognitionRequest = nil
                    self.recognitionTask = nil

                    isRecording = false

                    if isFinal && !transcribedText.isEmpty {
                        generateSQLFromSpeech()
                    }
                }
            }

            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            isRecording = true
        } catch {
            print("Recording failed: \(error)")
        }
    }

    private func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
    }

    private func generateSQLFromSpeech() {
        isProcessing = true

        // Simulate processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            generatedSQL = convertSpeechToSQL(transcribedText)
            isProcessing = false
        }
    }

    private func convertSpeechToSQL(_ speech: String) -> String {
        let lowerSpeech = speech.lowercased()

        // Basic pattern matching for SQL generation
        if lowerSpeech.contains("show me all") || lowerSpeech.contains("list all") {
            if lowerSpeech.contains("users") || lowerSpeech.contains("user") {
                if lowerSpeech.contains("new york") {
                    return "SELECT * FROM users WHERE city = 'New York';"
                }
                return "SELECT * FROM users;"
            }
            if lowerSpeech.contains("orders") || lowerSpeech.contains("order") {
                return "SELECT * FROM orders;"
            }
            if lowerSpeech.contains("products") || lowerSpeech.contains("product") {
                return "SELECT * FROM products;"
            }
        }

        if lowerSpeech.contains("find") || lowerSpeech.contains("show") {
            if lowerSpeech.contains("orders") && lowerSpeech.contains("last month") {
                return "SELECT * FROM orders WHERE order_date >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH);"
            }
            if lowerSpeech.contains("customers") && lowerSpeech.contains("more than") && lowerSpeech.contains("orders") {
                return "SELECT c.*, COUNT(o.id) as order_count\nFROM customers c\nLEFT JOIN orders o ON c.id = o.customer_id\nGROUP BY c.id\nHAVING order_count > 5;"
            }
        }

        if lowerSpeech.contains("calculate") || lowerSpeech.contains("total") {
            if lowerSpeech.contains("sales") && lowerSpeech.contains("product") {
                return "SELECT p.name, SUM(oi.quantity * oi.price) as total_sales\nFROM products p\nJOIN order_items oi ON p.id = oi.product_id\nGROUP BY p.id, p.name\nORDER BY total_sales DESC;"
            }
        }

        // Fallback
        return "-- Voice-to-SQL Conversion\n-- Original: \(speech)\n\nSELECT * FROM your_table\nWHERE condition = 'value';"
    }
}

struct ExamplePhrase: View {
    let text: String

    var body: some View {
        Text("\"\(text)\"")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
    }
}
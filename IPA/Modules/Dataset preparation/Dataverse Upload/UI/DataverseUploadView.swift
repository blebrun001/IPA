//  Main uploader screen that captures connection settings, allows file selection,
//  and bridges UI events with the asynchronous Dataverse upload flow.
//  Presents progress, retry hints, and a live log so users can follow each step.
import SwiftUI

/// Observable state for the upload workflow.
final class UploadState: ObservableObject {
    @Published var isRunning = false
    @Published var logEntries: [String] = []
    @Published var items: [UploadItem] = []
    @Published var progressText: String = ""
    @Published var retryMessage: String = ""

    /// Append a new log line to the on-screen console.
    func appendLog(_ line: String) {
        logEntries.append(line)
    }
}

/// Main application screen that configures the target dataset and triggers uploads.
struct DataverseUploadView<Settings: SettingsProviding>: View where Settings: ObservableObject {
    @StateObject private var state = UploadState()
    @ObservedObject private var settings: Settings
    private let clientType: DVClient.Type

    init(adapter: Settings,
         client: DVClient.Type = DataverseClient.self) {
        _settings = ObservedObject(wrappedValue: adapter)
        self.clientType = client
    }

    private var excludeRegex: String { settings.excludeRegex }
    private let formLabelWidth: CGFloat = 160

    private enum SectionTab: String, CaseIterable, Identifiable {
        case configuration = "Configuration"
        case monitoring = "Monitoring"

        var id: Self { self }
    }

    @State private var selectedTab: SectionTab = .configuration
    @State private var uploadTask: Task<Void, Never>? = nil

    private var formValid: Bool {
        !settings.server.isEmpty && !settings.apiKey.isEmpty && !settings.persistentId.isEmpty && !state.items.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedTab) {
                ForEach(SectionTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)

            Divider()

            Group {
                if selectedTab == .configuration {
                    configurationView
                } else {
                    monitoringView
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 860, minHeight: 620)
    }

    @ViewBuilder
    private var configurationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                connectionGroup
                uploadOptionsGroup
                selectionSummaryGroup
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 840)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var monitoringView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                commandGroup
                liveLogGroup
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 840)
            .frame(maxWidth: .infinity)
        }
    }

    private var connectionGroup: some View {
        GroupBox("Dataverse Connection") {
            SectionCaption(text: NSLocalizedString("Link the uploader to the correct Dataverse instance and dataset draft.", comment: "Connection help text"))
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Server")
                        .foregroundStyle(.secondary)
                        .frame(width: formLabelWidth, alignment: .trailing)
                    TextField("https://…", text: $settings.server)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    Text("API Key")
                        .foregroundStyle(.secondary)
                        .frame(width: formLabelWidth, alignment: .trailing)
                    SecureField("API key", text: $settings.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    Text("DOI / persistentId")
                        .foregroundStyle(.secondary)
                        .frame(width: formLabelWidth, alignment: .trailing)
                    TextField("doi:…", text: $settings.persistentId)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var uploadOptionsGroup: some View {
        GroupBox("Upload Options") {
            SectionCaption(text: NSLocalizedString("Control filtering, retries, and cache refreshes before the app talks to Dataverse.", comment: "Upload options help text"))
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Exclude regex")
                        .foregroundStyle(.secondary)
                        .frame(width: formLabelWidth, alignment: .trailing)
                    TextField(#"^\..*"#, text: $settings.excludeRegex)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    Text("Direct upload")
                        .foregroundStyle(.secondary)
                        .frame(width: formLabelWidth, alignment: .trailing)
                    Toggle("", isOn: $settings.useDirectUpload)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    Text("Auto resume")
                        .foregroundStyle(.secondary)
                        .frame(width: formLabelWidth, alignment: .trailing)
                    Toggle("", isOn: $settings.resumeOnFailure)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    Text("Index (time)")
                        .foregroundStyle(.secondary)
                        .frame(width: formLabelWidth, alignment: .trailing)
                    Stepper(value: $settings.indexRefreshIntervalSeconds, in: 5...600, step: 5) {
                        Text("\(settings.indexRefreshIntervalSeconds) s")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    Text("Index (files)")
                        .foregroundStyle(.secondary)
                        .frame(width: formLabelWidth, alignment: .trailing)
                    Stepper(value: $settings.indexRefreshEveryNFiles, in: 1...500, step: 1) {
                        Text("\(settings.indexRefreshEveryNFiles)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    Text("Checksum")
                        .foregroundStyle(.secondary)
                        .frame(width: formLabelWidth, alignment: .trailing)
                    Toggle("", isOn: $settings.useChecksumForDuplicates)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var selectionSummaryGroup: some View {
        GroupBox("Selection & Summary") {
            SectionCaption(text: NSLocalizedString("Review the staged files and the command that the app will run.", comment: "Selection help text"))
            VStack(alignment: .leading, spacing: 16) {
                FileListView(items: $state.items)
                Divider()
                CommandPreviewView(server: settings.server,
                                   persistentId: settings.persistentId,
                                   excludeRegex: excludeRegex,
                                   count: state.items.count)
            }
        }
    }

    private var commandGroup: some View {
        GroupBox("Commands") {
            SectionCaption(text: NSLocalizedString("Launch, stop, or copy logs from the current upload session.", comment: "Commands help text"))
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Button(state.isRunning ? "Stop" : "Upload") {
                        if state.isRunning {
                            uploadTask?.cancel()
                            uploadTask = nil
                            state.isRunning = false
                            state.retryMessage = ""
                            state.progressText = ""
                            state.appendLog("⛔️ Upload canceled by the user")
                        } else {
                            uploadTask = Task { await runUpload() }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!formValid)

                    if state.isRunning {
                        ProgressView().controlSize(.small)
                    }

                    Spacer()

                    Button("Copy Log") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(state.logEntries.joined(separator: "\n"), forType: .string)
                    }
                    .buttonStyle(.bordered)
                }

                if !state.progressText.isEmpty || !state.retryMessage.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            if !state.progressText.isEmpty {
                                Text(state.progressText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            if !state.retryMessage.isEmpty {
                                Text(state.retryMessage)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
        }
    }

    private var liveLogGroup: some View {
        GroupBox("Live Log") {
            SectionCaption(text: NSLocalizedString("Keep the app in the foreground to follow retries and byte counters in real time.", comment: "Log help text"))
            LogView(entries: state.logEntries,
                    retryMessage: state.retryMessage,
                    cancelMessage: "")
                .frame(minHeight: 220)
        }
    }

    private struct SectionCaption: View {
        let text: String

        var body: some View {
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)
        }
    }

    /// Launch the upload workflow and bridge progress back to the UI.
    private func runUpload() async {
        guard let serverURL = URL(string: settings.server) else {
            state.appendLog("Invalid server: \(settings.server)")
            return
        }
        state.isRunning = true
        state.progressText = "Starting..."
        state.appendLog("== Upload started ==")

        let client = clientType.init(server: serverURL, apiKey: settings.apiKey)
        let coordinator = UploadCoordinator(
            client: client,
            settings: settings
        )

        do {
            try await coordinator.uploadItems(state.items, log: { msg in
                DispatchQueue.main.async {
                    if msg.hasPrefix("Network error, retry") {
                        self.state.retryMessage = msg
                    } else {
                        self.state.appendLog(msg)
                        if !msg.contains("Network error") {
                            self.state.retryMessage = ""
                        }
                    }
                }
            }, progress: { _ in
                // The multiline log already captures progress entries; nothing to present here.
            }, byteProgress: { bp in
                DispatchQueue.main.async { self.state.progressText = bp }
            })
            DispatchQueue.main.async {
                self.state.isRunning = false
                self.state.progressText = ""
                self.state.retryMessage = ""
                self.state.appendLog("== Upload completed ==")
            }
        } catch is CancellationError {
            DispatchQueue.main.async {
                self.state.isRunning = false
                self.state.progressText = ""
                self.state.retryMessage = ""
                self.state.appendLog("⛔️ Upload canceled")
            }
        } catch {
            DispatchQueue.main.async {
                self.state.isRunning = false
                self.state.progressText = ""
                self.state.retryMessage = ""
                self.state.appendLog("Error: \(error.localizedDescription)")
            }
        }
    }
}

#if DEBUG
struct DataverseUploadView_Previews: PreviewProvider {
    final class PreviewSettings: SettingsProviding {
        @Published var server: String = "https://demo.dataverse.org"
        @Published var apiKey: String = "secret"
        @Published var persistentId: String = "doi:10.123/ABC"
        @Published var excludeRegex: String = #"^\..*"#
        @Published var useDirectUpload: Bool = true
        @Published var resumeOnFailure: Bool = true
        @Published var maxRetryAttempts: Int = 3
        @Published var initialBackoffSeconds: Int = 2
        @Published var indexRefreshIntervalSeconds: Int = 30
        @Published var indexRefreshEveryNFiles: Int = 10
        @Published var useChecksumForDuplicates: Bool = false
    }

    struct PreviewClient: DVClient {
        var server: URL = URL(string: "https://demo.dataverse.org")!
        var apiKey: String = "preview"

        init(server: URL, apiKey: String) {
            self.server = server
            self.apiKey = apiKey
        }

        func requestDirectUploadInit(persistentId: String,
                                     fileSize: Int64,
                                     fileName: String?,
                                     mime: String?) async throws -> DVDirectInitResponse {
            let data = DVDirectInitData(
                url: nil,
                urls: nil,
                partSize: nil,
                storageIdentifier: "s",
                abort: nil,
                complete: nil,
                headers: nil
            )
            return DVDirectInitResponse(status: "OK", data: data)
        }

        func putFileToS3(preSignedURL: URL, headers: [String : String]?, fileURL: URL) async throws { }

        func finalizeDirectUpload(persistentId: String, payload: DVFinalizeRequest) async throws { }

        func uploadMultipart(persistentId: String,
                             fileURL: URL,
                             directoryLabel: String?,
                             log: @escaping (String) -> Void,
                             progress: @escaping (String) -> Void,
                             shouldCancel: @escaping () -> Bool) async throws { }

        func listDraftFiles(persistentId: String) async throws -> [DVExistingFile] { [] }
    }

    static var previews: some View {
        DataverseUploadView(adapter: PreviewSettings(), client: PreviewClient.self)
            .frame(width: 960, height: 640)
    }
}
#endif

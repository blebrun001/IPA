//  IPASettingsAdapter.swift
//  Bridges SettingsManager with the Dataverse upload module via SettingsProviding.

import Foundation
import Combine

protocol SettingsProviding: ObservableObject {
    var server: String { get set }
    var apiKey: String { get set }
    var persistentId: String { get set }
    var excludeRegex: String { get set }
    var useDirectUpload: Bool { get set }
    var resumeOnFailure: Bool { get set }
    var maxRetryAttempts: Int { get set }
    var initialBackoffSeconds: Int { get set }
    var indexRefreshIntervalSeconds: Int { get set }
    var indexRefreshEveryNFiles: Int { get set }
    var useChecksumForDuplicates: Bool { get set }
}

/// Adapter that keeps the Dataverse uploader settings in sync with the shared SettingsManager.
final class IPASettingsAdapter: SettingsProviding {
    @Published var server: String
    @Published var apiKey: String
    @Published var persistentId: String
    @Published var excludeRegex: String
    @Published var useDirectUpload: Bool
    @Published var resumeOnFailure: Bool
    @Published var maxRetryAttempts: Int
    @Published var initialBackoffSeconds: Int
    @Published var indexRefreshIntervalSeconds: Int
    @Published var indexRefreshEveryNFiles: Int
    @Published var useChecksumForDuplicates: Bool

    private let manager: SettingsManager
    private var cancellables: Set<AnyCancellable> = []

    init(settingsManager: SettingsManager = SettingsManager.instance) {
        self.manager = settingsManager

        server = settingsManager.dataverseAddress
        apiKey = settingsManager.dataverseToken
        persistentId = settingsManager.dataversePersistentId
        excludeRegex = settingsManager.dataverseExcludeRegex
        useDirectUpload = settingsManager.dataverseUseDirectUpload
        resumeOnFailure = settingsManager.dataverseResumeOnFailure
        maxRetryAttempts = settingsManager.dataverseMaxRetryAttempts
        initialBackoffSeconds = settingsManager.dataverseInitialBackoffSeconds
        indexRefreshIntervalSeconds = settingsManager.dataverseIndexRefreshIntervalSeconds
        indexRefreshEveryNFiles = settingsManager.dataverseIndexRefreshEveryNFiles
        useChecksumForDuplicates = settingsManager.dataverseUseChecksumForDuplicates

        setupBindings()
    }

    private func setupBindings() {
        bind(managerPublisher: manager.$dataverseAddress,
             adapterPublisher: $server,
             managerKeyPath: \.dataverseAddress,
             adapterKeyPath: \.server)
        bind(managerPublisher: manager.$dataverseToken,
             adapterPublisher: $apiKey,
             managerKeyPath: \.dataverseToken,
             adapterKeyPath: \.apiKey)
        bind(managerPublisher: manager.$dataversePersistentId,
             adapterPublisher: $persistentId,
             managerKeyPath: \.dataversePersistentId,
             adapterKeyPath: \.persistentId)
        bind(managerPublisher: manager.$dataverseExcludeRegex,
             adapterPublisher: $excludeRegex,
             managerKeyPath: \.dataverseExcludeRegex,
             adapterKeyPath: \.excludeRegex)
        bind(managerPublisher: manager.$dataverseUseDirectUpload,
             adapterPublisher: $useDirectUpload,
             managerKeyPath: \.dataverseUseDirectUpload,
             adapterKeyPath: \.useDirectUpload)
        bind(managerPublisher: manager.$dataverseResumeOnFailure,
             adapterPublisher: $resumeOnFailure,
             managerKeyPath: \.dataverseResumeOnFailure,
             adapterKeyPath: \.resumeOnFailure)
        bind(managerPublisher: manager.$dataverseMaxRetryAttempts,
             adapterPublisher: $maxRetryAttempts,
             managerKeyPath: \.dataverseMaxRetryAttempts,
             adapterKeyPath: \.maxRetryAttempts)
        bind(managerPublisher: manager.$dataverseInitialBackoffSeconds,
             adapterPublisher: $initialBackoffSeconds,
             managerKeyPath: \.dataverseInitialBackoffSeconds,
             adapterKeyPath: \.initialBackoffSeconds)
        bind(managerPublisher: manager.$dataverseIndexRefreshIntervalSeconds,
             adapterPublisher: $indexRefreshIntervalSeconds,
             managerKeyPath: \.dataverseIndexRefreshIntervalSeconds,
             adapterKeyPath: \.indexRefreshIntervalSeconds)
        bind(managerPublisher: manager.$dataverseIndexRefreshEveryNFiles,
             adapterPublisher: $indexRefreshEveryNFiles,
             managerKeyPath: \.dataverseIndexRefreshEveryNFiles,
             adapterKeyPath: \.indexRefreshEveryNFiles)
        bind(managerPublisher: manager.$dataverseUseChecksumForDuplicates,
             adapterPublisher: $useChecksumForDuplicates,
             managerKeyPath: \.dataverseUseChecksumForDuplicates,
             adapterKeyPath: \.useChecksumForDuplicates)
    }

    private func bind<Value: Equatable>(
        managerPublisher: Published<Value>.Publisher,
        adapterPublisher: Published<Value>.Publisher,
        managerKeyPath: ReferenceWritableKeyPath<SettingsManager, Value>,
        adapterKeyPath: ReferenceWritableKeyPath<IPASettingsAdapter, Value>
    ) {
        managerPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self else { return }
                if self[keyPath: adapterKeyPath] != value {
                    self[keyPath: adapterKeyPath] = value
                }
            }
            .store(in: &cancellables)

        adapterPublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self else { return }
                if self.manager[keyPath: managerKeyPath] != value {
                    self.manager[keyPath: managerKeyPath] = value
                }
            }
            .store(in: &cancellables)
    }
}

//  SettingsManager.swift
//  Centralized manager for user settings with AppStorage-backed persistence and DVU migration.

import Foundation
import SwiftUI
import Combine

final class SettingsManager: ObservableObject {
    static let instance = SettingsManager()

    // MARK: - Published values observed throughout the app
    @Published var dataverseToken: String {
        didSet { storedDataverseToken.wrappedValue = dataverseToken }
    }
    @Published var dataverseAddress: String {
        didSet { storedDataverseAddress.wrappedValue = dataverseAddress }
    }
    @Published var enableSound: Bool {
        didSet { storedEnableSound.wrappedValue = enableSound }
    }

    @Published var dataversePersistentId: String {
        didSet {
            storedDataversePersistentId.wrappedValue = dataversePersistentId
            persistDatasetContextIfNeeded(dataversePersistentId)
        }
    }
    @Published var dataverseExcludeRegex: String {
        didSet { storedDataverseExcludeRegex.wrappedValue = dataverseExcludeRegex }
    }
    @Published var dataverseUseDirectUpload: Bool {
        didSet { storedDataverseUseDirectUpload.wrappedValue = dataverseUseDirectUpload }
    }
    @Published var dataverseResumeOnFailure: Bool {
        didSet { storedDataverseResumeOnFailure.wrappedValue = dataverseResumeOnFailure }
    }
    @Published var dataverseMaxRetryAttempts: Int {
        didSet { storedDataverseMaxRetryAttempts.wrappedValue = dataverseMaxRetryAttempts }
    }
    @Published var dataverseInitialBackoffSeconds: Int {
        didSet { storedDataverseInitialBackoffSeconds.wrappedValue = dataverseInitialBackoffSeconds }
    }
    @Published var dataverseIndexRefreshIntervalSeconds: Int {
        didSet { storedDataverseIndexRefreshIntervalSeconds.wrappedValue = dataverseIndexRefreshIntervalSeconds }
    }
    @Published var dataverseIndexRefreshEveryNFiles: Int {
        didSet { storedDataverseIndexRefreshEveryNFiles.wrappedValue = dataverseIndexRefreshEveryNFiles }
    }
    @Published var dataverseUseChecksumForDuplicates: Bool {
        didSet { storedDataverseUseChecksumForDuplicates.wrappedValue = dataverseUseChecksumForDuplicates }
    }

    // MARK: - Backing storage using AppStorage (UserDefaults)
    private var storedDataverseToken: AppStorage<String>
    private var storedDataverseAddress: AppStorage<String>
    private var storedEnableSound: AppStorage<Bool>

    private var storedDataversePersistentId: AppStorage<String>
    private var storedDataverseExcludeRegex: AppStorage<String>
    private var storedDataverseUseDirectUpload: AppStorage<Bool>
    private var storedDataverseResumeOnFailure: AppStorage<Bool>
    private var storedDataverseMaxRetryAttempts: AppStorage<Int>
    private var storedDataverseInitialBackoffSeconds: AppStorage<Int>
    private var storedDataverseIndexRefreshIntervalSeconds: AppStorage<Int>
    private var storedDataverseIndexRefreshEveryNFiles: AppStorage<Int>
    private var storedDataverseUseChecksumForDuplicates: AppStorage<Bool>
    private var datasetContextPersistentId: AppStorage<String>
    private var didMigrateDVUSettings: AppStorage<Bool>

    private init() {
        storedDataverseToken = AppStorage(wrappedValue: "", Keys.dataverseToken)
        storedDataverseAddress = AppStorage(wrappedValue: "", Keys.dataverseAddress)
        storedEnableSound = AppStorage(wrappedValue: true, Keys.enableSound)

        storedDataversePersistentId = AppStorage(wrappedValue: "", Keys.dataversePersistentId)
        storedDataverseExcludeRegex = AppStorage(wrappedValue: #"^\..*"#, Keys.dataverseExcludeRegex)
        storedDataverseUseDirectUpload = AppStorage(wrappedValue: false, Keys.dataverseUseDirectUpload)
        storedDataverseResumeOnFailure = AppStorage(wrappedValue: true, Keys.dataverseResumeOnFailure)
        storedDataverseMaxRetryAttempts = AppStorage(wrappedValue: 5, Keys.dataverseMaxRetryAttempts)
        storedDataverseInitialBackoffSeconds = AppStorage(wrappedValue: 2, Keys.dataverseInitialBackoffSeconds)
        storedDataverseIndexRefreshIntervalSeconds = AppStorage(wrappedValue: 30, Keys.dataverseIndexRefreshIntervalSeconds)
        storedDataverseIndexRefreshEveryNFiles = AppStorage(wrappedValue: 10, Keys.dataverseIndexRefreshEveryNFiles)
        storedDataverseUseChecksumForDuplicates = AppStorage(wrappedValue: false, Keys.dataverseUseChecksumForDuplicates)
        datasetContextPersistentId = AppStorage(wrappedValue: "", Keys.datasetContextPersistentId)
        didMigrateDVUSettings = AppStorage(wrappedValue: false, Keys.didMigrateDVU)

        dataverseToken = storedDataverseToken.wrappedValue
        dataverseAddress = storedDataverseAddress.wrappedValue
        enableSound = storedEnableSound.wrappedValue

        dataversePersistentId = storedDataversePersistentId.wrappedValue
        dataverseExcludeRegex = storedDataverseExcludeRegex.wrappedValue
        dataverseUseDirectUpload = storedDataverseUseDirectUpload.wrappedValue
        dataverseResumeOnFailure = storedDataverseResumeOnFailure.wrappedValue
        dataverseMaxRetryAttempts = storedDataverseMaxRetryAttempts.wrappedValue
        dataverseInitialBackoffSeconds = storedDataverseInitialBackoffSeconds.wrappedValue
        dataverseIndexRefreshIntervalSeconds = storedDataverseIndexRefreshIntervalSeconds.wrappedValue
        dataverseIndexRefreshEveryNFiles = storedDataverseIndexRefreshEveryNFiles.wrappedValue
        dataverseUseChecksumForDuplicates = storedDataverseUseChecksumForDuplicates.wrappedValue

        migrateLegacyDVUDefaultsIfNeeded()
        prefillPersistentIdFromDatasetContextIfAvailable()
    }

    // MARK: - Legacy DVU migration
    private func migrateLegacyDVUDefaultsIfNeeded(defaults: UserDefaults = .standard) {
        guard !didMigrateDVUSettings.wrappedValue else { return }

        if storedDataverseAddress.wrappedValue.isEmpty,
           let legacyServer = defaults.string(forKey: Keys.legacyServer),
           !legacyServer.isEmpty {
            dataverseAddress = legacyServer
        }

        if storedDataverseToken.wrappedValue.isEmpty,
           let legacyToken = defaults.string(forKey: Keys.legacyApiKey),
           !legacyToken.isEmpty {
            dataverseToken = legacyToken
        }

        if storedDataversePersistentId.wrappedValue.isEmpty,
           let legacyPid = defaults.string(forKey: Keys.legacyPersistentId),
           !legacyPid.isEmpty {
            dataversePersistentId = legacyPid
        }

        if storedDataverseExcludeRegex.wrappedValue == #"^\..*"#,
           let legacyExclude = defaults.string(forKey: Keys.legacyExcludeRegex),
           !legacyExclude.isEmpty {
            dataverseExcludeRegex = legacyExclude
        }

        if defaults.object(forKey: Keys.legacyUseDirectUpload) != nil {
            dataverseUseDirectUpload = defaults.bool(forKey: Keys.legacyUseDirectUpload)
        } else if defaults.object(forKey: Keys.legacyUploadViaServer) != nil {
            dataverseUseDirectUpload = !defaults.bool(forKey: Keys.legacyUploadViaServer)
        }

        if defaults.object(forKey: Keys.legacyResumeOnFailure) != nil {
            dataverseResumeOnFailure = defaults.bool(forKey: Keys.legacyResumeOnFailure)
        }

        if let value = defaults.object(forKey: Keys.legacyMaxRetryAttempts) as? Int {
            dataverseMaxRetryAttempts = value
        }
        if let value = defaults.object(forKey: Keys.legacyInitialBackoffSeconds) as? Int {
            dataverseInitialBackoffSeconds = value
        }
        if let value = defaults.object(forKey: Keys.legacyIndexRefreshIntervalSeconds) as? Int {
            dataverseIndexRefreshIntervalSeconds = value
        }
        if let value = defaults.object(forKey: Keys.legacyIndexRefreshEveryNFiles) as? Int {
            dataverseIndexRefreshEveryNFiles = value
        }
        if defaults.object(forKey: Keys.legacyUseChecksumForDuplicates) != nil {
            dataverseUseChecksumForDuplicates = defaults.bool(forKey: Keys.legacyUseChecksumForDuplicates)
        }

        didMigrateDVUSettings.wrappedValue = true
    }

    // MARK: - Dataset context helpers
    private func prefillPersistentIdFromDatasetContextIfAvailable() {
        guard dataversePersistentId.isEmpty else { return }
        guard !datasetContextPersistentId.wrappedValue.isEmpty else { return }
        dataversePersistentId = datasetContextPersistentId.wrappedValue
    }

    private func persistDatasetContextIfNeeded(_ persistentId: String) {
        guard !persistentId.isEmpty else { return }
        datasetContextPersistentId.wrappedValue = persistentId
    }

    private enum Keys {
        static let dataverseToken = "dataverseToken"
        static let dataverseAddress = "dataverseAddress"
        static let enableSound = "enableSound"

        static let dataversePersistentId = "ipa.settings.dataversePersistentId"
        static let dataverseExcludeRegex = "ipa.settings.dataverseExcludeRegex"
        static let dataverseUseDirectUpload = "ipa.settings.dataverseUseDirectUpload"
        static let dataverseResumeOnFailure = "ipa.settings.dataverseResumeOnFailure"
        static let dataverseMaxRetryAttempts = "ipa.settings.dataverseMaxRetryAttempts"
        static let dataverseInitialBackoffSeconds = "ipa.settings.dataverseInitialBackoffSeconds"
        static let dataverseIndexRefreshIntervalSeconds = "ipa.settings.dataverseIndexRefreshIntervalSeconds"
        static let dataverseIndexRefreshEveryNFiles = "ipa.settings.dataverseIndexRefreshEveryNFiles"
        static let dataverseUseChecksumForDuplicates = "ipa.settings.dataverseUseChecksumForDuplicates"

        static let datasetContextPersistentId = "ipa.datasetPreparation.currentPersistentId"
        static let didMigrateDVU = "ipa.settings.didMigrateDVU"

        // Legacy DVU keys
        static let legacyServer = "settings.server"
        static let legacyApiKey = "settings.apiKey"
        static let legacyPersistentId = "settings.persistentId"
        static let legacyExcludeRegex = "settings.excludeRegex"
        static let legacyUseDirectUpload = "settings.useDirectUpload"
        static let legacyUploadViaServer = "settings.uploadViaServer"
        static let legacyResumeOnFailure = "settings.resumeOnFailure"
        static let legacyMaxRetryAttempts = "settings.maxRetryAttempts"
        static let legacyInitialBackoffSeconds = "settings.initialBackoffSeconds"
        static let legacyIndexRefreshIntervalSeconds = "settings.indexRefreshIntervalSeconds"
        static let legacyIndexRefreshEveryNFiles = "settings.indexRefreshEveryNFiles"
        static let legacyUseChecksumForDuplicates = "settings.useChecksumForDuplicates"
    }
}
